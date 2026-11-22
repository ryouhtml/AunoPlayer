# Spesifikasi Desain: Ekspansi Fitur Auno Player (2026-11-22)

## 1. Ringkasan

Dokumen ini adalah spesifikasi tunggal untuk lima subsystem yang disetujui pengguna:

1. Mengganti **semua** branding visual Flick dengan logo Auno dan menghapus layanan online, **kecuali layanan lirik online**.
2. Menambahkan Bahasa Indonesia secara menyeluruh (~2.000 kunci ARB).
3. Meningkatkan lirik menjadi karaoke kata/suku-kata bergaya BitChord, dengan penyedia lirik online tetap aktif.
4. Meningkatkan pemindaian detail lagu audiophile bergaya Mornye pada engine Rust yang sudah ada.
5. Melengkapi histori dan rekap mendengar bergaya BitChord.

Baseline yang menjadi titik awal adalah commit `c3be702` yang sudah dirilis sebagai `v0.1.0`.

## 2. Keputusan yang Disepakati

| Topik | Keputusan |
|---|---|
| Bentuk dokumen | Satu spec besar untuk kelima subsystem, satu implementation plan dengan 5 fase bergate. |
| Master logo | `assets/icons/auno_logo_square.png` untuk ikon/launcher/splash/widget/notification; `assets/icons/auno_logo.png` untuk logo lebar di UI. `auno_icon.png` ditolak sebagai master karena byte-identik dengan `flicklogo.png`. |
| Cakupan penghapusan | Semua layanan online dihapus **kecuali** pengambilan lirik online. Penghapusan mencakup donasi Ko-fi/BMC, updater + what's-new/changelog, Apple Music/iTunes, Last.fm, ListenBrainz, Tidal, AutoEq cloud, network sources (Subsonic/WebDAV/Jellyfin/UPnP), dan casting (DLNA/Chromecast). |
| Lirik online | Tetap ada dan ditingkatkan meniru BitChord (timing kata/suku-kata dari provider online). |
| Lisensi | Seluruh proyek menjadi **GPL-3.0-or-later**. Kode BitChord (GPL-3.0) dan Mornye (LGPL-3.0/GPLv3) boleh diadaptasi dengan atribusi dan kewajiban source disclosure pada distribusi APK. |
| Terjemahan | Asisten yang membuat `app_id.arb` lengkap; pengguna mengoreksi setelah jadi. |
| Timing karaoke | Word/syllable bila tersedia; fallback reveal per-baris bila tidak ada. Tidak ada auto-estimasi timing. |
| Histori/rekap | Versi lengkap ala BitChord: rekap mingguan/bulanan/tahunan, total durasi, top item, streak, peta waktu, reveal animasi. |
| Scan audiophile | Komprehensif: format/kodek, sample rate, bit depth, bitrate, kanal, DSD/DoP, integritas file, tag, DR, LUFS, true peak, LRA, clipping, spektrum/waveform. |
| Eksekusi | Fase 1 → 2 → 3 → 4 → 5, masing-masing dengan gate verifikasi sebelum lanjut. |

## 3. Invarian (Tidak Boleh Dilanggar)

- Android-only, `minSdk 26`; tidak ada jalur desktop/iOS.
- Bit-perfect / native format output tetap menjadi tujuan; tidak ada resampling atau truncating diam-diam.
- Tanpa iklan, pelacakan, atau premium tier. Satu-satunya izin jaringan yang tersisa adalah `android.permission.INTERNET` untuk lirik online.
- **Tidak ada dependency baru.** Gunakan dependency yang sudah ada (`realfft`, `lofty`, `dsf-meta`, `dff-meta`, `wavpack-sys`, `symphonia`, `hound` untuk test).
- Asisten tidak memasang, meluncurkan, atau menguji di perangkat; pengguna yang melakukan verifikasi hardware.
- Semua teks UI baru harus melalui `l10n`; tidak ada string hard-coded baru.
- Internal identifier (nama class, file, generated getter l10n) yang sudah ada tetap canonical agar diff tetap terkonsentrasi; yang diubah adalah string yang ditampilkan dan aset gambar.

## 4. Arsitektur Umum

