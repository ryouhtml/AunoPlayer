//! Decoder thread. Satu thread untuk seluruh antrian track.
//! Ia tidak pernah menyentuh perangkat audio dan tidak pernah dipanggil
//! dari callback; komunikasi hanya lewat ring buffer SPSC + channel.

use std::{
    fs::File,
    path::PathBuf,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
    thread::{self, JoinHandle},
    time::{Duration, Instant},
};

use crossbeam_channel::{bounded, Receiver, Sender, TryRecvError};
use dsd_pcm::{Decimator, Quantizer};
use symphonia::core::{
    audio::SampleBuffer,
    codecs::{Decoder, DecoderOptions, CODEC_TYPE_NULL},
    formats::{FormatOptions, FormatReader, SeekMode, SeekTo},
    io::MediaSourceStream,
    meta::MetadataOptions,
    probe::Hint,
    units::Time,
};
use tracing::warn;

use super::{format::AudioFormat, ring::PcmProducer};
use crate::error::{decode as dec_err, AunoError, Result};

#[derive(Debug, Clone)]
pub struct QueuedTrack {
    pub path: PathBuf,
    pub start: Option<Duration>,
    pub format: AudioFormat,
}

#[derive(Debug)]
pub enum DecoderCommand {
    Seek(Duration),
    QueueNext(Vec<QueuedTrack>),
    Stop,
    Shutdown,
}

#[derive(Debug)]
pub enum DecoderEvent {
    Position {
        elapsed: Duration,
        total: Duration,
        buffered_frames: usize,
    },
    TrackChanged(PathBuf),
    GaplessRejected,
    EndOfQueue,
    Error(String),
}

pub struct DecoderHandles {
    pub commands: Sender<DecoderCommand>,
    pub events: Receiver<DecoderEvent>,
    pub thread: JoinHandle<()>,
}

pub fn spawn_decoder(
    first: QueuedTrack,
    upcoming: Vec<QueuedTrack>,
    producer: PcmProducer,
    flush_epoch: Arc<AtomicU64>,
) -> Result<DecoderHandles> {
    let format = first.format;
    let channels = format.channels as usize;
    let source = Source::open(&first)?;
    let (commands, cmd_rx) = bounded(16);
    let (event_tx, events) = bounded(32);

    let thread = thread::Builder::new()
        .name("auno-decoder".into())
        .spawn(move || {
            let mut decoder = DecoderThread {
                commands: cmd_rx,
                events: event_tx,
                producer,
                source,
                format,
                channels,
                queue: upcoming.into_iter().collect(),
                flush_epoch,
                scratch: Vec::with_capacity(channels * 4096),
                last_event: Instant::now(),
            };
            decoder.run();
        })?;

    Ok(DecoderHandles {
        commands,
        events,
        thread,
    })
}

struct DecoderThread {
    commands: Receiver<DecoderCommand>,
    events: Sender<DecoderEvent>,
    producer: PcmProducer,
    source: Source,
    format: AudioFormat,
    channels: usize,
    queue: std::collections::VecDeque<QueuedTrack>,
    flush_epoch: Arc<AtomicU64>,
    scratch: Vec<i32>,
    last_event: Instant,
}

