# Implementation Plan: Redesain Library & Full Player Auno Player

Spesifikasi sumber: `docs/superpowers/specs/2026-11-28-library-player-redesign-design.md` (commit `f51382d`).
Plan ini dibuat dengan `make-plan`; Phase 0 dijalankan dengan tiga subagent dan temuannya diringkas di bawah.

Toolchain Flutter/Dart/Rust tidak tersedia lokal, jadi **gate setiap fase** adalah: commit → push ke `feature/auno-fase1` → dispatch `ci.yml` lewat `workflow_dispatch` dengan ref branch tersebut → pantau dengan `C:\Users\Administrator\AppData\Local\Temp\opencode\ci.ps1 -Sha <7-char> -Watch`. Lanjut ke fase berikutnya hanya bila hijau. Jangan push ke `main`.

---

## Phase 0 — Documentation Discovery (SELESAI)

### Allowed APIs (terverifikasi dari source)

| Kebutuhan | API / fakta | Sumber |
|---|---|---|
| Mode library default | `SongsViewModeNotifier.build()` mengembalikan `SongViewMode.orbit`; `SongsScreen` mengarahkan semua non-list ke `_buildOrbitView` | `lib/providers/songs_view_mode_provider.dart:15-22`; `lib/features/songs/screens/songs_screen.dart:388-392` |
| Kontrol orbit | `OrbitScrollController.jumpToIndex(int, {bool animate = true})`, attach/detach di init/dispose | `lib/features/songs/widgets/orbit_scroll.dart:17-31,185,191-194,235` |
| Transform & gestur orbit | scale/opacity via `AppMotionMath.bell`/`lerpBell`; drag → `FrictionSimulation`, snap spring; `_dragExtent` | `orbit_scroll.dart:797-843,312-452,508-510`; `lib/core/motion/app_motion.dart:87-99` |
| Kartu & state retention | `SongCard` punya `scale/opacity/isSelected/onTap/onSwipeLeft/onSwipeRight/onOpenActions`; `_cardFace` di-cache; kunci pada `Positioned` menjaga state | `song_card.dart:73-94,105-151,249-275`; `orbit_scroll.dart:855-861` |
| Play + buka player | `_playSongAndOpenPlayer` memanggil `play(...)` lalu `NavigationHelper.navigateToFullPlayer(context, heroTag: 'song_art_${id}')` | `songs_screen.dart:1379-1399` |
| Hero sudah ada | `FullPlayerScreen(heroTag: heroTag)`; `SongStage._heroWrapped` membungkus saat `heroTag != null` | `lib/core/utils/navigation_helper.dart:38-107`; `lib/features/player/widgets/song_stage.dart:142-153` |
| Mode player | `PlayerScreenMode.{immersive,artworkCard}`; mode disimpan lokal via `PlayerScreenModePreferenceService`, bukan Riverpod | `lib/models/player_screen_mode.dart:1-22`; `full_player_screen.dart:65-66,195-215` |
| Artwork | `AlbumArtBox` punya `showFrame`, `size`, recognizer putar/double-tap/rotation-seek; **belum** punya `fullBleed` | `album_art_box.dart:24-33,61-63,94-102,324-390,437-514` |
| Badge format nyata | `song.fileType`, `dsdRateLabel`, `resolution`, `BitPerfectIndicator` | `player_action_button_row.dart:129-179`; `song_metadata_sheet.dart:61-67` |
| Kontrol | `PlayerControls` punya transport + progress, **tidak** punya parameter favorite | `player_controls.dart:34-47` |
| Lirik | `SyncedLyricsView(playerService, lyricsService, lyrics, albumColor, positionNotifier, active)` merender `ListView.builder` penuh, belum ada mode strip | `synced_lyrics_view.dart:45-53,559-630`; `inline_lyrics_panel.dart:364-375` |
| Inspector | `showAudioAnalysisSheet(context, song)`, `audioAnalysisUnavailableReason`, null test dari `sideMidDb` | `audio_analysis_sheet.dart:34-74,503-629,1175-1185` |
| Queue | `QueueScreen` punya `SliverReorderableList` + `moveQueueItem/moveUpNextItem`, tapi membungkus `Scaffold` dan header melakukan `Navigator.pop()` | `queue_screen.dart:16-21,93-317,378-445` |
| Carousel | `SongStageCarousel(currentSong,nextSong,prevSong,stageBuilder,onNext,onPrevious,enabled,onDragStateChanged)`; commit 320 ms `easeOutCubic`; swipe ambang 28%/700 | `song_stage_carousel.dart:31-41,49-52,145-197,242-303` |
| Chrome player | `_buildTopChrome(...)` memuat chevron, chip queue (drag kiri → queue), more-vert; gesture vertikal outer dismiss di `:1158-1195` | `full_player_screen.dart:804-956,1158-1195` |
| Sensor gerak | `MediaQuery.disableAnimationsOf(context)` dipakai di orbit, mini player, lirik; `AppConstants` 150/300/500 ms | `orbit_scroll.dart:410`; `app_constants.dart:12-22` |
| l10n | `context.l10n` extension; global `l10n` dari `english_l10n.dart` untuk screen lama; 2476 kunci paritas di en/id/es/tl/zh; pilot Baybayin tepat 11 kunci | `l10n.dart:64-86`; `english_l10n.dart:1-13`; `arb_invariants_test.dart:107-127`; `baybayin_pilot_test.dart:137-179` |
| Guard l10n | Skrip Python ada di `%TEMP%\opencode\` (bukan di repo). Guard dalam repo adalah test Flutter | `scan_hardcoded.py`, `check_arb.py`, `check_getters.py`, `check_new_keys_referenced.py`; `test/l10n/*.dart` |
| CI & artifact | `ci.yml`: rust-checks, rust-test, dart-checks (`pub get` → `gen-l10n` → `build_runner` → `analyze --no-fatal-infos` → `test`). Trigger: `main` + `workflow_dispatch`. `build-apk.yml` artifact `auno-player-full-release` | `.github/workflows/ci.yml:3-8,18-125`; `build-apk.yml:3-6,105-110` |

### Anti-pattern guards (dari discovery)

- Jangan mengarang API: `AlbumArtBox.fullBleed` dan mode strip lirik belum ada—harus ditambahkan dulu.
- Jangan memindahkan favorite ke `PlayerControls`; favorite tetap di action row/sheet.
- Jangan memakai tag Hero `song-art-<id>`; canonical adalah `song_art_<id>`.
- Jangan menaruh panel queue langsung sebagai `QueueScreen` (ada `Scaffold` + `pop()`); ekstrak badannya.
- Jangan mengubah timing lirik atau menambah MD5/copy/share palsu.
- Jangan menambah dependency Flutter/Cargo.
- Jangan menambah kunci ke `app_tl_Tglg.arb`.
- Jangan mengklaim guard Python ada di repo; panggil dari `%TEMP%\opencode\` bila dipakai.
- Jangan menjalankan/mengunduh APK ke laptop; artifact hanya dilaporkan dari Actions.
- Jangan menyentuh perangkat; verifikasi tampilan hardware tetap pengguna.

### Known gaps Phase 0

- Belum ada test khusus `FullPlayerScreen`, `SongStage`, `SongStageCarousel`, atau queue panel; test baru perlu dibuat.
- Hero belum membungkus artwork pada jalur immersive portrait/full view; perlu ditambahkan.
- `graphify-out/graph.json` tidak ada; graphify tidak dipakai.
- Tidak ada verifikasi hardware/local Flutter pada phase discovery.

---

## Phase 1 — Wheel library mengganti orbit default

**Tujuan:** library utama menjadi roda silinder 3D dengan state/interaksi lama tetap utuh.

### 1.1 Yang dikerjakan

- Buat helper murni `lib/features/songs/widgets/wheel_transform.dart`:
  - `double wheelScale(double distance)`, `double wheelOpacity(double distance)`, `double wheelAngle(double distance)`, `Matrix4 wheelMatrix(...)`.
  - Kurva mengikuti referensi: skala `1.04 → 0.96 → 0.84 → min 0.72`; opacity `1.0 → 0.85 → 0.55 → 0.25`; sudut silinder dibatasi (bukan rotasi penuh).
- Buat `lib/features/songs/widgets/wheel_song_list.dart`:
  - Terima `songs`, `selectedIndex`, `OrbitScrollController`, callback yang sama persis dengan `_buildOrbitView` (`songs_screen.dart:519-548`).
  - Salin pola drag/fling/spring dari `orbit_scroll.dart:312-452` dan cache transform dari `:161-164,195-210`.
  - Bungkus `SongCard` dengan `Transform(matrix: wheelMatrix(...))`; `scale/opacity` tetap diteruskan ke `SongCard` supaya `_cardFace` tidak rebuild tiap frame.
  - Render hanya ±3 kartu; tepi disamarkan gradient.
  - Tambah `Semantics` dari `l10n` dan cabang `MediaQuery.disableAnimationsOf` (tanpa rotasi/EQ).
- Di `songs_screen.dart`, ganti pemanggilan `_buildOrbitView(...)` dengan `WheelSongList(...)` pada cabang non-list. Jangan mengubah enum `SongViewMode`, default provider, daftar, grid album, fast index, multi-select, atau `_playSongAndOpenPlayer`.
- Pastikan tap memanggil `_playSongAndOpenPlayer` (sudah memutar sebelum push), swipe kiri/kanan dan `onOpenActions` tetap memanggil handler lama.

### 1.2 Referensi dokumen

- Kurva & struktur: spec `§4`; HTML referensi pertama.
- Salinan API: `songs_screen.dart:460-551`; `orbit_scroll.dart:17-31,312-452,782-905`; `song_card.dart:73-94,249-275`.
- Test harness: `test/features/songs/orbit_scroll_test.dart:20-86,144-224`; `song_card_test.dart:16-49,174-204`.

### 1.3 Verification checklist

- [ ] `wheelScale/opacity/angle` memiliki unit test untuk `d = 0,1,2,3,>3`.
- [ ] Test fling berhenti di indeks terdekat; `jumpToIndex` masih bekerja dari fast index.
- [ ] Test tap memanggil play + navigasi; mode pilih hanya toggle seleksi.
- [ ] Test reduce-motion: tidak ada matriks rotasi/EQ, callback tetap jalan.
- [ ] `grep` tidak menemukan string UI baru di luar ARB.
- [ ] Gate CI fase ini hijau.

### 1.4 Anti-pattern guards

- Jangan menghapus `OrbitScroll`; widget lama masih dipakai `orbit_preview.dart` dan preferensi.
- Jangan mengubah `SongCard` secara destruktif; bungkus dari luar.
- Jangan mengubah urutan mode album/grid yang dikendalikan `SongSortOption.album`.

---

## Phase 2 — Artwork full-bleed & badge metadata di immersive

**Tujuan:** destination Hero tersedia dan player immersive menyerupai referensi tanpa mengubah mode/gesture lama.

### 2.1 Yang dikerjakan

- Tambah parameter `bool fullBleed = false` pada `AlbumArtBox` (`album_art_box.dart:24-33`).
  - Saat `fullBleed`, resolusi `size` memakai lebar layar dan tinggi ~56% layar; `showFrame:false`; fade bawah ke warna permukaan.
  - Pertahankan `DoubleTapGestureRecognizer`, `TapGestureRecognizer`, `_RotationSeekRecognizer`, dan `_buildArtContent` apa adanya.
- Di `song_stage.dart`:
  - Gunakan `AlbumArtBox(fullBleed: true)` pada jalur immersive full view (ganti `CachedImageWidget` di `:493-519`). Pada immersive portrait default, tetap tampilkan artwork (boleh non-full-bleed) supaya Hero selalu punya tujuan saat halaman dibuka.
  - Bungkus keduanya dengan `_heroWrapped(..., heroTag)`; hanya lagu aktif yang diberi tag (pola `full_player_screen.dart:1401,1547-1548,1812`).
- Tambah baris metadata ringkas di immersive: judul marquee, artist, badge dari `fileType`/`dsdRateLabel`/`bitDepth`/`sampleRate`/`resolution`; salin logika dari `player_action_button_row.dart:129-179` dan `song_metadata_sheet.dart:61-67`. Sembunyikan badge bila data null.
- `PlayerControls` dan progress bar tidak diubah; favorite tetap di `PlayerActionButtonRow`/action sheet.

### 2.2 Referensi dokumen

- Spec `§5.1`; `album_art_box.dart:24-33,324-390,437-514`; `song_stage.dart:142-153,287-524`; `player_action_button_row.dart:129-228`.

### 2.3 Verification checklist

- [ ] Widget test: `AlbumArtBox(fullBleed:true)` tidak membuang recognizer lama.
- [ ] Widget test: hanya satu Hero dengan tag `song_art_<id>` untuk lagu aktif.
- [ ] Widget test: badge tampil untuk metadata lengkap dan hilang untuk metadata null.
- [ ] `artworkCard` mode tidak berubah (bandingkan widget tree sebelum/sesudah).
- [ ] Gate CI fase ini hijau.

### 2.4 Anti-pattern guards

- Jangan mengganti `AlbumArtBox` dengan `Image.asset`/`CachedImageWidget` biasa di jalur immersive.
- Jangan menambah parameter favorite ke `PlayerControls`.
- Jangan mengubah `PlayerScreenMode` atau preferensinya.

---

## Phase 3 — Animasi zoom thumbnail ke artwork player

**Tujuan:** tap kartu library terasa "zoom" dari thumbnail ke artwork player.

### 3.1 Yang dikerjakan

- Di `WheelSongList`, bungkus thumbnail setiap kartu yang terlihat dengan `Hero(tag: 'song_art_${song.id}', transitionOnUserGestures: true)`. Tag harus identik dengan yang dikirim `_playSongAndOpenPlayer` dan diterima `NavigationHelper`/`FullPlayerScreen`.
- Pastikan urutan: feedback skala turun → `playerProvider.notifier.play(...)` → `navigateToFullPlayer(...)` (urutan sudah ada di `songs_screen.dart:1379-1399`; jangan dibalik).
- Perbesar durasi transisi ke ~320 ms `easeOutCubic` hanya untuk Hero/overlay ini; jangan mengubah `AppConstants` global. Bila `Hero` bentrok dengan `SongStageCarousel`, pakai `Overlay` animasi dengan kurva sama (fallback spec `§6`).
- Reduce-motion: lewati `Hero`, pakai fade singkat.
- Mode pilih: tidak ada playback, tidak ada Hero flight.

### 3.2 Referensi dokumen

- Spec `§6`; `navigation_helper.dart:38-107`; `songs_screen.dart:1379-1399`; `song_stage.dart:142-153`; `song_stage_carousel.dart:162-197`.

### 3.3 Verification checklist

- [ ] Test mencocokkan tag Hero di wheel dan player untuk id yang sama.
- [ ] Test playback dipanggil sebelum navigasi.
- [ ] Test reduce-motion tidak memasang Hero.
- [ ] Test multi-select tidak memutar/mengirim Hero.
- [ ] Gate CI fase ini hijau.

### 3.4 Anti-pattern guards

- Jangan memakai tag `song-art-...`.
- Jangan mengubah `NavigationHelper.navigateToFullPlayer` signature.
- Jangan mengubah transisi global aplikasi.

---

## Phase 4 — Lirik strip & audio inspector

**Tujuan:** lirik aktif terlihat di bawah kontrol dan detail teknis bisa dibuka dari player.

### 4.1 Yang dikerjakan

- Tambah presentasi `strip` pada penampil lirik yang ada (bukan widget lirik baru): satu baris aktif dari `LyricsData` yang sama dengan `SyncedLyricsView`, memakai `positionNotifier` dan indeks baris aktif yang sudah ada. Tap strip memanggil `_setLyricsMode(true/false)` (`full_player_screen.dart:244-258`). Tidak ada estimasi timing.
- Tambah entri **Audio inspector** di `SongActionsSheet` di samping “Lihat metadata” (`song_actions_sheet.dart:238-257`), memanggil `showAudioAnalysisSheet(context, song)` (`audio_analysis_sheet.dart:53-61`). Pertahankan `audioAnalysisUnavailableReason` gate.
- Tetap tidak menambah MD5/copy/share palsu; null test tetap dari `sideMidDb`.

### 4.2 Referensi dokumen

- Spec `§5.2`; `synced_lyrics_view.dart:45-53,559-630`; `inline_lyrics_panel.dart:364-375`; `full_player_screen.dart:244-258`; `audio_analysis_sheet.dart:34-74,1175-1185`; `song_actions_sheet.dart:238-257`.

### 4.3 Verification checklist

- [ ] Test strip menampilkan baris aktif dari `LyricsData` deterministik dan tap mengubah mode lirik.
- [ ] Test inspector tidak muncul saat `audioAnalysisUnavailableReason` non-null.
- [ ] Test tidak ada string timing/MD5 hard-coded.
- [ ] Gate CI fase ini hijau.

### 4.4 Anti-pattern guards

- Jangan membuat parser lirik kedua atau mengisi timing otomatis.
- Jangan mengganti `AudioAnalysisSheet` dengan sheet statis.

---

## Phase 5 — Panel queue & swipe navigasi chrome

**Tujuan:** Now Playing ↔ Queue bisa di-swipe tanpa mengganggu swipe lagu di artwork.

### 5.1 Yang dikerjakan

- Ekstrak badan `QueueScreen` (`queue_screen.dart:93-317`) menjadi widget reusable, mis. `QueuePanel`, tanpa `Scaffold` dan tanpa `_Header` yang memanggil `Navigator.pop()`. `QueueScreen` tetap memakai widget tersebut agar rute lama tidak berubah.
- Di `FullPlayerScreen`, tambahkan state halaman lokal (`nowPlaying`/`queue`) dan `PageController` untuk panel. Pasang handler horizontal hanya pada chrome header/metadata (`_buildTopChrome`, `:804-956`).
- Prioritas gesture:
  - abaikan bila `_isCarouselDragging == true` (`full_player_screen.dart:98,1345,1479-1480,1753`);
  - tidak menimpa drag chip queue lama (`primaryVelocity < -400` di `:836-847`);
  - tidak menimpa edge dismiss vertikal (`:1158-1195`, edge 32 px).
- Panel memakai `SliverReorderableList` hasil ekstraksi; reorder tetap memanggil `moveQueueItem`/`moveUpNextItem`.

### 5.2 Referensi dokumen

- Spec `§5.3`; `queue_screen.dart:93-317,378-445`; `full_player_screen.dart:804-956,1158-1195`; `song_stage_carousel.dart:49-52,327-334`.

### 5.3 Verification checklist

- [ ] Test swipe chrome berpindah halaman; swipe pada artwork tetap mengganti lagu.
- [ ] Test reorder queue masih memanggil provider yang benar.
- [ ] Test rute `NavigationHelper.navigateToQueue` masih terbuka dari snackbar.
- [ ] Gate CI fase ini hijau.

### 5.4 Anti-pattern guards

- Jangan memasang `GestureDetector` horizontal di seluruh halaman.
- Jangan menghapus `_Header` rute queue lama.
- Jangan mengubah `SongStageCarousel` thresholder kecuali ada bukti test gagal.

---

## Phase 6 — l10n, guard, CI, dan artifact (final)

**Tujuan:** semua copy lokal, CI hijau, APK dibangun tanpa download.

### 6.1 Yang dikerjakan

- Tambah kunci ARB baru (mis. label inspector, aksesibilitas wheel, badge) ke `app_en.arb`, `app_id.arb`, `app_es.arb`, `app_tl.arb`, `app_zh.arb` dengan placeholder paritas. Akses melalui `context.l10n` atau global `l10n` sesuai pola file yang disentuh. Jangan sentuh `app_tl_Tglg.arb`.
- Jalankan guard lokal dari `%TEMP%\opencode\`: `scan_hardcoded.py`, `check_arb.py`, `check_getters.py`, `check_new_keys_referenced.py`.
- Pastikan guard dalam repo lulus di CI: `arb_invariants_test.dart`, `source_guard_test.dart`, `hardcoded_english_test.dart`, `spanish_arb_test.dart`, `baybayin_pilot_test.dart`.
- Commit + push, dispatch `ci.yml` via `workflow_dispatch` (ref `feature/auno-fase1`), pantau dengan `ci.ps1 -Sha <sha> -Watch`.
- Setelah hijau, dispatch `build-apk.yml` dengan `build_apk.ps1 -Ref feature/auno-fase1 -Sha <sha>`; laporkan `ARTIFACT_URL` saja. Jangan download.
- Jalankan `graphify update .` bila tool tersedia.

### 6.2 Verification checklist

- [ ] Paritas kunci 5 ARB = 100%, placeholder identik.
- [ ] Baybayin pilot tetap 11 kunci.
- [ ] `flutter gen-l10n` → `build_runner` → `flutter analyze --no-fatal-infos` → `flutter test` hijau di CI.
- [ ] `cargo test --lib` tetap hijau bila CI menjalankannya (tidak ada perubahan Rust).
- [ ] APK artifact `auno-player-full-release` tersedia; URL dilaporkan.
- [ ] Pernyataan eksplisit: tampilan di perangkat belum diverifikasi asisten.

### 6.3 Anti-pattern guards

- Jangan menambah kunci ke file pilot Baybayin.
- Jangan mengunduh APK/artifact ke laptop.
- Jangan menekan tombol install/launch perangkat.

---

## Final Verification (seluruh plan)

- [ ] Semua fase memiliki commit sendiri dan CI hijau masing-masing.
- [ ] Tidak ada dependency baru di `pubspec.yaml`/`Cargo.toml`.
- [ ] Tidak ada perubahan jalur audio, `minSdk`, izin, atau schema Isar.
- [ ] Tag Hero konsisten: `song_art_<id>` di wheel, player, dan `NavigationHelper`.
- [ ] Tidak ada string UI hard-coded baru; tidak ada nilai audio/MD5 palsu; tidak ada timing lirik estimasi.
- [ ] `git status` tidak memasukkan `key.properties`, keystore, `graphify-out/`, atau `auno-project-raw.zip`.
- [ ] Hasil akhir dilaporkan sebagai: verifikasi otomatis CI selesai, verifikasi hardware/tampilan menunggu pengguna.