```
Fase 1  Branding + penghapusan layanan
   ↓ gate
Fase 2  Bahasa Indonesia (app_id.arb, locale id, regenerate l10n)
   ↓ gate
Fase 3  Karaoke (normalisasi lirik → model span → renderer)
   ↓ gate
Fase 4  Scan audiophile (Rust analysis → bridge → sheet)
   ↓ gate
Fase 5  Histori & rekap (event Isar → agregasi → UI reveal)
```

Data lokal tetap berpusat di `lib/data/database.dart` (Isar). Ada dua schema bump: satu di Fase 1 untuk menghapus koleksi fitur yang dihapus, satu di Fase 5 untuk entitas event dengar. Semua perubahan UI harus mengikuti pola Riverpod + `l10n` yang sudah dipakai.

---

## 5. Fase 1 — Branding & Penghapusan Layanan

### 5.1 Branding

- `flutter_launcher_icons.yaml`: ganti `image_path`, `adaptive_icon_foreground`, dan `adaptive_icon_monochrome` menjadi `assets/icons/auno_logo_square.png`. Jalankan `dart run flutter_launcher_icons` untuk menghasilkan ulang launcher mipmap, adaptive icon, splash, dan notification icon.
- `assets/icons/auno_icon.png` dan semua turunan raster launcher ditimpa dari master square; tidak ada byte Flick yang tersisa.
- `android/app/src/main/res/drawable/widget_ic_flick_logo.xml` dan alias monokrom terkait diarahkan ke drawable Auno yang baru. Nama file drawable internal boleh tetap agar tidak memicu refactor Android yang tidak perlu.
- `lib/features/onboarding/widgets/onboarding_graphics.dart`: hapus `_logoDots` (18 titik Flick) dan ganti dengan `Image.asset('assets/icons/auno_logo.png')` pada slot yang sama di `onboarding_poster.dart`.
- Teks "Auno Player" di `onboarding_screen.dart` sudah benar dan tetap.
- Verifikasi: SHA-256 semua aset gambar yang dikirimkan tidak ada yang sama dengan `flicklogo.png`; grep UI tidak menemukan string "Flick" yang ditampilkan.

### 5.2Penghapusan Layanan

Hapus secara menyeluruh (kode, rute, tile pengaturan, provider, service, entitas Isar usang, izin/dependency Android yang tidak terpakai, dan kunci l10n terkait di semua ARB):

- Donasi: `lib/features/settings/screens/support_flick_screen.dart`, rute, tile, kunci Ko-fi/Buy Me a Coffee.
- Update: `lib/providers/update_check_provider.dart`, `lib/features/whats_new/**` termasuk `changelog_data.dart`, wiring di `lib/app/app.dart`, kunci what's-new/changelog.
- Integrasi: `apple_music_provider.dart`, `services/apple_music/**`, `identify_album_sheet.dart`, Last.fm, `listenbrainz_scrobble_queue` (termasuk flush di `lib/app/app.dart:666`), Tidal, AutoEq cloud lookup (preset offline tetap dipertahankan), network sources (Subsonic/WebDAV/Jellyfin/UPnP), dan casting (DLNA/Chromecast).

**Pengecualian eksplisit:** penyedia lirik online (`lib/services/online_lyrics_service.dart` dan adapter terkait) tidak dihapus. `INTERNET` permission tetap di manifest dan hanya dipakai untuk lirik.

### 5.3 Error Handling, Data, Testing

- Satu-satunya jaringan yang tersisa adalah lirik: setiap request punya timeout dan fallback ke embedded/sidecar tanpa pesan mengganggu.
- Isar: hapus koleksi milik fitur yang dihapus lewat bump versi schema; hanya data fitur tersebut yang terpengaruh.
- Gate: `flutter analyze` + `flutter test` hijau; grep statis nol nama layanan/URL yang dihapus; nol aset gambar identik Flick; lirik online masih dapat diambil.

---

## 6. Fase 2 — Bahasa Indonesia Penuh

