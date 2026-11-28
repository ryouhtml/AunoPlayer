# Spesifikasi Desain: Redesain Library & Full Player (2026-11-28)

## 1. Ringkasan

Dokumen ini adalah spesifikasi desain untuk menyelaraskan tampilan library dan full player dengan dua referensi HTML yang diberikan pengguna:

1. `ai_studio_code.html` — roda silinder 3D berisi kartu lagu horizontal, dengan skala/opacity berbasis jarak dari kartu aktif, border aktif, glow, EQ, dan marquee.
2. `ai_studio_code (1).html` — player audiophile dengan artwork full-bleed, badge format, kontrol transport, lirik strip, panel antrean, swipe antar layar, dan audio inspector.

Baseline yang menjadi titik awal adalah commit `21244d9` pada branch `feature/auno-fase1`. Perubahan ini **UI-only**: tidak mengubah jalur audio, engine Rust, atau schema data.

Keputusan pengguna yang menjadi input desain:

| Topik | Keputusan |
|---|---|
| Library | Roda 3D mengganti tampilan library utama; daftar/grid lama tetap bisa dipilih lewat pengalih mode. |
| Player | Semua elemen referensi diadopsi: artwork + badge, kontrol, lirik strip, queue reorder, inspector, swipe navigasi. |
| Animasi klik | Thumbnail kartu zoom/bertransisi ke artwork full player saat lagu diputar. |
| Jalur implementasi | **Jalur A**: wheel baru + memperluas widget player yang sudah ada, bukan rewrite menyeluruh. |
| Cara kerja | Asisten yang mengerjakan; pengguna tidak mengunduh apa pun ke laptop. Verifikasi lewat GitHub Actions. |

## 2. Invarian (Tidak Boleh Dilanggar)

- Android-only, `minSdk 26`; tidak ada jalur desktop/iOS.
- Bit-perfect / native format output tetap menjadi tujuan; tidak ada resampling atau truncating diam-diam.
- Tanpa iklan, pelacakan, atau premium tier.
- **Tidak ada dependency baru.** Gunakan Flutter SDK bawaan dan dependency yang sudah ada.
- Semua teks UI baru wajib masuk ke ARB dan diakses lewat `l10n`; tidak ada string hard-coded baru.
- `app_tl_Tglg.arb` adalah pilot Baybayin 11 kunci dan **tidak** diberi kunci baru.
- Tidak ada nilai audio palsu: badge format hanya dari metadata lagu yang nyata; inspector hanya memakai hasil analisis yang sudah ada.
- Tidak ada auto-estimasi timing lirik.
- Asisten tidak memasang, meluncurkan, atau menguji di perangkat; verifikasi hardware tetap menjadi domain pengguna.
- Asisten tidak mengunduh artifact APK ke laptop; cukup laporkan URL artifact GitHub Actions.
- Ikuti gaya file yang disentuh; tidak ada reformatting tak terkait dalam diff yang sama.

## 3. Arsitektur Umum

```
SongsScreen (default = wheel)
   ├── WheelSongList (baru, berbasis OrbitScrollController)
   │      ├── SongCardItem (thumbnail + metadata + badge)
   │      └── Tap → playSong → Navigator.push('/full_player')
   │                         └── Hero(song_art_<id>) → AlbumArtBox fullBleed
   └── mode lama: list / album grid (tetap)

FullPlayerScreen
   ├── PlayerScreenMode.immersive (default, direstyle)
   │      ├── AlbumArtBox(fullBleed: true, showFrame: false)
   │      ├── Metadata row + format badge
   │      ├── PlayerControls + progress bar
   │      ├── SyncedLyricsView strip → mode lirik penuh
   │      └── swipe chrome → panel Queue
   ├── Queue panel (memakai badan QueueScreen, SliverReorderableList)
   └── Inspector → AudioAnalysisSheet + SongMetadataSheet
```

Tidak ada perubahan schema Isar, tidak ada mode player baru, dan tidak ada rute baru. `PlayerScreenMode.artworkCard` beserta preferensinya tetap utuh.

## 4. Library — Roda Silinder 3D

### 4.1 Tampilan

