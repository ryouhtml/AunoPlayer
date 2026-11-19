//! Auno Player core.
//!
//! The desktop TUI binary and the Android `cdylib` share this exact crate:
//! both drive `player::Session`, so there is a single playback implementation.

pub mod android;
pub mod audio;
pub mod error;
pub mod library;
pub mod player;
pub mod ui;

pub use error::{AunoError, Result};
pub use player::Session;