- Buat `lib/l10n/app_id.arb` sebagai terjemahan lengkap `app_en.arb`. every key diterjemahkan ke Bahasa Indonesia natural dengan istilah audio yang tepat: *laju sampel, kedalaman bit, rentang dinamis, kanal, laju bit, karaoke, lirik, riwayat, rekap*. Singkatan teknis (FLAC, DSD, DoP, DAC, LUFS, ReplayGain, AutoEQ, Tidal dll. yang masih relevan) tidak diterjemahkan.
- Placeholder `{param}`, sintaks plural ICU, dan metadata `@` dipertahankan persis.
- `lib/l10n/l10n.dart`: tambah `Locale('id')` ke `kSupportedLocales`; resolver menerima `id` dan `id_ID` lewat mekanisme language-code yang sudah ada. Tidak perlu logika script khusus.
- `lib/features/settings/widgets/language_settings_card.dart`: tambah opsi "Bahasa Indonesia".
- Jalankan `flutter gen-l10n` untuk menghasilkan `lib/l10n/generated/app_localizations_id.dart` dan memperbarui `app_localizations.dart`.
- Validasi wajib: (1) paritas kunci 100% antara template dan `app_id.arb`, (2) placeholder identik per kunci, (3) JSON valid, (4) tidak ada kunci yang tertinggal dari hasil Fase 1.
- Fallback gen-l10n ke string Inggris tetap ada sebagai jaring pengaman, tetapi gate mensyaratkan paritas 100%.
- Gate: `flutter analyze` + `flutter test` hijau; skrip paritas lolos; locale `id` dapat dipilih dan dipakai.

---

## 7. Fase 3 — Karaoke ala BitChord

### 7.1 Model & Normalisasi

- Perluas `lib/services/lyrics_service.dart`: `KaraokeLine`, `KaraokeWord`, `KaraokeSyllable` dengan `startMs`, `endMs` opsional, `startChar`/`endChar`, `sungUntilMs`, `background`, `alignment`, dan enum `TimingSource` (`embeddedEnhancedLrc`, `sidecarEnhancedLrc`, `onlineProvider`, `manual`, `lineOnly`).
- Parser enhanced LRC `<mm:ss.xx>` yang sudah ada dipakai ulang. Adapter baru menyatukan embedded, sidecar, provider online, dan manual override menjadi satu model tanpa mengubah API publik `LyricsData` yang sudah dipakai komponen lain.
- Algoritma span (sweep karakter, periode animate, char sung pada posisi tertentu, penanganan gap) diadaptasi dari model `LyricLine`/`LyricWord`/`LyricSyllable` BitChord ke Dart. Karena listen turunan GPL-3.0, sertakan header atribusi di file terkait; proyek sudah GPL-3.0-or-later.

### 7.2 Rendering & Interaksi

- `lib/features/player/widgets/karaoke_lyric_line.dart`: highlight per-karakter dengan sweep halus, tanda baca/jeda tidak ikut tersorong, baris latar, alignment, auto-scroll ke baris aktif, dan tap untuk seek ke baris.
- Provider Riverpod `karaokeControllerProvider`: posisi player → indeks baris aktif + span yang sedang dinyanyikan.
- Pengaturan: toggle karaoke dan pilihan gaya *sweep kata* vs *suku kata*, keduanya via kunci l10n baru.

### 7.3 Error Handling & Gate

- Timestamp malformed → timing kata diabaikan, turun ke reveal per-baris.
- Provider online timeout/gagal → cache lokal/embedded/sidecar; tidak ada auto-estimasi timing.
- Test: parser enhanced LRC (overlap, end hilang, gap), algoritma sweep pada posisi simulasi, widget test baris aktif dan auto-scroll.
- Gate: `flutter analyze` + `flutter test` hijau; karaoke bekerja untuk file dengan word timing dan degrade rapi untuk line-only.

---

## 8. Fase 4 — Scan Detail Audiophile ala Mornye

### 8.1 Engine Rust

Perluas `rust/src/api/audio_analysis.rs` yang sudah melakukan single-pass decode → waveform, BS.1770 LUFS, true peak, DR, LRA, clipping, dan spectrogram via `realfft`:

- Tambah field `AudioSourceAnalysis`: `codec`, `container`, `bitrate_bps`, `channel_layout`, `dsd_variant`, `dop_capable`, `tag_completeness`, `integrity_ok`, `bit_perfect_path`.
- Aktifkan analisis untuk DSF/DFF/WavPack yang sekarang diskip, memakai `dsf-meta`, `dff-meta`, dan `wavpack-sys` yang sudah ada. Tetap satu pass, bisa dibatalkan, dan lapor progres lewat `AudioSourceAnalysisJob`.
- `bit_perfect_path` dihitung dari konfigurasi jalur output engine: `true` bila sample rate/bit depth sumber dikirim apa adanya tanpa resampling.
- Tidak ada dependency Cargo baru.

