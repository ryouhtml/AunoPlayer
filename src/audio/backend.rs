//! Lapisan output audio. Satu-satunya tempat yang menyentuh cpal.
//!
//! CATATAN PENTING (jujut secara teknis):
//! cpal TIDAK menyediakan WASAPI Exclusive / ASIO. Backend bawaan cpal adalah
//! WASAPI shared-mode di Windows, ALSA atau PipeWire di Linux, dan AAudio di
//! Android. Kode ini memaksa sample rate + channel mengikuti file (tanpa
//! resampling di aplikasi), tetapi mixer OS masih aktif di shared mode.
//! Untuk exclusive/ASIO nyata, implementasikan `AudioBackend` memakai crate
//! `wasapi` / `ndsd-asio-sys`.
//!
//! Format sample output dipilih dari kemampuan perangkat:
//!   - Desktop: I32 (24-bit left-aligned, bit-perfect) atau I16.
//!   - Android AAudio: hanya I16 dan F32, jadi 24-bit dikonversi ke F32
//!     di callback (tanpa alokasi, tanpa lock).

use std::{
    sync::{
        atomic::{AtomicBool, AtomicU64, AtomicU8, Ordering},
        Arc,
    },
    time::Duration,
};

use cpal::{
    traits::{DeviceTrait, HostTrait, StreamTrait},
    BufferSize, SampleFormat, Stream, StreamConfig,
};
use ringbuf::traits::Consumer;
use tracing::{error, warn};

use super::{
    format::{AudioFormat, SampleContainer},
    ring::PcmConsumer,
};
use crate::error::{AunoError, Result};

#[derive(Clone, Default)]
pub struct AudioControl {
    pub paused: Arc<AtomicBool>,
    pub volume: Arc<AtomicU8>,
    /// true = bypass software volume (bit tidak diubah sama sekali).
    pub bypass: Arc<AtomicBool>,
    /// Dinaikkan decoder saat seek; callback membuang isi ring lama.
    pub flush_epoch: Arc<AtomicU64>,
    pub underruns: Arc<AtomicU64>,
}

pub trait AudioBackend: Sized + Send {
    fn open(
        format: AudioFormat,
        consumer: PcmConsumer,
        control: AudioControl,
        device_filter: Option<&str>,
    ) -> Result<Self>;

    fn play(&self) -> Result<()>;
    fn pause(&self) -> Result<()>;
    fn device_name(&self) -> &str;
}

pub struct CpalBackend {
    stream: Stream,
    device_name: String,
}

