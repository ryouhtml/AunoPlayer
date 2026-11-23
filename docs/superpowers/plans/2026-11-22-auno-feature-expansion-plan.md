# Implementation Plan: Ekspansi Fitur Auno Player

Spesifikasi sumber: `docs/superpowers/specs/2026-11-22-auno-feature-expansion-design.md` (commit `9fafb92`).
Plan ini dibuat dengan `make-plan`; Phase 0 (documentation discovery) sudah dijalankan dengan tiga subagent dan temuannya diringkas di bawah.

Perintah global yang dipakai berulang:

```
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter_rust_bridge_codegen generate
flutter analyze --no-fatal-infos
flutter test
cargo test --lib --manifest-path rust/Cargo.toml
dart run flutter_launcher_icons
```

---

## Phase 0 — Documentation Discovery (SELESAI)

### Allowed APIs (terverify dari source)

| Kebutuhan | API / fakta | Sumber |
|---|---|---|
| Locale resolver | `kSupportedLocales`, `resolveSupportedLocale`, `LocaleController.instance.select` | `lib/l10n/l10n.dart:46-51,88-117,168-174` |
| Baris pemilih bahasa | pola `SelectionSetting` untuk `Español`/`Taglish` | `lib/features/settings/widgets/language_settings_card.dart:43-57` |
| Konfigurasi l10n | `arb-dir`, `template-arb-file`, `output-dir` | `l10n.yaml:3-10` |
| Master ikon | `auno_logo_square.png` / `auno_logo.png` | spec `:20`; `flutter_launcher_icons.yaml:6-15`; `pubspec.yaml:91-96,110-133` |
| Model lirik | `LyricsWord`, `LyricsLine`, `LyricsData`, `LyricsSaveResult` | `lib/services/lyrics_service.dart:11-65` |
| Helper karaoke | `findCurrentLineIndex`, `tokenMatches`, `splitKaraokeWord`, `fillForWord`, `resolveWords` | `lib/services/lyrics_service.dart:260-394` |
| Parser word timing | `_wordTimestampPattern`, `_extractWords`, `parseLyricsText`, `buildLrcContent` | `lib/services/lyrics_service.dart:68-84,396-501` |
| Renderer karaoke | `KaraokeLyricLine` + `_resolveWords`/`fillForWord`/`ShaderMask` | `lib/features/player/widgets/karaoke_lyric_line.dart:14-207` |
| Online lyrics | `OnlineLyricsService.fetchExact/search`, `OnlineLyricsResult`, cache 8s/50 entri, LRCLib | `lib/services/online_lyrics_service.dart:1-227` |
| Preferensi karaoke | `karaokeEnabled` (default `true`) | `lib/services/app_preferences_service.dart:136,267,922`; `lib/providers/app_preferences_provider.dart:474-475` |
| Analisis Rust | `AudioSourceAnalysis`, `AudioSourceSpectrogram`, `AudioSourceAnalysisStatus`, `AudioSourceAnalysisJob` (`create/cancel/progress/analyze`) | `rust/src/api/audio_analysis.rs:21-28,347-460` |
| Binding FRB | `analyzeAudioFile`, `createSourceAudioAnalysisJob`, job `analyze/cancel/progress` | `lib/src/rust/api/audio_analysis.dart:13-38` |
| Sheet analisis | `audioAnalysisUnavailableReason`, `_retryableStatuses`, `showAudioAnalysisSheet` | `lib/features/player/widgets/audio_analysis_sheet.dart:21-59` |
| Isar | `Database.init()` + schema list + `MDBX_INCOMPATIBLE` recovery; **tanpa app-version integer** | `lib/data/database.dart:21-124` |
| Konvensi field baru | `@Name('z...')` agar property ID stabil | `lib/data/entities/artist_entity.dart:18-29`; `test/data/artist_entity_schema_test.dart:5-13` |
| Repository histori | `RecentlyPlayedRepository.recordPlay/getListeningRecap(s)/watchHistory`, `ListeningRecap*` models | `lib/data/repositories/recently_played_repository.dart:10-203,206-427,523-643` |
| Tracker putar | `ReplayPlayTracker` ambang 30 detik, dipanggil dari `PlayerService._trackReplayProgress` | `lib/services/replay_play_tracker.dart:1-82`; `lib/services/player_service.dart:3872-3943` |
| Recap UI | `ListeningRecapScreen`, `ReplayStudioScreen`, `ReplayReveal`, `ReplayPoster`, `ReplaySections` | `lib/features/recap/screens/*.dart`; `lib/features/recap/widgets/*.dart` |
| Codegen | `build.yaml` membatasi Isar generator ke `lib/data/**`; CI menjalankan build_runner | `build.yaml:1-9`; `.github/workflows/ci.yml:108-120` |