### 8.2 UI

`lib/features/player/widgets/audio_analysis_sheet.dart` diperluas menjadi bagian:

1. **Format** — kodek, kontainer, sample rate, bit depth, kanal, layout, bitrate, ukuran file, durasi.
2. **DSD/Hi-Res** — variant (DSF/DFF), DoP capable, badge Hi-Res.
3. **Dinamika** — LUFS, true peak, DR, LRA, clipping, target −18 LUFS (nilai sudah ada di `_suggestedGainTargetLufs`).
4. **Spektrum & waveform** — visualisasi yang sudah ada dipertahankan.
5. **Integritas & tag** — hasil read pass dan kelengkapan tag dari `lofty`.
6. **Jalur output** — status bit-perfect / akan di-resample.

Aksi lokal: simpan laporan sebagai file teks/JSON di direktori aplikasi. Tidak ada pengiriman atau share online.

### 8.3 Error Handling & Gate

- `UnsupportedFormat`, `UnsupportedMultichannel`, `Unreadable`, `NoAudioStream`, `NoSamples`, `Busy`, `Cancelled` tetap ditampilkan jelas dengan opsi retry untuk status yang retryable.
- Content-URI, cue in/out, dan sourceType network tetap ditolak seperti perilaku sekarang (`audioAnalysisUnavailableReason`).
- Analisis DSD yang gagal tetap menampilkan metadata tag, bukan layar kosong.
- Test: unit test Rust dengan fixture WAV/FLAC/DSD dari `hound` (dev-dependency sudah ada), test field baru, widget test sheet dengan data lengkap dan sebagian.
- Gate: `cargo test --lib --manifest-path rust/Cargo.toml` + `flutter analyze` + `flutter test` hijau; metrik tampil untuk file lokal; nol dependency baru.

---

## 9. Fase 5 — Histori & Rekap ala BitChord

### 9.1 Data

- Entitas baru `lib/data/entities/listening_event_entity.dart` di `lib/data/database.dart`: `songId`, `playedAt`, `listenedMs`, `completedRatio`, dan snapshot `title`, `artist`, `album` agar rekap tetap benar saat file dihapus. Index pada `playedAt` dan `songId`.
- `recently_played_entity.dart` tetap dipakai untuk tampilan "terakhir diputar".
- Player service mencatat event saat putar dimulai dan saat selesai/dijeda; menghitung **waktu dengar aktual**, bukan durasi file. `sessionId` mencegah dobel hitung saat pause/resume.
- Isar schema bump + backfill dari histori lama yang masih tersedia.

### 9.2 Agregasi & UI

- `lib/services/listening_stats_service.dart`: bucket harian/mingguan/bulanan/tahunan; total durasi; jumlah putar; top lagu, artis, album; streak beruntun; peta jam mendengar; pendengaran pertama; kartu kepribadian dengar.
- `lib/features/recap/screens/listening_recap_screen.dart` dan `replay_studio_screen.dart`: period selector, reveal bertahap, poster yang bisa disimpan sebagai gambar lokal (tanpa share online). Widget yang sudah ada (`replay_reveal.dart`, `replay_poster.dart`, `replay_sections.dart`) diperluas, tidak ditimpa.
- `lib/features/recently_played/screens/recently_played_screen.dart`: pencarian dan ringkasan statistik.

### 9.3 Error Handling & Gate

- File hilang → pakai snapshot judul/artis/album.
- Perubahan jam sistem → clamp ke rentang wajar.
- Event gagal ditulis → playback tidak terganggu.
- Test: repository dengan in-memory Isar, agregasi (streak, dedupe, bucket), widget test reveal dan period selector.
- Gate: `flutter analyze` + `flutter test` hijau; histori tidak dobel hitung; rekap menampilkan data nyata; semua data lokal.

---

## 10. Lisensi & Atribusi

- `LICENSE` diganti menjadi GPL-3.0-or-later.
- Tambah `NOTICE` dengan atribusi:
  - BitChord (`https://github.com/kushagrasinghx/BitChord`, GPL-3.0) — pola model lirik karaoke, histori, dan rekap.
  - Mornye (`https://github.com/mornyeapp/Mornye`, LGPL-3.0-only + GPLv3) — pendekatan pemindaian detail audiophile.
  - Flick (MIT) — baseline kode asal yang tetap dihormati.