impl AudioBackend for CpalBackend {
    fn open(
        format: AudioFormat,
        consumer: PcmConsumer,
        control: AudioControl,
        device_filter: Option<&str>,
    ) -> Result<Self> {
        let host = select_host();
        let device = select_device(&host, device_filter)?;
        let device_name = device
            .description()
            .map(|d| d.name().to_string())
            .unwrap_or_else(|_| "unknown".into());

        let (config, sample_format) = match_output_config(&device, format)?;
        let error_control = control.clone();
        let error_callback = move |err: cpal::Error| {
            error_control.underruns.fetch_add(1, Ordering::Relaxed);
            error!("cpal stream error: {err}");
        };

        // Tipe output bersifat dinamis, tetapi dipilih SATU KALI di sini.
        // Di dalam callback sudah tidak ada match dinamis / alokasi.
        let stream = match (consumer, sample_format) {
            (PcmConsumer::I16(mut cons), SampleFormat::I16) => device.build_output_stream::<i16, _, _>(
                config,
                {
                    let control = control.clone();
                    let mut epoch = 0u64;
                    move |data: &mut [i16], _| render(&mut cons, data, &control, &mut epoch)
                },
                error_callback.clone(),
                Some(Duration::from_millis(500)),
            )?,
            (PcmConsumer::I16(mut cons), SampleFormat::F32) => device.build_output_stream::<f32, _, _>(
                config,
                {
                    let control = control.clone();
                    let mut epoch = 0u64;
                    move |data: &mut [f32], _| render(&mut cons, data, &control, &mut epoch)
                },
                error_callback.clone(),
                Some(Duration::from_millis(500)),
            )?,
            (PcmConsumer::I16(mut cons), SampleFormat::I32) => device.build_output_stream::<i32, _, _>(
                config,
                {
                    let control = control.clone();
                    let mut epoch = 0u64;
                    move |data: &mut [i32], _| render(&mut cons, data, &control, &mut epoch)
                },
                error_callback.clone(),
                Some(Duration::from_millis(500)),
            )?,
            (PcmConsumer::I32(mut cons), SampleFormat::I32) => device.build_output_stream::<i32, _, _>(
                config,
                {
                    let control = control.clone();
                    let mut epoch = 0u64;
                    move |data: &mut [i32], _| render(&mut cons, data, &control, &mut epoch)
                },
                error_callback.clone(),
                Some(Duration::from_millis(500)),
            )?,
            (PcmConsumer::I32(mut cons), SampleFormat::F32) => device.build_output_stream::<f32, _, _>(
                config,
                {
                    let control = control.clone();
                    let mut epoch = 0u64;
                    move |data: &mut [f32], _| render(&mut cons, data, &control, &mut epoch)
                },
                error_callback.clone(),
                Some(Duration::from_millis(500)),
            )?,
            (PcmConsumer::I32(mut cons), SampleFormat::I16) => device.build_output_stream::<i16, _, _>(
                config,
                {
                    let control = control.clone();
                    let mut epoch = 0u64;
                    move |data: &mut [i16], _| render(&mut cons, data, &control, &mut epoch)
                },
                error_callback,
                Some(Duration::from_millis(500)),
            )?,
            _ => {
                return Err(AunoError::Unsupported(format!(
                    "kombinasi format ring/output tidak didukung: {sample_format}"
                )));
            }
        };

        Ok(Self { stream, device_name })
    }

    fn play(&self) -> Result<()> {
        self.stream.play()?;
        Ok(())
    }

    fn pause(&self) -> Result<()> {
        self.stream.pause()?;
        Ok(())
    }

    fn device_name(&self) -> &str {
        &self.device_name
    }
}

impl CpalBackend {
    pub fn stream(&self) -> &Stream {
        &self.stream
    }

    pub fn device_name(&self) -> &str {
        &self.device_name
    }
}

fn select_host() -> cpal::Host {
    cpal::default_host()
}

fn select_device(host: &cpal::Host, filter: Option<&str>) -> Result<cpal::Device> {
    if let Some(filter) = filter {
        let needle = filter.to_ascii_lowercase();
        let found = host.output_devices()?.find(|d| {
            d.description()
                .map(|desc| desc.name().to_ascii_lowercase().contains(&needle))
                .unwrap_or(false)
        });
        if let Some(device) = found {
            return Ok(device);
        }
        warn!("DAC '{filter}' tidak ditemukan; memakai perangkat default");
    }
    host.default_output_device().ok_or(AunoError::NoDevice)
}