- `SongsScreen` menjadikan roda sebagai default. Pengalih mode di header tetap menyediakan daftar dan grid album.
- Wheel adalah widget baru di `lib/features/songs/widgets/` yang memakai `OrbitScrollController` dan pola cache transform dari `orbit_scroll.dart`.
- Kartu horizontal setinggi ~76 dp, radius ~16, lebar mengikuti `cardWidthRatio` yang sudah ada.
- Untuk jarak `d` dari indeks aktif:
  - skala: `1.04` di `d=0`, `0.96` di `d=1`, turun ke `0.84` dan minimum `0.72`;
  - opacity: `1.0`, `0.85`, `0.55`, `0.25` mengikuti kurva referensi;
  - transform: `rotateX` + `translateZ` untuk efek silinder, bukan rotasi penuh 360°.
- Hanya ±3 kartu di sekitar indeks aktif yang dirender; mask/gradient dipakai untuk menyamarkan tepi.
- Latar gradient cokelat gelap–hitam diambil dari referensi, tetapi warna tetap diturunkan dari `AppColors`/dynamic palette agar mengikuti tema aplikasi.
- Kartu aktif: border terang, glow hangat, dan 3 bar EQ beranimasi. Judul panjang memakai marquee.
- Badge kanan kartu memakai metadata asli: durasi dan format ringkas (`FLAC`, `DSD64`, `PCM`). Badge disembunyikan bila tidak ada data.

### 4.2 Interaksi

- Drag/fling vertikal memakai `OrbitScrollController` yang sudah ada; fling berhenti di indeks terdekat.
- Swipe kanan = favorite, swipe kiri = antre, tombol “…” = action sheet. Semua perilaku lama dipertahankan.
- Multi-select dan fast-index A–Z tetap bekerja; tap dalam mode pilih hanya toggle seleksi.
- Tap kartu pada mode normal: beri feedback skala turun singkat (~0.96), mulai playback, lalu buka full player dengan transisi zoom (bagian 6).

### 4.3 Aksesibilitas

- Setiap kartu punya label `Semantics` dari kunci `l10n`.
- Reduce-motion mematikan rotasi 3D dan animasi EQ; skala/opacity halus tetap dipakai.
- Target sentuh minimal mengikuti standar Material yang sudah dipakai aplikasi.

## 5. Full Player

### 5.1 Artwork & Metadata

- `PlayerScreenMode.immersive` menjadi tampilan utama. Tidak ada enum mode baru.
- `AlbumArtBox` mendapat opsi `fullBleed`/`showFrame: false`: gambar dirender selebar layar (~56% tinggi) dengan fade bawah ke warna permukaan.
- Gesture putar/double-tap/rotation-seek yang sudah ada di `AlbumArtBox` tetap hidup; widget artwork tidak diganti dengan `Image` baru.
- Baris metadata ringkas: judul (marquee), artist, lalu badge kanan. Badge bersumber dari `song.fileType`, `song.bitDepth`, `song.sampleRate`, dan `song.isDsd`/`dsdRateLabel`. Tidak ada estimasi.
- `PlayerScreenMode.artworkCard` dan seluruh preferensinya tidak diubah.

### 5.2 Kontrol, Lirik, Queue, Inspector

- `PlayerControls` dipertahankan apa adanya (transport + progress); favorite dan aksi lain tetap berada di `PlayerActionButtonRow`/action sheet yang sudah ada. Style progress bar tetap mengikuti preferensi waveform/line pengguna.
- Lirik strip menampilkan satu baris aktif dari data `LyricsData` yang sama dengan `SyncedLyricsView`; bila perlu ditambahkan mode strip pada penampil lirik, bukan widget lirik terpisah. Tap masuk/keluar mode lirik penuh. Waktu berasal dari lirik asli, tanpa auto-estimasi.
- Panel queue memakai badan `QueueScreen` yang sudah mendukung `SliverReorderableList`; badan tersebut diekstrak dari `Scaffold`-nya agar bisa dipakai sebagai panel. Rute queue lama tetap dipakai oleh snackbar “Lihat antrean”.
- Audio inspector membuka `AudioAnalysisSheet` dan `SongMetadataSheet` yang sudah ada. Ini mencakup codec, kedalaman bit, laju sampel, analisis, dan null test L−R asli dari `sideMidDb`.
- Tidak meniru MD5/copy/share dari HTML referensi karena aplikasi tidak memiliki sumber nilai MD5 audio yang nyata.

### 5.3 Swipe Navigasi

