import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:auno_player/core/theme/adaptive_colors.dart';
import 'package:auno_player/core/theme/app_colors.dart';

/// A color story derived from one album cover.
///
/// The palette is intentionally small: four seed colors plus the surfaces and
/// foregrounds the UI actually paints. Everything is pre-resolved so widgets
/// never run contrast math per frame.
@immutable
class DynamicThemePalette {
  const DynamicThemePalette({
    required this.dominant,
    required this.vibrant,
    required this.muted,
    required this.darkMuted,
    required this.accent,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.backgroundTop,
    required this.backgroundBottom,
  });

  final Color dominant;
  final Color vibrant;
  final Color muted;
  final Color darkMuted;

  /// [vibrant] adjusted until it reaches 3:1 against [surface].
  final Color accent;

  /// Base card color: #18181A blended with a trace of [dominant].
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color backgroundTop;
  final Color backgroundBottom;

  static const DynamicThemePalette neutral = DynamicThemePalette(
    dominant: AppColors.surfaceLight,
    vibrant: AppColors.accent,
    muted: AppColors.surfaceLight,
    darkMuted: AppColors.surfaceDark,
    accent: AppColors.accentLight,
    surface: Color(0xFF18181A),
    surfaceHigh: Color(0xFF202024),
    border: AppColors.glassBorder,
    onSurface: AppColors.textPrimary,
    onSurfaceMuted: AppColors.textSecondary,
    backgroundTop: AppColors.background,
    backgroundBottom: AppColors.backgroundBlack,
  );

  static DynamicThemePalette lerp(
    DynamicThemePalette a,
    DynamicThemePalette b,
    double t,
  ) {
    Color mix(Color x, Color y) => Color.lerp(x, y, t)!;
    return DynamicThemePalette(
      dominant: mix(a.dominant, b.dominant),
      vibrant: mix(a.vibrant, b.vibrant),
      muted: mix(a.muted, b.muted),
      darkMuted: mix(a.darkMuted, b.darkMuted),
      accent: mix(a.accent, b.accent),
      surface: mix(a.surface, b.surface),
      surfaceHigh: mix(a.surfaceHigh, b.surfaceHigh),
      border: mix(a.border, b.border),
      onSurface: mix(a.onSurface, b.onSurface),
      onSurfaceMuted: mix(a.onSurfaceMuted, b.onSurfaceMuted),
      backgroundTop: mix(a.backgroundTop, b.backgroundTop),
      backgroundBottom: mix(a.backgroundBottom, b.backgroundBottom),
    );
  }

  /// Builds the full palette from four seed colors.
  factory DynamicThemePalette.fromSeeds({
    required Color dominant,
    required Color vibrant,
    required Color muted,
    required Color darkMuted,
  }) {
    const base = Color(0xFF18181A);
    final surface = Color.alphaBlend(
      dominant.withValues(alpha: 0.16),
      base,
    );
    final surfaceHigh = Color.alphaBlend(
      vibrant.withValues(alpha: 0.20),
      base,
    );
    final accent = _legibleAccent(vibrant, surface);
    final onSurface = AdaptiveColors.ensureContrast(
      Colors.white,
      surface,
      minContrast: 4.5,
    );
    final onSurfaceMuted = Color.lerp(
      onSurface,
      surface,
      0.32,
    )!.withValues(alpha: 0.86);
    return DynamicThemePalette(
      dominant: dominant,
      vibrant: vibrant,
      muted: muted,
      darkMuted: darkMuted,
      accent: accent,
      surface: surface,
      surfaceHigh: surfaceHigh,
      border: accent.withValues(alpha: 0.22),
      onSurface: onSurface,
      onSurfaceMuted: onSurfaceMuted,
      backgroundTop: Color.alphaBlend(
        dominant.withValues(alpha: 0.20),
        AppColors.background,
      ),
      backgroundBottom: AppColors.backgroundBlack,
    );
  }

  /// Lightens [seed] until it clears 3:1 against [background].
  static Color _legibleAccent(Color seed, Color background) {
    var candidate = seed;
    for (var step = 0; step < 8; step++) {
      if (_contrast(candidate, background) >= 3.0) return candidate;
      candidate = Color.lerp(candidate, Colors.white, 0.12)!;
    }
    return AdaptiveColors.ensureContrast(
      candidate,
      background,
      minContrast: 3.0,
    );
  }

  static double _contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }
}

/// Plain integer seed colors, safe to send across an isolate boundary.
@immutable
class PaletteSeed {
  const PaletteSeed({
    required this.dominant,
    required this.vibrant,
    required this.muted,
    required this.darkMuted,
  });

  final int dominant;
  final int vibrant;
  final int muted;
  final int darkMuted;

  static const PaletteSeed neutral = PaletteSeed(
    dominant: 0xFF1E1E1E,
    vibrant: 0xFFE0E0E0,
    muted: 0xFF1E1E1E,
    darkMuted: 0xFF0C0C0C,
  );

  DynamicThemePalette toPalette() {
    return DynamicThemePalette.fromSeeds(
      dominant: Color(dominant),
      vibrant: Color(vibrant),
      muted: Color(muted),
      darkMuted: Color(darkMuted),
    );
  }
}