/// Memilih sample rate DAN format sample yang didukung perangkat.
/// Sample rate harus SAMA PERSIS dengan file -- kami tidak pernah diam-diam
/// mengizinkan resampling. Urutan preferensi format menjaga bit-perfect:
///   sumber 16-bit -> I16, F32, I32
///   sumber 24-bit -> I32, F32, I16
fn match_output_config(device: &cpal::Device, format: AudioFormat) -> Result<(StreamConfig, SampleFormat)> {
    let rate = format.sample_rate;
    let ranges: Vec<_> = device.supported_output_configs()?.collect();

    let preferred: &[SampleFormat] = match format.container {
        SampleContainer::I16 => &[SampleFormat::I16, SampleFormat::F32, SampleFormat::I32],
        SampleContainer::I32 => &[SampleFormat::I32, SampleFormat::F32, SampleFormat::I16],
    };

    for desired in preferred {
        for range in &ranges {
            if range.channels() != format.channels
                || range.sample_format() != *desired
                || rate < range.min_sample_rate()
                || rate > range.max_sample_rate()
            {
                continue;
            }
            if let Some(supported) = range.try_with_sample_rate(rate) {
                let mut config = supported.config();
                // Hindari buffer_size fixed yang tidak didukung semua backend.
                config.buffer_size = BufferSize::Default;
                return Ok((config, *desired));
            }
        }
    }

    Err(AunoError::Unsupported(format!(
        "DAC tidak mendukung {} Hz / {} ch / {} secara native (resampling ditolak)",
        format.sample_rate, format.channels, format.container.label()
    )))
}

trait RenderSample: cpal::SizedSample + Default + Copy {
    fn scale(self, gain: f32) -> Self;
}

/// Konversi sample dari tipe ring ke tipe output cpal.
/// Sample i32 dari decoder SELALU left-aligned (24 bit di 32 bit teratas),
/// sehingga pembagian 2^31 untuk f32 dan shift >>16 untuk i16 sudah tepat.
trait RingSample<S> {
    fn from_ring(sample: S) -> Self;
}

impl RenderSample for i16 {
    fn scale(self, gain: f32) -> Self {
        (self as f32 * gain) as i16
    }
}
impl RenderSample for i32 {
    fn scale(self, gain: f32) -> Self {
        // Cast f32->i32 saturating sejak Rust 1.45, aman di callback.
        (self as f32 * gain) as i32
    }
}
impl RenderSample for f32 {
    fn scale(self, gain: f32) -> Self {
        self * gain
    }
}

impl RingSample<i16> for i16 {
    fn from_ring(sample: i16) -> Self { sample }
}
impl RingSample<i32> for i16 {
    fn from_ring(sample: i32) -> Self { (sample >> 16) as i16 }
}
impl RingSample<i16> for i32 {
    fn from_ring(sample: i16) -> Self { (sample as i32) << 16 }
}
impl RingSample<i32> for i32 {
    fn from_ring(sample: i32) -> Self { sample }
}
impl RingSample<i16> for f32 {
    fn from_ring(sample: i16) -> Self { sample as f32 / 32_768.0 }
}
impl RingSample<i32> for f32 {
    fn from_ring(sample: i32) -> Self { sample as f32 / 2_147_483_648.0 }
}

/// Dipanggil oleh cpal pada thread real-time.
/// Aturan: tidak ada alokasi, tidak ada lock, tidak ada syscall, tidak ada panic.
fn render<S, T>(
    cons: &mut ringbuf::HeapCons<S>,
    out: &mut [T],
    control: &AudioControl,
    last_epoch: &mut u64,
) where
    S: Copy,
    T: RenderSample + RingSample<S>,
{
    // Flush ring setelah seek.
    let epoch = control.flush_epoch.load(Ordering::Relaxed);
    if epoch != *last_epoch {
        while cons.try_pop().is_some() {}
        *last_epoch = epoch;
    }

    let paused = control.paused.load(Ordering::Relaxed);
    let mut written = 0usize;
    for slot in out.iter_mut() {
        if paused {
            *slot = T::default();
            continue;
        }
        match cons.try_pop() {
            Some(sample) => {
                *slot = T::from_ring(sample);
                written += 1;
            }
            None => *slot = T::default(),
        }
    }
    if !paused && written < out.len() {
        control.underruns.fetch_add(1, Ordering::Relaxed);
    }

    if !control.bypass.load(Ordering::Relaxed) {
        let gain = control.volume.load(Ordering::Relaxed) as f32 / 100.0;
        if gain < 0.999_99 {
            for slot in out.iter_mut() {
                *slot = slot.scale(gain);
            }
        }
    }
}