- File yang berisi algoritma turunan menyertakan header lisensi/atribusi sesuai sumbernya.
- Rilis APK harus menyertakan atau menautkan source code lengkap sesuai kewajiban GPL.

## 11. Testing & Kriteria Gate Keseluruhan

| Gate | Perintah / pemeriksaan |
|---|---|
| Setiap fase | `flutter analyze`, `flutter test` |
| Fase 1 | SHA aset vs `flicklogo.png`; grep layanan online; grep string "Flick" yang ditampilkan |
| Fase 2 | Skrip paritas kunci ARB + placeholder; `flutter gen-l10n` |
| Fase 4 | `cargo test --lib --manifest-path rust/Cargo.toml` |
| Fase 5 | Test Isar in-memory + agregasi |
| Final | Build APK via GitHub Actions; publish oleh pengguna; verifikasi hardware oleh pengguna |

## 12. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Kualitas ~2.000 terjemahan | Asisten membuat draf lengkap, pengguna mengoreksi istilah sensitif sebelum rilis. |
| Kewajiban source disclosure GPL | `NOTICE` + tautan source di halaman rilis; lisensi diperbarui di Fase 1. |
| Analisis DSD berat di perangkat | Single-pass, bisa dibatalkan, progress, dan `nice` thread; fallback metadata bila gagal. |
| Migrasi Isar | Dua schema bump terkontrol + backfill; test migration dengan DB lama. |
| Provider lirik online berubah/putus | Timeout + cache lokal + fallback embedded/sidecar; tidak ada layanan pengganti yang ditambahkan tanpa alasan. |
| Tanpa verifikasi hardware oleh asisten | Semua pernyataan akhir dibedakan antara verifikasi lokal (otomatis) dan hasil hardware yang dikonfirmasi pengguna. |

## 13. Definition of Done

1. Kelima fase selesai dan gate masing-masing hijau.
2. Tidak ada aset visual Flick yang terpasang; tidak ada donasi/update/integrasi online selain lirik.
3. Bahasa Indonesia dapat dipilih dengan paritas kunci 100%.
4. Karaoke menampilkan sweep kata/suku kata dari sumber lokal maupun online, dengan fallback yang rapi.
5. Sheet analisis audiophile menampilkan metrik komprehensif termasuk DSD dan integritas, tanpa dependency baru.
6. Histori dan rekap menampilkan statistik nyata dari event lokal, tanpa dobel hitung.
7. `LICENSE`, `NOTICE`, dan halaman rilis memenuhi kewajiban GPL-3.0-or-later.
8. APK dibangun ulang dan dipublikasikan oleh pengguna; hash publish helper diperbarui ke commit akhir.
9. Asisten menyatakan secara eksplisit mana yang terverifikasi otomatis dan mana yang menunggu konfirmasi hardware pengguna.

## 14. Referensi File Utama

- Branding: `flutter_launcher_icons.yaml`, `assets/icons/auno_logo_square.png`, `assets/icons/auno_logo.png`, `lib/features/onboarding/widgets/onboarding_graphics.dart`, `android/app/src/main/res/drawable/widget_ic_flick_logo.xml`
- Penghapusan: `lib/features/settings/screens/support_flick_screen.dart`, `lib/features/settings/screens/integrations_settings_screen.dart`, `lib/providers/update_check_provider.dart`, `lib/features/whats_new/**`, `lib/app/app.dart`
- i18n: `lib/l10n/app_en.arb`, `lib/l10n/l10n.dart`, `lib/features/settings/widgets/language_settings_card.dart`, `l10n.yaml`
- Lirik: `lib/services/lyrics_service.dart`, `lib/features/player/widgets/karaoke_lyric_line.dart`
- Audio: `rust/src/api/audio_analysis.rs`, `lib/features/player/widgets/audio_analysis_sheet.dart`, `rust/Cargo.toml`
- Rekap: `lib/data/entities/recently_played_entity.dart`, `lib/data/repositories/recently_played_repository.dart`, `lib/features/recap/**`, `lib/features/recently_played/**`
- Rilis: `docs/RELEASING.md`, `C:\Users\Administrator\AppData\Local\Temp\opencode\publish-apk.ps1`