- Swipe pada chrome header/metadata berpindah antara Now Playing dan panel Queue.
- Area artwork tetap memakai `SongStageCarousel` untuk lagu prev/next, sehingga gesture tidak saling menimpa.
- Gesture dihormati hanya bila tidak ada drag aktif pada carousel; urutan prioritas ditentukan oleh widget induk.

## 6. Animasi Zoom Thumbnail

- Tag `Hero` memakai `song_art_<song.id>`—sama dengan tag yang sudah dikirim `NavigationHelper.navigateToFullPlayer`—di thumbnail wheel dan di artwork full player untuk lagu yang sedang diputar.
- Durasi ~320 ms dengan kurva `easeOutCubic`, mengikuti konstanta animasi aplikasi (`AppConstants`).
- Playback dimulai sebelum `Navigator.push('/full_player')` agar tujuan Hero sudah menampilkan lagu yang benar saat animasi selesai.
- Bila lagu tanpa cover, placeholder yang sama dipakai di kedua sisi dengan tag Hero yang sama.
- Mode multi-select tidak memicu playback/zoom.
- Reduce-motion: Hero dimatikan, diganti fade singkat.
- Fallback bila transisi Hero bentrok dengan `SongStageCarousel`: animasi `Overlay` manual dengan kurva dan durasi yang sama, bukan penghapusan efek.

## 7. l10n, Test, dan Verifikasi

### 7.1 l10n

- Kunci baru ditambahkan ke `app_en.arb`, `app_id.arb`, `app_es.arb`, `app_tl.arb`, dan `app_zh.arb` dengan placeholder paritas.
- `app_tl_Tglg.arb` tidak diubah.
- Semua string baru diakses melalui `l10n`; diakses dari `BuildContext` bila generator lokal yang dipakai file tersebut mengharuskannya.
- Guard lokal yang dijalankan sebelum push (berada di `C:\Users\Administrator\AppData\Local\Temp\opencode\`, bukan di repo): `scan_hardcoded.py`, `check_arb.py`, `check_getters.py`, `check_new_keys_referenced.py`.
- Guard dalam repo yang dijalankan CI lewat `flutter test`: `test/l10n/arb_invariants_test.dart`, `source_guard_test.dart`, `hardcoded_english_test.dart`, `spanish_arb_test.dart`, dan `baybayin_pilot_test.dart`.

### 7.2 Test

- `test/features/songs/`: pemetaan `d` → skala/opacity/rotasi, fling ke index terdekat, tap memutar dan membuka player, mode pilih tidak memutar, reduce-motion tanpa Hero/EQ.
- `test/features/player/`: badge hanya untuk metadata nyata, strip lirik menukar mode, panel queue reorder, inspector memakai data analisis asli, swipe chrome berpindah halaman, tag Hero ada di kedua sisi.
- Gunakan data lagu palsu deterministik; tidak bergantung pada storage perangkat atau jaringan.

### 7.3 Gate

1. Guard l10n lokal lolos.
2. Push ke `feature/auno-fase1`. Kedua workflow hanya berjalan pada `main` atau `workflow_dispatch`, jadi jalankan keduanya lewat `workflow_dispatch` dengan ref branch tersebut menggunakan token git yang sudah tersimpan—bukan dengan push ke `main`. Pantau `gen-l10n` → `build_runner` → `flutter analyze` → `flutter test`.
3. Setelah CI hijau, dispatch build APK lewat GitHub Actions dan laporkan URL artifact. Tidak ada download ke laptop.
4. Jalankan `graphify update .` setelah kode berubah bila tool tersedia.
5. Nyatakan secara eksplisit bahwa tampilan akhir di perangkat belum diverifikasi oleh asisten.

## 8. Referensi

- `C:\Users\Administrator\Downloads\ai_studio_code.html`
- `C:\Users\Administrator\Downloads\ai_studio_code (1).html`
- `lib/features/songs/screens/songs_screen.dart`
- `lib/features/songs/widgets/orbit_scroll.dart`
- `lib/features/songs/widgets/song_card.dart`
- `lib/features/player/screens/full_player_screen.dart`
- `lib/features/player/widgets/song_stage_carousel.dart`
- `lib/features/player/widgets/album_art_box.dart`
- `lib/features/player/widgets/synced_lyrics_view.dart`
- `lib/features/player/widgets/audio_analysis_sheet.dart`
- `lib/features/queue/screens/queue_screen.dart`
- `lib/models/player_screen_mode.dart`
