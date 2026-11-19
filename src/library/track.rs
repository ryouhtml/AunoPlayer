use std::{path::PathBuf, time::Duration};

use crate::audio::AudioFormat;

#[derive(Debug, Clone, Default)]
pub struct TrackMeta {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration: Duration,
    pub sample_rate: u32,
    pub channels: u16,
    pub bits_per_sample: u16,
}

/// Satu entri di library. Bisa berupa file utuh atau region dari CUE sheet.
#[derive(Debug, Clone)]
pub struct LibraryEntry {
    pub path: PathBuf,
    pub meta: TrackMeta,
    /// Offset awal untuk track hasil pemisahan CUE.
    pub start: Option<Duration>,
    pub label: String,
}

impl LibraryEntry {
    pub fn format(&self) -> crate::error::Result<AudioFormat> {
        // Probe file asli lebih akurat daripada tag: tag bisa salah atau kosong.
        AudioFormat::probe(&self.path)
    }
}
