# Security Policy

Auno Player is an offline-first Android music player: your library stays on the
device, there is no account system, and the app does not phone home. Network
access is limited to optional online lyrics lookup the user configures.

## Supported versions

Only the latest release and the latest commit on `main` are supported. Betas on
the GitHub releases page and the Play Store build track the same code.

## Reporting a vulnerability

**Do not open a public issue for security problems.**

- Preferred: use GitHub's private vulnerability reporting —
  [Report a vulnerability](https://github.com/ryouhtml/AunoPlayer/security/advisories/new).
- Or email **fyketonel@gmail.com** with steps to reproduce.

You should get a response within a few days. Please include the app version,
device/Android version, and as much detail as you can without exposing real
credentials or private file paths.

## In scope

- Unsafe Rust FFI or memory-safety issues in the audio engine
  (Symphonia, rusb, cpal/Oboe, wavpack-sys, flutter_rust_bridge boundary)
- Path traversal or unintended file access in the library scanner, SAF, or
  metadata write-back
- USB DAC / UAC 2.0 handling issues that could expose or corrupt data
- Unexpected network traffic beyond user-configured features
- Android surface issues (exported components, deep links, permissions)

## Out of scope

- Issues in third-party providers or dependencies — report those upstream
  (LRCLib, Symphonia, …)
- Compromised, rooted, or physically accessed devices
- Denial of service from malformed local media files you chose to open
- Social engineering

## Design guarantees we aim to uphold

- No ads, no tracking, no premium tier, no telemetry.
- Library data lives in the local Isar database; the app does not upload it.
- Network calls only happen for features the user enabled.

Thank you for helping keep users safe.