impl DecoderThread {
    fn run(&mut self) {
        loop {
            // Perintah diproses lebih dulu supaya seek/stop responsif.
            match self.commands.try_recv() {
                Ok(DecoderCommand::Stop) | Ok(DecoderCommand::Shutdown) => return,
                Ok(DecoderCommand::QueueNext(tracks)) => self.queue.extend(tracks),
                Ok(DecoderCommand::Seek(to)) => {
                    self.flush_epoch.fetch_add(1, Ordering::Relaxed);
                    self.scratch.clear();
                    if let Err(err) = self.source.seek(to, self.format.sample_rate) {
                        let _ = self.events.send(DecoderEvent::Error(err.to_string()));
                        return;
                    }
                }
                Err(TryRecvError::Empty) => {}
                Err(TryRecvError::Disconnected) => return,
            }

            // Backpressure: decoder thread tidur saat ring penuh.
            let headroom = self.producer.capacity().saturating_sub(4096);
            if self.producer.len() >= headroom {
                thread::sleep(Duration::from_millis(2));
                continue;
            }

            self.scratch.clear();
            match self.source.next_block(&mut self.scratch) {
                Ok(true) => {
                    let frames = self.scratch.len() / self.channels;
                    if frames == 0 {
                        continue;
                    }
                    self.source.advance(frames);
                    self.producer.push_interleaved(&self.scratch);

                    if self.last_event.elapsed() >= Duration::from_millis(100) {
                        self.last_event = Instant::now();
                        let (done, total) = self.source.position();
                        let _ = self.events.send(DecoderEvent::Position {
                            elapsed: frame_duration(done, self.format.sample_rate),
                            total: frame_duration(total, self.format.sample_rate),
                            buffered_frames: self.producer.len() / self.channels,
                        });
                    }
                }
                Ok(false) => {
                    let Some(next) = self.queue.pop_front() else {
                        let _ = self.events.send(DecoderEvent::EndOfQueue);
                        return;
                    };

                    if !self.format.gapless_compatible(next.format) {
                        warn!("format berubah, gapless tidak mungkin: {}", next.format.label());
                        let _ = self.events.send(DecoderEvent::GaplessRejected);
                        return;
                    }

                    match Source::open(&next) {
                        Ok(source) => {
                            let path = next.path.clone();
                            self.source = source;
                            let _ = self.events.send(DecoderEvent::TrackChanged(path));
                        }
                        Err(err) => {
                            let _ = self.events.send(DecoderEvent::Error(err.to_string()));
                            return;
                        }
                    }
                }
                Err(err) => {
                    let _ = self.events.send(DecoderEvent::Error(err.to_string()));
                    return;
                }
            }
        }
    }
}

fn frame_duration(frames: u64, sample_rate: u32) -> Duration {
    if sample_rate == 0 {
        return Duration::ZERO;
    }
    let secs = frames / sample_rate as u64;
    let frac = (frames % sample_rate as u64) as f64 / sample_rate as f64;
    Duration::new(secs, (frac * 1_000_000_000.0) as u32)
}

enum Source {
    Symphonia {
        reader: Box<dyn FormatReader>,
        decoder: Box<dyn Decoder>,
        track_id: u32,
        buf: Option<SampleBuffer<i32>>,
        frames_done: u64,
        frames_total: u64,
    },
    Dsd {
        iter: dsd_reader::DsdIter,
        decimator: Decimator,
        quantizer: Quantizer,
        pcm: Vec<f64>,
        quantized: Vec<i32>,
        frames_done: u64,
        frames_total: u64,
        finished: bool,
    },
}

impl Source {
    fn open(track: &QueuedTrack) -> Result<Self> {
        let ext = track
            .path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or_default();

        if matches!(ext.to_ascii_lowercase().as_str(), "dsf" | "dff" | "dsd") {
            return Self::open_dsd(track);
        }
        Self::open_pcm(track)
    }

    fn open_pcm(track: &QueuedTrack) -> Result<Self> {
        let file = File::open(&track.path)?;
        let mss = MediaSourceStream::new(Box::new(file), Default::default());
        let mut hint = Hint::new();
        if let Some(ext) = track.path.extension().and_then(|e| e.to_str()) {
            hint.with_extension(ext);
        }

        let probed = symphonia::default::get_probe().format(
            &hint,
            mss,
            &FormatOptions::default(),
            &MetadataOptions::default(),
        )?;

        let reader = probed.format;
        let track_info = reader
            .default_track()
            .ok_or_else(|| AunoError::Decode("tidak ada audio track".into()))?;

        if track_info.codec_params.codec == CODEC_TYPE_NULL {
            return Err(AunoError::Decode("codec audio null".into()));
        }

        let track_id = track_info.id;
        let params = track_info.codec_params.clone();
        let frames_total = params.n_frames.unwrap_or(0);

        let decoder = symphonia::default::get_codecs()
            .make(&params, &DecoderOptions { verify: false })?;

        let mut source = Self::Symphonia {
            reader,
            decoder,
            track_id,
            buf: None,
            frames_done: 0,
            frames_total,
        };

        if let Some(start) = track.start {
            if start > Duration::ZERO {
                source.seek(start, track.format.sample_rate)?;
            }
        }
        Ok(source)
    }

    fn open_dsd(track: &QueuedTrack) -> Result<Self> {
        let reader = dsd_reader::DsdReader::from_container(track.path.clone())
            .map_err(|e| AunoError::Decode(e.to_string()))?;
        let rate = reader.dsd_rate() as u32;
        let channels = reader.channels_num();
        let decimator = Decimator::new(rate, channels).map_err(dec_err)?;
        let quantizer = Quantizer::new(track.format.bits_per_sample as u32).map_err(dec_err)?;
        let iter = reader.interl_iter(false, None).map_err(|e| {
            AunoError::Decode(e.to_string())
        })?;

        Ok(Self::Dsd {
            iter,
            decimator,
            quantizer,
            pcm: Vec::new(),
            quantized: Vec::new(),
            frames_done: 0,
            frames_total: 0,
            finished: false,
        })
    }

