//! Parser CUE sheet minimalis (tanpa dependency tambahan).
//! Mendukung FILE, TRACK, TITLE, PERFORMER, dan INDEX 01.

use std::{fs, path::{Path, PathBuf}, time::Duration};

use crate::error::{AunoError, Result};

#[derive(Debug, Clone)]
pub struct CueTrack {
    pub number: u32,
    pub title: String,
    pub performer: String,
    pub start: Duration,
}

#[derive(Debug, Clone)]
pub struct CueSheet {
    pub audio_file: PathBuf,
    pub tracks: Vec<CueTrack>,
}

fn unquote(value: &str) -> String {
    let trimmed = value.trim();
    if trimmed.len() >= 2 && trimmed.starts_with('"') && trimmed.ends_with('"') {
        trimmed[1..trimmed.len() - 1].to_string()
    } else {
        trimmed.to_string()
    }
}

fn parse_index(value: &str) -> Result<Duration> {
    // INDEX 01 mm:ss:ff  (ff = 1/75 detik)
    let mut parts = value.split_whitespace();
    let _number = parts.next();
    let timecode = parts
        .next()
        .ok_or_else(|| AunoError::Decode("INDEX tanpa timecode".into()))?;
    let fields: Vec<u64> = timecode
        .split(':')
        .map(|v| v.parse::<u64>().map_err(|e| AunoError::Decode(e.to_string())))
        .collect::<Result<Vec<_>>>()?;
    if fields.len() != 3 {
        return Err(AunoError::Decode(format!("timecode CUE invalid: {timecode}")));
    }
    let millis = fields[0] * 60_000 + fields[1] * 1000 + (fields[2] * 1000) / 75;
    Ok(Duration::from_millis(millis))
}

pub fn parse_cue(path: &Path) -> Result<CueSheet> {
    let content = fs::read_to_string(path)?;
    let base = path.parent().unwrap_or_else(|| Path::new("."));
    let mut audio_file: Option<PathBuf> = None;
    let mut tracks: Vec<CueTrack> = Vec::new();

    for raw in content.lines() {
        let line = raw.trim();
        let keyword = line.split_whitespace().next().unwrap_or_default();

        match keyword {
            "FILE" => {
                if let Some(start) = line.find('"') {
                    let rest = &line[start + 1..];
                    if let Some(end) = rest.find('"') {
                        audio_file = Some(base.join(&rest[..end]));
                    }
                }
            }
            "TRACK" => {
                let number = line
                    .split_whitespace()
                    .nth(1)
                    .and_then(|v| v.parse::<u32>().ok())
                    .unwrap_or(0);
                tracks.push(CueTrack {
                    number,
                    title: String::new(),
                    performer: String::new(),
                    start: Duration::ZERO,
                });
            }
            "TITLE" | "PERFORMER" => {
                if let Some(track) = tracks.last_mut() {
                    let value = unquote(line[keyword.len()..].trim_start());
                    if keyword == "TITLE" {
                        track.title = value;
                    } else {
                        track.performer = value;
                    }
                }
            }
            "INDEX" => {
                if let Some(track) = tracks.last_mut() {
                    if line.split_whitespace().nth(1) == Some("01") {
                        track.start = parse_index(line)?;
                    }
                }
            }
            _ => {}
        }
    }

    Ok(CueSheet {
        audio_file: audio_file.ok_or_else(|| AunoError::Decode("CUE tanpa FILE".into()))?,
        tracks,
    })
}
