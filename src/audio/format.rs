use std::{fs::File, path::Path};

use symphonia::core::{
    formats::FormatOptions,
    io::MediaSourceStream,
    meta::MetadataOptions,
    probe::Hint,
};

use crate::error::{AunoError, Result};

/// Codec yang didukung. Semua lossless; DSD dikonversi ke PCM (lihat README).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LosslessCodec {
    Flac,
    Wav,
    Aiff,
    Alac,
    Pcm,
    Dsd,
}

impl LosslessCodec {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Flac => "FLAC",
            Self::Wav => "WAV",
            Self::Aiff => "AIFF",
            Self::Alac => "ALAC",
            Self::Pcm => "PCM",
            Self::Dsd => "DSD",
        }
    }

    fn from_extension(ext: &str) -> Option<Self> {
        match ext.to_ascii_lowercase().as_str() {
            "flac" => Some(Self::Flac),
            "wav" | "rf64" => Some(Self::Wav),
            "aif" | "aiff" | "afc" => Some(Self::Aiff),
            "m4a" | "mp4" | "alac" | "caf" => Some(Self::Alac),
            "dsf" | "dff" | "dsd" => Some(Self::Dsd),
            "pcm" | "raw" => Some(Self::Pcm),
            _ => None,
        }
    }
}

/// Tipe sample yang dikirim ke ring buffer dan ke perangkat.
/// 16-bit -> I16, 24/32-bit -> I32 (24-bit left-aligned di dalam 32-bit container).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SampleContainer {
    I16,
    I32,
}

impl SampleContainer {
    pub fn label(self) -> &'static str {
        match self {
            Self::I16 => "PCM16",
            Self::I32 => "PCM24-in-32",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AudioFormat {
    pub sample_rate: u32,
    pub channels: u16,
    pub bits_per_sample: u16,
    pub codec: LosslessCodec,
    pub container: SampleContainer,
}

impl AudioFormat {
    pub fn new(
        sample_rate: u32,
        channels: u16,
        bits_per_sample: u16,
        codec: LosslessCodec,
    ) -> Self {
        Self {
            sample_rate,
            channels,
            bits_per_sample,
            codec,
            container: if bits_per_sample <= 16 {
                SampleContainer::I16
            } else {
                SampleContainer::I32
            },
        }
    }

    /// Dua track bisa di-play gapless hanya jika format output identik.
    /// Ini konsekuensi langsung dari tidak adanya resampling: stream audio
    /// tidak boleh dibuka ulang di tengah transisi.
    pub fn gapless_compatible(self, other: Self) -> bool {
        self.sample_rate == other.sample_rate
            && self.channels == other.channels
            && self.container == other.container
    }

    /// Bitrate PCM mentah (byte/s tidak termasuk overhead container).
    pub fn pcm_bytes_per_sec(self) -> u64 {
        self.sample_rate as u64
            * self.channels as u64
            * self.bits_per_sample as u64
            / 8
    }

    pub fn label(self) -> String {
        format!(
            "{} | {} Hz | {}-bit | {} ch",
            self.codec.as_str(),
            self.sample_rate,
            self.bits_per_sample,
            self.channels
        )
    }

    /// Probe cepat tanpa mendekode seluruh file. Dipakai untuk membuka
    /// perangkat pada sample rate asli sebelum decoder thread dimulai.
    pub fn probe(path: &Path) -> Result<Self> {
        let ext = path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or_default();

        let codec = LosslessCodec::from_extension(ext).ok_or_else(|| {
            AunoError::Unsupported(format!("ekstensi '.{ext}' tidak dikenal"))
        })?;

        if codec == LosslessCodec::Dsd {
            return Self::probe_dsd(path);
        }

        let file = File::open(path)?;
        let mss = MediaSourceStream::new(Box::new(file), Default::default());
        let mut hint = Hint::new();
        if !ext.is_empty() {
            hint.with_extension(ext);
        }

        let probed = symphonia::default::get_probe().format(
            &hint,
            mss,
            &FormatOptions::default(),
            &MetadataOptions::default(),
        )?;

        let track = probed
            .format
            .default_track()
            .ok_or_else(|| AunoError::Decode("tidak ada audio track".into()))?;

        let sample_rate = track.codec_params.sample_rate.ok_or_else(|| {
            AunoError::Decode("sample rate tidak diketahui".into())
        })?;
        let channels = track.codec_params.channels.map_or(2, |c| c.count()) as u16;
        let bits = track.codec_params.bits_per_sample.unwrap_or(32) as u16;

        Ok(Self::new(sample_rate, channels, bits, codec))
    }

    fn probe_dsd(path: &Path) -> Result<Self> {
        let reader = dsd_reader::DsdReader::from_container(path.to_path_buf())
            .map_err(|e| AunoError::Decode(e.to_string()))?;
        let dsd_rate = reader.dsd_rate() as u32;
        let channels = reader.channels_num() as u16;
        let pcm_rate = dsd_pcm::decimation_factor(dsd_rate, 96_000).ok_or_else(|| {
            AunoError::Unsupported(format!("DSD rate {dsd_rate} Hz tidak didukung"))
        })?;

        // dsd-pcm menghasilkan f64, lalu dikuantisasi ke 24-bit.
        Ok(Self::new(pcm_rate, channels, 24, LosslessCodec::Dsd))
    }
}
