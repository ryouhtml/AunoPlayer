use std::{
    path::PathBuf,
    sync::{atomic::Ordering, Arc},
    time::Duration,
};

use crossbeam_channel::TryRecvError;
use tracing::{error, warn};

use crate::{
    audio::{
        spawn_decoder, AudioBackend, AudioControl, AudioFormat, CpalBackend, DecoderCommand,
        DecoderEvent, DecoderHandles, PcmRing, QueuedTrack,
    },
    error::Result,
    library::{scan_dir, LibraryEntry},
};

pub struct Playback {
    pub backend: CpalBackend,
    pub control: AudioControl,
    pub handles: DecoderHandles,
    pub format: AudioFormat,
}

impl Drop for Playback {
    fn drop(&mut self) {
        let _ = self.handles.commands.try_send(DecoderCommand::Shutdown);
    }
}

pub struct Session {
    pub root: PathBuf,
    pub entries: Vec<LibraryEntry>,
    pub selected: usize,
    pub playback: Option<Playback>,
    pub device_filter: Option<String>,
    pub volume: u8,
    pub bypass: bool,
    pub status: String,
    pub now_playing: String,
    pub elapsed: Duration,
    pub total: Duration,
    pub buffered_frames: usize,
    pub underruns: u64,
}

impl Session {
    pub fn new(root: PathBuf, device_filter: Option<String>) -> Result<Self> {
        let entries = scan_dir(&root)?;
        let count = entries.len();
        Ok(Self {
            root,
            entries,
            selected: 0,
            playback: None,
            device_filter,
            volume: 100,
            bypass: true, // default audiophile: tidak ada software volume
            status: format!("{count} track terindeks"),
            now_playing: "-".into(),
            elapsed: Duration::ZERO,
            total: Duration::ZERO,
            buffered_frames: 0,
            underruns: 0,
        })
    }

    pub fn refresh(&mut self) -> Result<()> {
        self.stop();
        self.entries = scan_dir(&self.root)?;
        self.selected = self.selected.min(self.entries.len().saturating_sub(1));
        self.status = format!("{} track terindeks", self.entries.len());
        Ok(())
    }

    pub fn is_playing(&self) -> bool {
        self.playback
            .as_ref()
            .map(|p| !p.control.paused.load(Ordering::Relaxed))
            .unwrap_or(false)
    }

    pub fn move_selection(&mut self, delta: isize) {
        if self.entries.is_empty() {
            return;
        }
        let len = self.entries.len() as isize;
        self.selected = (self.selected as isize + delta).rem_euclid(len) as usize;
    }

    pub fn play_selected(&mut self) {
        if let Err(err) = self.play_index(self.selected) {
            self.status = format!("ERROR: {err}");
            error!("{err}");
        }
    }

    fn play_index(&mut self, index: usize) -> Result<()> {
        self.stop();
        let Some(entry) = self.entries.get(index).cloned() else {
            return Ok(());
        };

        let format = match entry.format() {
            Ok(format) => format,
            Err(err) => {
                self.status = format!("Tidak bisa dibaca: {err}");
                return Ok(());
            }
        };

        let ring_frames = (format.sample_rate as usize / 2).max(8192);
        let ring = PcmRing::new(format.container, ring_frames, format.channels);

        let control = AudioControl {
            volume: Arc::new(std::sync::atomic::AtomicU8::new(self.volume)),
            bypass: Arc::new(std::sync::atomic::AtomicBool::new(self.bypass)),
            ..AudioControl::default()
        };

        let backend = CpalBackend::open(
            format,
            ring.consumer,
            control.clone(),
            self.device_filter.as_deref(),
        )?;

        // Antrean untuk gapless: hanya track dengan format identik.
        let mut upcoming = Vec::new();
        for next in self.entries.iter().skip(index + 1).take(6) {
            if let Ok(next_format) = next.format() {
                if format.gapless_compatible(next_format) {
                    upcoming.push(QueuedTrack {
                        path: next.path.clone(),
                        start: next.start,
                        format: next_format,
                    });
                } else {
                    break;
                }
            }
        }

        let first = QueuedTrack {
            path: entry.path.clone(),
            start: entry.start,
            format,
        };

        let handles = spawn_decoder(first, upcoming, ring.producer, control.flush_epoch.clone())?;
        backend.play()?;

        self.selected = index;
        self.now_playing = entry.label.clone();
        self.elapsed = Duration::ZERO;
        self.total = entry.meta.duration;
        self.buffered_frames = 0;
        self.status = format!("Play | {}", format.label());
        self.playback = Some(Playback {
            backend,
            control,
            handles,
            format,
        });
        Ok(())
    }

