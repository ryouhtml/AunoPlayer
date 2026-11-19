use std::{fs, path::{Path, PathBuf}};

use tracing::warn;

use crate::error::Result;

use super::{cue::parse_cue, metadata::read_metadata, track::LibraryEntry};

pub const AUDIO_EXTENSIONS: &[&str] = &[
    "flac", "wav", "rf64", "aif", "aiff", "alac", "m4a", "dsf", "dff",
];

fn is_audio(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| AUDIO_EXTENSIONS.contains(&e.to_ascii_lowercase().as_str()))
        .unwrap_or(false)
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) -> Result<()> {
    let Ok(entries) = fs::read_dir(dir) else {
        return Ok(());
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            walk(&path, out)?;
        } else {
            out.push(path);
        }
    }
    Ok(())
}

/// Scan folder. File .cue di-expanded menjadi beberapa entri dengan offset.
pub fn scan_dir(root: &Path) -> Result<Vec<LibraryEntry>> {
    let mut files = Vec::new();
    walk(root, &mut files)?;
    files.sort();

    let cue_files: Vec<PathBuf> = files
        .iter()
        .filter(|p| p.extension().and_then(|e| e.to_str()) == Some("cue"))
        .cloned()
        .collect();

    let mut entries = Vec::new();

    for cue_path in &cue_files {
        match parse_cue(cue_path) {
            Ok(sheet) if sheet.audio_file.is_file() => {
                let meta = read_metadata(&sheet.audio_file).unwrap_or_default();
                for track in sheet.tracks {
                    entries.push(LibraryEntry {
                        path: sheet.audio_file.clone(),
                        start: Some(track.start),
                        label: if track.title.is_empty() {
                            format!("{:02}. {}", track.number, sheet.audio_file.display())
                        } else {
                            format!("{:02}. {}", track.number, track.title)
                        },
                        meta: meta.clone(),
                    });
                }
            }
            Ok(_) => warn!("CUE merujuk file yang tidak ada: {}", cue_path.display()),
            Err(err) => warn!("CUE gagal dibaca {}: {err}", cue_path.display()),
        }
    }

    for path in files {
        if !is_audio(&path) {
            continue;
        }
        let meta = read_metadata(&path).unwrap_or_default();
        let label = if meta.title.is_empty() {
            path.file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_else(|| path.display().to_string())
        } else {
            format!("{} — {}", meta.title, meta.artist)
        };
        entries.push(LibraryEntry {
            path,
            meta,
            start: None,
            label,
        });
    }

    entries.sort_by(|a, b| a.path.cmp(&b.path).then(a.start.cmp(&b.start)));
    Ok(entries)
}
