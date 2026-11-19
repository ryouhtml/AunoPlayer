use thiserror::Error;

pub type Result<T> = std::result::Result<T, AunoError>;

#[derive(Debug, Error)]
pub enum AunoError {
    #[error("I/O: {0}")]
    Io(#[from] std::io::Error),

    #[error("audio device: {0}")]
    Audio(#[from] cpal::Error),

    #[error("decode: {0}")]
    Decode(String),

    #[error("unsupported: {0}")]
    Unsupported(String),

    #[error("metadata: {0}")]
    Metadata(String),

    #[error("device not available")]
    NoDevice,

    #[error("channel closed")]
    ChannelClosed,
}

impl From<symphonia::core::errors::Error> for AunoError {
    fn from(err: symphonia::core::errors::Error) -> Self {
        AunoError::Decode(err.to_string())
    }
}

impl<T> From<crossbeam_channel::SendError<T>> for AunoError {
    fn from(_: crossbeam_channel::SendError<T>) -> Self {
        Self::ChannelClosed
    }
}

pub fn decode<E: std::fmt::Display>(e: E) -> AunoError {
    AunoError::Decode(e.to_string())
}