    fn next_block(&mut self, out: &mut Vec<i32>) -> Result<bool> {
        match self {
            Self::Symphonia {
                reader,
                decoder,
                track_id,
                buf,
                ..
            } => loop {
                let packet = match reader.next_packet() {
                    Ok(packet) => packet,
                    Err(symphonia::core::errors::Error::IoError(ref e))
                        if e.kind() == std::io::ErrorKind::UnexpectedEof =>
                    {
                        return Ok(false);
                    }
                    Err(err) => {
                        warn!("packet dilewati: {err}");
                        decoder.reset();
                        continue;
                    }
                };

                if packet.track_id() != *track_id {
                    continue;
                }

                let decoded = match decoder.decode(&packet) {
                    Ok(decoded) => decoded,
                    Err(symphonia::core::errors::Error::ResetRequired) => {
                        decoder.reset();
                        continue;
                    }
                    Err(err) => {
                        warn!("packet tidak bisa didekode: {err}");
                        continue;
                    }
                };

                if buf.as_ref().is_none_or(|b| b.capacity() < decoded.capacity()) {
                    *buf = Some(SampleBuffer::<i32>::new(
                        decoded.capacity() as u64,
                        *decoded.spec(),
                    ));
                }
                let buf = buf.as_mut().expect("sample buffer initialized above");
                buf.copy_interleaved_ref(decoded);

                if buf.samples().is_empty() {
                    continue;
                }
                out.extend_from_slice(buf.samples());
                return Ok(true);
            },
            Self::Dsd {
                iter,
                decimator,
                quantizer,
                pcm,
                quantized,
                finished,
                ..
            } => {
                pcm.clear();
                let mut drained = false;
                if let Some((_, buffers)) = iter.next() {
                    if let Some(first) = buffers.first() {
                        let bytes: &[u8] = first.as_ref();
                        if !bytes.is_empty() {
                            decimator
                                .process_interleaved(bytes, pcm)
                                .map_err(dec_err)?;
                            drained = true;
                        }
                    }
                } else if !*finished {
                    *finished = true;
                    decimator.finish(pcm);
                    drained = true;
                }
                if !drained || pcm.is_empty() {
                    return Ok(false);
                }

                quantized.clear();
                quantizer.quantize(pcm, quantized);

                // Quantizer dsd-pcm right-aligned; symphonia/cpal mengharapkan
                // sample left-aligned di dalam i32.
                let shift = 32u32.saturating_sub(quantizer.bits());
                if shift == 0 {
                    out.extend_from_slice(quantized);
                } else {
                    out.extend(quantized.iter().map(|&s| s << shift));
                }
                Ok(!out.is_empty())
            }
        }
    }

    fn advance(&mut self, frames: usize) {
        match self {
            Self::Symphonia { frames_done, .. } | Self::Dsd { frames_done, .. } => {
                *frames_done += frames as u64;
            }
        }
    }

    fn position(&self) -> (u64, u64) {
        match self {
            Self::Symphonia {
                frames_done,
                frames_total,
                ..
            }
            | Self::Dsd {
                frames_done,
                frames_total,
                ..
            } => (*frames_done, *frames_total),
        }
    }

    fn seek(&mut self, to: Duration, sample_rate: u32) -> Result<()> {
        match self {
            Self::Symphonia {
                reader,
                decoder,
                track_id,
                frames_done,
                ..
            } => {
                let time = Time::new(to.as_secs(), to.subsec_nanos() as f64 / 1_000_000_000.0);
                reader
                    .seek(
                        SeekMode::Accurate,
                        SeekTo::Time {
                            time,
                            track_id: Some(*track_id),
                        },
                    )
                    .map_err(dec_err)?;
                decoder.reset();
                *frames_done = (to.as_secs_f64() * sample_rate as f64) as u64;
                Ok(())
            }
            Self::Dsd { decimator, .. } => {
                decimator.reset();
                Err(AunoError::Unsupported(
                    "seek presisi pada DSD belum didukung (decode dari awal)".into(),
                ))
            }
        }
    }
}
