# Auno Player

Offline, low-footprint audiophile player. One Rust core powers both the desktop
TUI and the Android app.

## Features

- Bit-perfect playback: no resampling, no software volume (bypass by default).
- FLAC / WAV / AIFF / ALAC / raw PCM, plus DSD (DSF/DFF) converted to 24-bit PCM.
- Gapless playback between tracks with identical output format (SPSC `ringbuf`,
  decoder isolated from the audio callback).
- Metadata via `lofty` and `.cue` track splitting.
- Live format / output device info: codec, sample rate, bit depth, channels,
  PCM bitrate, active DAC, buffer level and underruns.

## Desktop

```sh
cargo build --release
./target/release/auno-player
```

## Android

The Gradle project lives in `android/`. Native libraries are produced from the
same Rust crate via `cargo-ndk` and placed in `android/app/src/main/jniLibs`.

`.github/workflows/build-apk.yml` builds `app-debug.apk` for `arm64-v8a`,
`armeabi-v7a` and `x86_64` and uploads it as a workflow artifact.

Audio files are imported with **Import audio** and stored under the app's
private `files/Music` directory; the Rust scanner indexes that directory.
Minimum Android version is 26 (AAudio).
