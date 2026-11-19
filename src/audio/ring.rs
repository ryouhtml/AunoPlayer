//! Ring buffer SPSC yang dialokasikan sekali di awal.
//! Producer = decoder thread, Consumer = audio callback.
//! Tidak ada locking, tidak ada alokasi, tidak ada syscall di callback.

use ringbuf::{
    traits::{Observer, Producer, Split},
    HeapCons, HeapProd, HeapRb,
};

use super::format::SampleContainer;

pub enum PcmProducer {
    I16(HeapProd<i16>),
    I32(HeapProd<i32>),
}

pub enum PcmConsumer {
    I16(HeapCons<i16>),
    I32(HeapCons<i32>),
}

pub struct PcmRing {
    pub producer: PcmProducer,
    pub consumer: PcmConsumer,
}

impl PcmRing {
    /// `frames` = jumlah frame yang bisa ditampung (±0.5 detik audio).
    pub fn new(container: SampleContainer, frames: usize, channels: u16) -> Self {
        let capacity = frames * channels as usize;
        match container {
            SampleContainer::I16 => {
                let rb = HeapRb::<i16>::new(capacity);
                let (producer, consumer) = rb.split();
                Self {
                    producer: PcmProducer::I16(producer),
                    consumer: PcmConsumer::I16(consumer),
                }
            }
            SampleContainer::I32 => {
                let rb = HeapRb::<i32>::new(capacity);
                let (producer, consumer) = rb.split();
                Self {
                    producer: PcmProducer::I32(producer),
                    consumer: PcmConsumer::I32(consumer),
                }
            }
        }
    }
}

impl PcmProducer {
    pub fn len(&self) -> usize {
        match self {
            Self::I16(p) => p.occupied_len(),
            Self::I32(p) => p.occupied_len(),
        }
    }

    pub fn capacity(&self) -> usize {
        match self {
            Self::I16(p) => p.capacity().get(),
            Self::I32(p) => p.capacity().get(),
        }
    }

    /// Input selalu i32 interleaved dari `SampleBuffer<i32>` symphonia.
    /// Untuk 16-bit kita compress ke i16 di sini (sekali, di decoder thread).
    pub fn push_interleaved(&mut self, samples: &[i32]) {
        match self {
            Self::I16(p) => {
                for &s in samples {
                    if p.try_push((s >> 16) as i16).is_err() {
                        break;
                    }
                }
            }
            Self::I32(p) => {
                p.push_slice(samples);
            }
        }
    }
}