    pub fn stop(&mut self) {
        if let Some(playback) = self.playback.take() {
            drop(playback);
        }
        self.elapsed = Duration::ZERO;
        self.buffered_frames = 0;
    }

    pub fn toggle_pause(&mut self) {
        let Some(playback) = &self.playback else {
            return;
        };
        let paused = &playback.control.paused;
        let next = !paused.load(Ordering::Relaxed);
        paused.store(next, Ordering::Relaxed);
        self.status = if next {
            "Paused".into()
        } else {
            "Play".into()
        };
    }

    pub fn set_volume(&mut self, volume: u8) {
        self.volume = volume.min(100);
        if let Some(playback) = &self.playback {
            playback.control.volume.store(self.volume, Ordering::Relaxed);
        }
    }

    pub fn toggle_bypass(&mut self) {
        self.bypass = !self.bypass;
        if let Some(playback) = &self.playback {
            playback
                .control
                .bypass
                .store(self.bypass, Ordering::Relaxed);
        }
        self.status = if self.bypass {
            "Volume bypass: ON (bit-perfect)"
        } else {
            "Volume bypass: OFF (software gain)"
        }
        .into();
    }

    pub fn seek(&mut self, delta_secs: i64) {
        let Some(playback) = &self.playback else {
            return;
        };
        let current = self.elapsed.as_secs_f64();
        let max = self.total.as_secs_f64();
        let target = (current + delta_secs as f64).clamp(0.0, max.max(0.0));
        let target_duration = Duration::from_secs_f64(target);
        if playback
            .handles
            .commands
            .try_send(DecoderCommand::Seek(target_duration))
            .is_ok()
        {
            self.elapsed = target_duration;
            self.status = format!("Seek -> {:02}:{:02}", target as u64 / 60, target as u64 % 60);
        }
    }

    pub fn next(&mut self) {
        if self.entries.is_empty() {
            return;
        }
        self.move_selection(1);
        self.play_selected();
    }

    pub fn previous(&mut self) {
        if self.entries.is_empty() {
            return;
        }
        self.move_selection(-1);
        self.play_selected();
    }

    /// Dipanggil setiap frame UI. Tidak pernah blocking.
    pub fn poll_events(&mut self) {
        let Some(playback) = self.playback.as_ref() else {
            return;
        };
        loop {
            match playback.handles.events.try_recv() {
                Ok(DecoderEvent::Position {
                    elapsed,
                    total,
                    buffered_frames,
                }) => {
                    self.elapsed = elapsed;
                    if total > Duration::ZERO {
                        self.total = total;
                    }
                    self.buffered_frames = buffered_frames;
                }
                Ok(DecoderEvent::TrackChanged(path)) => {
                    self.now_playing = path
                        .file_name()
                        .map(|n| n.to_string_lossy().into_owned())
                        .unwrap_or_else(|| path.display().to_string());
                }
                Ok(DecoderEvent::GaplessRejected) => {
                    self.status = "Format berubah: gapless tidak bisa, hentikan".into();
                    self.stop();
                    return;
                }
                Ok(DecoderEvent::EndOfQueue) => {
                    self.status = "Selesai".into();
                    self.stop();
                    return;
                }
                Ok(DecoderEvent::Error(err)) => {
                    self.status = format!("ERROR decoder: {err}");
                    warn!("{err}");
                    self.stop();
                    return;
                }
                Err(TryRecvError::Empty) | Err(TryRecvError::Disconnected) => break,
            }
        }

        self.underruns = self
            .playback
            .as_ref()
            .map(|p| p.control.underruns.load(Ordering::Relaxed))
            .unwrap_or(0);
    }
}
