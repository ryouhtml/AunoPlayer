use std::{path::Path, time::Duration};

use lofty::{
    file::{AudioFile, TaggedFileExt},
    tag::ItemKey,
};

use crate::error::{AunoError, Result};

use super::track::TrackMeta;

/// Membaca Vorbis Comment (FLAC), ID3v2, MP4 ilst, dan APE via lofty.
pub fn read_metadata(path: &Path) -> Result<TrackMeta> {
    let tagged = lofty::read_from_path(path).map_err(|e| AunoError::Metadata(e.to_string()))?;
    let tag = tagged.primary_tag();

    let pick = |keys: &[ItemKey]| -> String {
        let Some(tag) = tag else {
            return String::new();
        };
        for &key in keys {
            if let Some(value) = tag.get_string(key) {
                return value.to_string();
            }
        }
        String::new()
    };

    let props = tagged.properties();
    Ok(TrackMeta {
        title: pick(&[ItemKey::TrackTitle]),
        artist: pick(&[ItemKey::TrackArtist, ItemKey::AlbumArtist]),
        album: pick(&[ItemKey::AlbumTitle]),
        duration: Duration::from_secs(props.duration().as_secs()),
        sample_rate: props.sample_rate().unwrap_or(0),
        channels: props.channels().unwrap_or(0) as u16,
        bits_per_sample: props.bit_depth().unwrap_or(0) as u16,
    })
}