/// Extracts four seed colors from a 32x32 RGBA buffer.
///
/// This is a top-level function so it can run inside [Isolate.run]. It uses a
/// 32x32x32 histogram (5 bits per channel), which is accurate enough for a
/// 1024-pixel sample and far cheaper than per-pixel clustering.
PaletteSeed extractPaletteSeed(Uint8List rgba) {
  const levels = 32;
  const buckets = levels * levels * levels;
  final counts = Int32List(buckets);
  final redSum = Int32List(buckets);
  final greenSum = Int32List(buckets);
  final blueSum = Int32List(buckets);

  var total = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    final r = rgba[i];
    final g = rgba[i + 1];
    final b = rgba[i + 2];
    final key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
    counts[key]++;
    redSum[key] += r;
    greenSum[key] += g;
    blueSum[key] += b;
    total++;
  }
  if (total == 0) return PaletteSeed.neutral;

  var dominantScore = -1.0;
  var vibrantScore = -1.0;
  var mutedScore = -1.0;
  var darkScore = -1.0;
  var dominant = PaletteSeed.neutral.dominant;
  var vibrant = PaletteSeed.neutral.vibrant;
  var muted = PaletteSeed.neutral.muted;
  var darkMuted = PaletteSeed.neutral.darkMuted;

  for (var key = 0; key < buckets; key++) {
    final count = counts[key];
    if (count == 0) continue;
    final r = redSum[key] ~/ count;
    final g = greenSum[key] ~/ count;
    final b = blueSum[key] ~/ count;
    final argb = 0xFF000000 | (r << 16) | (g << 8) | b;

    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
    final luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
    final weight = math.pow(count, 0.72).toDouble();

    final dom = weight * (1.0 + saturation * 0.25);
    if (dom > dominantScore) {
      dominantScore = dom;
      dominant = argb;
    }

    // Vibrant: saturated and reasonably bright, but still frequent.
    final vib = weight * (saturation * saturation * 2.6 + luminance * 0.25);
    if (saturation >= 0.16 && vib > vibrantScore) {
      vibrantScore = vib;
      vibrant = argb;
    }

    // Muted: low-but-nonzero saturation, close to 30%.
    final mutedFit = 1.0 - (saturation - 0.28).abs();
    final mut = weight * mutedFit;
    if (saturation >= 0.05 && saturation <= 0.55 && mut > mutedScore) {
      mutedScore = mut;
      muted = argb;
    }

    // Dark muted: darkest frequent bucket.
    final dark = weight * (1.0 - luminance);
    if (luminance <= 0.34 && dark > darkScore) {
      darkScore = dark;
      darkMuted = argb;
    }
  }

  if (vibrantScore < 0) vibrant = dominant;
  if (mutedScore < 0) {
    muted = _mixArgb(dominant, 0xFF808080, 0.45);
  }
  if (darkScore < 0) {
    darkMuted = _mixArgb(dominant, 0xFF000000, 0.55);
  }

  return PaletteSeed(
    dominant: dominant,
    vibrant: vibrant,
    muted: muted,
    darkMuted: darkMuted,
  );
}

int _mixArgb(int a, int b, double t) {
  final ar = (a >> 16) & 0xFF;
  final ag = (a >> 8) & 0xFF;
  final ab = a & 0xFF;
  final br = (b >> 16) & 0xFF;
  final bg = (b >> 8) & 0xFF;
  final bb = b & 0xFF;
  final r = (ar + (br - ar) * t).round();
  final g = (ag + (bg - ag) * t).round();
  final bl = (ab + (bb - ab) * t).round();
  return 0xFF000000 | (r << 16) | (g << 8) | bl;
}

/// Extracts and caches palettes for album covers.
///
/// Cache keys are album identity (`artist|album`) with a song-id fallback, so
/// skipping inside one album is instant. Decoding happens on the main isolate
/// (dart:ui requires it) at 32x32; the histogram runs in a background isolate.
class DynamicPaletteService {
  DynamicPaletteService._();

  static final DynamicPaletteService instance = DynamicPaletteService._();

  final Map<String, _PaletteEntry> _cache = {};
  final Map<String, Future<DynamicThemePalette?>> _inflight = {};

  DynamicThemePalette? cached(String key) => _cache[key]?.palette;

  Future<DynamicThemePalette?> paletteFor({
    required String key,
    required String? imagePath,
  }) async {
    if (imagePath == null || imagePath.isEmpty) return null;
    final existing = _cache[key];
    if (existing != null && existing.imagePath == imagePath) {
      return existing.palette;
    }
    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _extract(imagePath).then((palette) {
      if (palette != null) {
        _cache[key] = _PaletteEntry(imagePath: imagePath, palette: palette);
      }
      return palette;
    }).whenComplete(() => _inflight.remove(key));
    _inflight[key] = future;
    return future;
  }

  Future<DynamicThemePalette?> _extract(String imagePath) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      final file = await _resolveFile(imagePath);
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final rgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final seed = await Isolate.run(() => extractPaletteSeed(rgba));
      return seed.toPalette();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<File?> _resolveFile(String path) async {
    final file = File(path);
    if (await file.exists()) return file;
    return null;
  }

  void invalidate(String key) => _cache.remove(key);

  void clear() {
    _cache.clear();
    _inflight.clear();
  }
}

class _PaletteEntry {
  const _PaletteEntry({required this.imagePath, required this.palette});

  final String imagePath;
  final DynamicThemePalette palette;
}