### Anti-pattern guards (dari discovery)

- Jangan mengedit file hasil generator (`lib/src/rust/frb_generated.dart`, `lib/src/rust/api/*.dart`, `*.g.dart`) secara manual — regenerasi dengan codegen.
- Jangan mengubah API publik `LyricsData`/`LyricsService` yang dipakai `full_player_screen.dart`, `share_bottom_sheet.dart`, dan editor lirik.
- Jangan mengarang app schema-version integer; Isar memakai ID property stabil + recovery `MDBX_INCOMPATIBLE`.
- Jangan menebak timing kata saat sumber tidak memilikinya.
- Jangan menambah dependency Flutter/Cargo baru.
- Jangan menghapus `http`/`url_launcher` sebelum audit: keduanya dipakai lirik online. `in_app_update` adalah kandidat hapus (updater-only).
- Jangan mengabaikan test Rust `source_analysis_rejects_dsd` — harus diperbarui saat DSD diaktifkan.
- Jangan memaksa recap Bahasa Indonesia ke copy Inggris: `lib/l10n/replay_l10n.dart:1-14` saat ini memaksa `englishForFilipino`.
- Jangan menyentuh perangkat/install/launch; verifikasi hardware adalah pengguna.

### Known gaps Phase 0
- Enumerasi lengkap kunci ARB tidak dibuat di discovery; gate Fase 1/2 harus memakai diff kunci aktual dari `app_en.arb` pasca-penghapusan.
- Aset raster/native belum di-SHA saat discovery; gate Fase 1 wajib mengecek.
- Kode sumber BitChord/Mornye belum dibaca baris per baris; adaptasi dibatasi pada pola/arsitektur + atribusi.

---

## Phase 1 — Branding & Penghapusan Layanan

**Tujuan:** tidak ada satu pun piksel/string Flick, dan tidak ada layanan online kecuali lirik.

### 1.1 Branding
- Ubah `flutter_launcher_icons.yaml:7,11,15` dan `pubspec.yaml:92,95,96` dari `auno_icon.png` ke `assets/icons/auno_logo_square.png`.
- Hapus deklarasi aset `flicklogo.png`, `flicklogo_svg.svg`, `flicklogo_transparent.png` di `pubspec.yaml:114-116` bila sudah tidak direferensikan; timpa `auno_icon.png` dan mipmap dari master square.
- `android/app/src/main/res/drawable/widget_ic_flick_logo.xml` dan `widget_flick_logo.xml`: retarget ke drawable Auno; nama file tetap.
- `lib/features/onboarding/widgets/onboarding_graphics.dart:308-353`: hapus `_logoDots`, gunakan `Image.asset('assets/icons/auno_logo.png')` pada slot `onboarding_poster.dart:51,101,142`.
- Jalankan `dart run flutter_launcher_icons`; regenerasi mipmap/adaptive/splash/notification.

### 1.2 Hapus donasi
- Hapus `lib/features/settings/screens/support_flick_screen.dart` dan `lib/features/settings/widgets/donation_coffee_icon.dart`.
- Cabut 4 call site: `settings_screen.dart:386-399`, `app_info_settings_screen.dart:47-71,823-840`, `menu_screen.dart:384-385`, `replay_studio_screen.dart:779-792`.
- Cabut `settings_search_catalog.dart:780-784` dan copy donasi di `milestone_service.dart:110-136`.
- Hapus kunci ARB: `donate`, `donateFundFeaturesAndKeepThe`, `flickWillAlwaysBeFreeDonations`, `filipinoDonationNote`, `koFi`, `buyMeACoffee`, `buyMeACoffeeDescription` (dan turunannya dari hasil diff).

### 1.3 Hapus updater + what's-new
- Hapus `lib/providers/update_check_provider.dart`, `lib/providers/whats_new_provider.dart`, `lib/features/whats_new/**`, `lib/services/github_release_service.dart` (jika tidak dipakai fitur lain).
- Cabut wiring `lib/app/app.dart:173,354,362,458-487,662` dan export di `lib/providers/providers.dart:11-12,29,32-33`.
- Hapus `in_app_update` dari `pubspec.yaml:69`; audit `http`/`url_launcher` sebelum menghapus.
- Perbarui `docs/RELEASING.md:33-42` agar tidak menyebut channel update dalam aplikasi.

### 1.4 Hapus integrasi
- Hapus tile di `integrations_settings_screen.dart` dan file `apple_music_settings_tile.dart`, `lastfm_settings_tile.dart`, `listenbrainz_settings_tile.dart`, lalu hapus layar integrasi jika tidak ada isi.
- Hapus provider/service: `apple_music_provider.dart(.g.dart)`, `lastfm_provider.dart`, `listenbrainz_provider.dart`, `services/apple_music/**`, `services/lastfm/**`, `services/listenbrainz/**`; cabut export di `providers.dart`.
- Cabut UI terkait: `identify_album_sheet.dart`, `album_detail_screen.dart:371-464,511-518`, `artist_detail_screen.dart:155-198,439-515,604-614,789-790`, `missing_metadata_screen.dart:5,52`, `artist_artwork_service.dart:14,88`, `artist_entity.dart:18` (field `zArtSource`/`zArtCheckedAt` bila hanya dipakai Apple Music).
- Cabut scrobble di `app.dart:630-668`, termasuk `listenbrainzScrobbleQueueProvider.flush()` di `:666`.
- Hapus source network: `services/sources/{tidal,network_source,subsonic,jellyfin,webdav,upnp,smb}_service.dart`, `network_sources_screen.dart`, `network_server_edit_screen.dart`, kategori `settings_screen.dart:133-143`, search `settings_search_catalog.dart:109-117`, `network_server_entity.dart`, field `sourceType` di `song_entity.dart:140` bila tidak dipakai lokal.
- Hapus casting: `services/casting/**`, `cast_provider.dart`, `casting_settings_screen.dart`, `settings_screen.dart:201-211`, `settings_search_catalog.dart:277-289`; native `CastController.kt`, `CastOptionsProvider.kt`, `DlnaRouteProviderService.kt`, `MainActivity.kt:107-109,173-175,1113-1194,1459-1476`, `MusicNotificationService.kt:61-63,112-127,198-220,521-557,578-647,695-708`; Gradle `android/app/build.gradle.kts:232-234`.
- Manifest `AndroidManifest.xml`: hapus `:38-40`, `:96-103`, `:164-175`; tulis ulang komentar `INTERNET` di `:4-5` menjadi "hanya untuk lirik online".
- AutoEq: hapus `fetchOnline` di `lib/services/autoeq_catalog_service.dart:224-350` dan UI online di `autoeq_search_sheet.dart:58-187,334,402,466-514`; **pertahankan** `assets/autoeq/autoeq_catalog.json` dan `autoeq_brands.json`.

### 1.5 Data & lisensi
- Keluarkan `NetworkServerEntitySchema` dari schema list `lib/data/database.dart:38-45` dan getter `networkServers` `:120-124`. Bersihkan sisa koleksi via satu kali cleanup saat `init()` bila perlu; jangan memperkenalkan app-version integer.
- Jalankan `dart run build_runner build --delete-conflicting-outputs`.
- Ganti `LICENSE` menjadi GPL-3.0-or-later dan tambah `NOTICE` (BitChord, Mornye, Flick/MIT).

### Verification checklist — Phase 1
Status 2026-11-23: implementasi Phase 1 selesai di `feature/auno-fase1`; codegen/analyze/test masih harus dijalankan di CI karena toolchain Flutter/Dart tidak tersedia lokal.
- [ ] `dart run flutter_launcher_icons` sukses; mipmap/adaptive/notification/splash berasal dari `auno_logo_square.png`.
- [ ] Skrip SHA: tidak ada aset gambar yang sama dengan `flicklogo.png`.
- [ ] `grep -ri "flick" lib android/app/src/main/res` hanya menemukan identifier internal/komentar, bukan string yang ditampilkan atau aset.
- [ ] `grep -riE "ko-fi|buymeacoffee|lastfm|listenbrainz|tidal|chromecast|dlna|github.com/ryouhtml|api.github.com" lib android app` kembali kosong, kecuali komentar sejarah bila perlu.
- [ ] `grep` tetap menemukan `lrclib.net` dan `INTERNET` permission.
- [ ] `flutter gen-l10n`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze --no-fatal-infos`, `flutter test`.
- [x] Kunci ARB yang dihapus tidak menyisakan referensi getter di Dart (script lokal, 2026-11-23).

### Anti-pattern guards — Phase 1
- Jangan menghapus `http`/`url_launcher` tanpa grep pemakaian lirik online.
- Jangan mengganti nama file drawable internal; cukup retarget isinya.
- Jangan menghapus preset AutoEq lokal.
- Jangan memakai `rm -rf` pada direktori source; hapus file yang sudah dipastikan tidak diimpor.

---

## Phase 2 — Bahasa Indonesia Penuh

**Tujuan:** `app_id.arb` 100% paritas dengan template pasca-Fase-1, locale `id` dapat dipilih.

### 2.1 Implementasi
- Generate `lib/l10n/app_id.arb` dari **template hasil Fase 1**, menerjemahkan setiap kunci ke Bahasa Indonesia natural; istilah: *laju sampel, kedalaman bit, rentang dinamis, kanal, laju bit, karaoke, lirik, riwayat, rekap*. Pertahankan `{param}`, ICU plural, metadata `@`; singkatan teknis tidak diterjemahkan.
- `lib/l10n/l10n.dart:46-51`: tambah `Locale('id')`. Resolver `:105-109` otomatis menerima `id`/`id_ID`.
- `lib/features/settings/widgets/language_settings_card.dart`: klon baris `Español` (`:43-49`) menjadi `Bahasa Indonesia` dengan `selected: selectedLocale?.languageCode == 'id'` dan `LocaleController.instance.select(const Locale('id'))`.
- `flutter gen-l10n` → hasilkan `app_localizations_id.dart` dan perbarui `app_localizations.dart` (`supportedLocales` di `:8-11,98-104`).
- `lib/l10n/replay_l10n.dart:1-14`: jangan paksa copy Inggris untuk locale `id`; gunakan hasil localisasi Indonesia.
- Skrip validasi (taruh di `tool/check_arb_parity.dart` atau sejenisnya): bandingkan keyset template vs `app_id.arb`, bandingkan placeholder per kunci, valid JSON.

### Verification checklist — Phase 2
- [ ] Skrip paritas: 0 kunci hilang, 0 kunci ekstra, 0 placeholder mismatch di semua locale.
- [ ] `flutter gen-l10n` sukses; `app_localizations_id.dart` ada dan terdaftar.
- [ ] `flutter analyze --no-fatal-infos`, `flutter test`.
- [ ] Widget test: memilih Bahasa Indonesia mengubah teks UI dan tersimpan di `AppPreferencesService`.
- [ ] Recap/player memakai string Indonesia, bukan paksaan Inggris.

### Anti-pattern guards — Phase 2
- Jangan menerjemahkan kunci yang sudah dihapus di Fase 1.
- Jangan mengubah `kFallbackLocale` dari `en`.
- Jangan menambah logika script kh seperti Baybayin untuk `id`.

---

## Phase 3 — Karaoke ala BitChord

**Tujuan:** model span kata/suku kata terpadu, renderer sweep halus, fallback baris tanpa menebak.

### 3.1 Model & normalisasi
- Di `lib/services/lyrics_service.dart`, tambah model baru `KaraokeLine`, `KaraokeWord`, `KaraokeSyllable` (field `startMs/endMs/startChar/endChar/sungUntilMs/background/alignment`) dan enum `TimingSource` (`embeddedEnhancedLrc`, `sidecarEnhancedLrc`, `onlineProvider`, `manual`, `lineOnly`) — kopi pola `LyricsWord`/`LyricsLine` di `:11-40`, jangan ubah keduanya.
- Tambah adapter `KaraokeLyricsNormalizer` yang mengubah hasil parser existing (`:396-501`) + hasil `OnlineLyricsResult.syncedLyrics` (`lib/services/online_lyrics_service.dart:5-83`) menjadi model baru. Copy pola load order manual → embedded → sidecar dari `loadLyricsForSong` (`:86-129`).
- Port algoritma spanBitChord (`wordSpans`, `sweepSpans`, `revealedChars`, `charsSungAt`) ke helper Dart baru di `lib/services/karaoke_spans.dart`, dengan header atribusi GPL-3.0.
- Terapkan aturan: timestamp malformed/end hilang → `lineOnly`; tidak ada auto-estimasi.

### 3.2 State & renderer
- Tambah `karaokeControllerProvider` (Riverpod) yang menerima posisi dari `PlayerService`/`positionNotifier` dan menghasilkan baris aktif + span; ikuti pola provider di `lib/providers/` (bukan mengubah API `LyricsService`).
- Perluas `lib/features/player/widgets/karaoke_lyric_line.dart:14-207`: dukung suku kata, baris latar, alignment, tap-untuk-seek, dan span model baru; pertahankan `ShaderMask`/`LinearGradient` yang sudah ada (`:189-207`) dan ticker (`:49-176`).
- Perbarui caller `synced_lyrics_view.dart:380-414,434-467` dan `lyrics_sync_screen.dart:1600-1634`.
- Tambah preferensi gaya sweep kata vs suku kata di `app_preferences_service.dart` dengan `@Name` bila disimpan, plus kunci ARB baru di semua locale (enkapsulasi aturan Fase 2).

### Verification checklist — Phase 3
- [ ] Unit test parser/span: overlap, end hilang, gap, suku kata, `lineOnly`.
- [ ] Test `karaokeControllerProvider`: posisi → baris aktif dan fill yang benar; pause tidak meloncat.
- [ ] Widget test: sweep kata/suku kata, tap seek, auto-scroll, baris latar.
- [ ] Test regresi lama tetap hijau: `test/services/lyrics_word_timing_test.dart`, `test/features/player/karaoke_word_split_test.dart`.
- [ ] `flutter analyze --no-fatal-infos`, `flutter test`; kunci ARB baru terparitas di semua locale.
- [ ] Online lyrics LRCLib masih bisa dicari/disimpan (`online_lyrics_search_sheet.dart`) dan hasilnya masuk normalizer.

### Anti-pattern guards — Phase 3
- Jangan mengubah signature `loadLyricsForSong`, `resolveWords`, `buildLrcContent`, atau `LyricsData`.
- Jangan menebak timing untuk file `lineOnly`.
- Jangan menghapus `http` client 8 detik / cache LRCLib.
- Jangan hard-code string; semua lewat `l10n`.

---

## Phase 4 — Scan Detail Audiophile

**Tujuan:** `AudioSourceAnalysis` lebih kaya, DSD/WavPack ikut dianalisis, UI informatif, tanpa dependency baru.

### 4.1 Rust
- Di `rust/src/api/audio_analysis.rs:370-391`, tambah field: `codec`, `container`, `bitrate_bps`, `channel_layout`, `dsd_variant`, `dop_capable`, `tag_completeness`, `integrity_ok`, `bit_perfect_path`. Semua bertipe Option/<primitive> yang didukung FRB.
- Kopi pola single-pass + job dari `:393-460`. Aktifkan DSF/DFF/WavPack yang sekarang ditolak di `:130-133`, memakai `dsf-meta`, `dff-meta`, `wavpack-sys` (sudah ada di `rust/Cargo.toml:16-92`). Bila decode penuh tidak memungkinkan, kembalikan metadata dari `lofty` + status jelas, jangan layar kosong.
- Hitung `codec/container/bitrate/channel_layout` dari `symphonia` + `lofty`; `integrity_ok` dari satu read pass; `bit_perfect_path` dari konfigurasi engine (tanpa resampling).
- Update test `source_analysis_rejects_dsd` (`:1547`) menjadi test DSD sukses/fallback; tambah test field baru. Pertahankan test lain (`:1210-1639`).
- Regenerasi binding: `flutter_rust_bridge_codegen generate` (konfigurasi `flutter_rust_bridge.yaml:1-3`). Jangan edit `lib/src/rust/api/*` manual.

### 4.2 UI
- Di `lib/features/player/widgets/audio_analysis_sheet.dart`, hapus penolakan `song.isDsd`/`song.isWavPack` dari `audioAnalysisUnavailableReason` (`:45-46`) setelah engine mendukung; pertahankan penolakan network/cue/content-URI.
- Bangun 6 bagian UI seperti spec `:136-145`, kopi pola status+retry dari `:21-27,109-181` dan rendering spektrum yang ada.
- Tambah aksi "simpan laporan lokal" (teks/JSON) ke direktori aplikasi; tanpa shareOnline.
- Tambah kunci ARB baru di semua locale.

### Verification checklist — Phase 4
- [ ] `cargo test --lib --manifest-path rust/Cargo.toml` hijau, termasuk test DSD baru.
- [ ] `flutter_rust_bridge_codegen generate` sukses; binding baru terlihat di `lib/src/rust/api/audio_analysis.dart`.
- [ ] Widget test sheet: data lengkap, data sebagian, status `Busy`/`Cancelled`, retry.
- [ ] `flutter analyze --no-fatal-infos`, `flutter test`; ARB paritas terjaga.
- [ ] Tidak ada entri baru di `rust/Cargo.toml` / `pubspec.yaml`.

### Anti-pattern guards — Phase 4
- Jangan buat engine analisis paralel; perluas file yang ada.
- Jangan mengubah `AudioSourceAnalysisJob` semantics (cancel sticky, progress 0..1, `Busy` saat lock gagal).
- Jangan mengabaikan test lama yang menolak multichannel/content-URI.
- Jangan mengirim laporan ke layanan online.

---

## Phase 5 — Histori & Rekap ala BitChord

**Tujuan:** event dengar aktual + agregasi lengkap + reveal, tanpa dobel hitung.

### 5.1 Data event
- Buat `lib/data/entities/listening_event_entity.dart` dengan `@collection`, field `songId`, `sessionId`, `playedAt`, `listenedMs`, `completedRatio`, `title`, `artist`, `album`. Gunakan `@Name('z...')` untuk field baru bila menambah ke entitas existing; ikuti `recently_played_entity.dart:1-17` dan konvensi `artist_entity.dart:18-29`.
- Daftarkan `ListeningEventEntitySchema` di `lib/data/database.dart:38-45` dan tambah getter collection di `:104-124`; tambah test schema-ID seperti `test/data/artist_entity_schema_test.dart:5-13`.
- `dart run build_runner build --delete-conflicting-outputs`.

### 5.2 Pencatatan
- Perluas `lib/services/replay_play_tracker.dart:1-82` untuk menghasilkan `sessionId` dan mengukur `listenedMs` aktual (bukan durasi file), dengan dedupe pause/resume. Kopi pola constructor injectable `now` untuk test deterministik.
- Wire di `lib/services/player_service.dart:3872-3943` dan `:4072-4187`: pada ambang dengar, tulis `ListeningEvent`; `recentlyPlayed.recordPlay` tetap dipanggil agar widget/history lama tidak rusak.
- Jangan mencatat pada `pause` atau `complete` secara terpisah bila sudah tercatat di ambang — hindari dobel hitung.

### 5.3 Agregasi & UI
- Buat `lib/services/listening_stats_service.dart` dengan input `ListeningEvent` + fallback ke `RecentlyPlayedRepository.getListeningRecap(s)` (`recently_played_repository.dart:348-394`) bila event baru belum ada. Hitung: total durasi, jumlah putar, top lagu/artis/album, streak, peta jam, pendengaran pertama, kartu kepribadian.
- Perluas `ListeningRecap` / buat model turunan di repository agar UI bisa menerima statistik baru tanpa mengubah konstruktor `ListeningRecapScreen({this.repository})` (`listening_recap_screen.dart:18-26`).
- Perluas `listening_recap_screen.dart`, `replay_studio_screen.dart`, dan widget `replay_reveal.dart`/`replay_poster.dart`/`replay_sections.dart` untuk period selector, reveal bertahap, dan poster lokal. Pertahankan `GallerySaveService`/`CsvExportService` yang sudah ada (`:186-271`).
- `recently_played_screen.dart`: pencarian + ringkasan statistik.
- Tambah kunci ARB baru di semua locale, termasuk `app_id.arb`.

### Verification checklist — Phase 5
- [ ] Test repository dengan real-Isar harness (`test/services/webdav_sync_integration_test.dart:51-118`) untuk write/read/index event.
- [ ] Test agregasi: streak, dedupe session, bucket harian/mingguan/bulanan/tahunan, fallback ke data lama.
- [ ] Widget test recap dengan fake repository (`test/features/recap/listening_recap_screen_test.dart:31-50,144-254`) untuk period selector dan reveal.
- [ ] `flutter analyze --no-fatal-infos`, `flutter test`.
- [ ] Tidak ada data yang dikirim keluar perangkat.

### Anti-pattern guards — Phase 5
- Jangan memperkenalkan app schema-version integer; pakai konvensi `@Name('z...')` + schema-ID test.
- Jangan mengganti `recordPlay` lama secara mendadak; gunakan fallback.
- Jangan memaksa copy Inggris untuk recap Indonesia (`replay_l10n.dart`).
- Jangan menghapus widget `Replay*` yang sudah ada; perluas.

---

## Final Phase — Verification & Release Handoff

1. Jalankan semua gate: `flutter gen-l10n`, `dart run build_runner build --delete-conflicting-outputs`, `flutter_rust_bridge_codegen generate`, `flutter analyze --no-fatal-infos`, `flutter test`, `cargo test --lib --manifest-path rust/Cargo.toml`.
2. Audit anti-pattern: grep API hasil generator yang diedit manual, dependency baru, string hard-coded, layanan online (kecuali LRCLib), aset Flick.
3. Cek paritas ARB 100% untuk semua locale, termasuk kunci baru Fase 3–5.
4. Verifikasi `LICENSE` GPL-3.0-or-later + `NOTICE` atribusi dan kewajiban source disclosure di halaman rilis.
5. Build APK lewat GitHub Actions (CI `.github/workflows/ci.yml`); **jangan** memasang/menjalankan di perangkat.
6. Update `$sha` di `C:\Users\Administrator\AppData\Local\Temp\opencode\publish-apk.ps1` dari `c3be702` ke commit final, lalu minta pengguna melakukan publish dan verifikasi hardware.
7. Laporkan secara terpisah: (a) verifikasi otomatis lokal yang hijau, (b) hasil yang masih menunggu konfirmasi pengguna di perangkat.
