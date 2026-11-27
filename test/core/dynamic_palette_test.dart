import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/core/theme/dynamic_palette.dart';

Uint8List _solid(int width, int height, int r, int g, int b) {
  final data = Uint8List(width * height * 4);
  for (var i = 0; i < data.length; i += 4) {
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = 255;
  }
  return data;
}

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('extractPaletteSeed', () {
    test('returns neutral for an empty buffer', () {
      final seed = extractPaletteSeed(Uint8List(0));
      expect(seed.dominant, PaletteSeed.neutral.dominant);
    });

    test('finds the dominant hue of a solid image', () {
      final seed = extractPaletteSeed(_solid(8, 8, 220, 30, 40));
      final dominant = Color(seed.dominant);
      expect((dominant.r * 255).round(), greaterThan(180));
      expect((dominant.g * 255).round(), lessThan(80));
      expect((dominant.b * 255).round(), lessThan(90));
    });

    test('keeps a saturated vibrant color and a dark muted color', () {
      final data = Uint8List(16 * 16 * 4);
      for (var i = 0; i < data.length; i += 4) {
        final dark = (i ~/ 4) < (16 * 16 ~/ 2);
        data[i] = dark ? 12 : 240;
        data[i + 1] = dark ? 14 : 40;
        data[i + 2] = dark ? 20 : 180;
        data[i + 3] = 255;
      }
      final seed = extractPaletteSeed(data);
      expect(Color(seed.darkMuted).computeLuminance(), lessThan(0.2));
      expect((Color(seed.vibrant).b * 255).round(), greaterThan(120));
    });

    test('skips fully transparent pixels', () {
      final data = Uint8List(4 * 4 * 4);
      data.fillRange(0, data.length, 0);
      expect(
        extractPaletteSeed(data).dominant,
        PaletteSeed.neutral.dominant,
      );
    });
  });

  group('DynamicThemePalette', () {
    test('accent clears 3:1 against the tinted surface', () {
      final palette = DynamicThemePalette.fromSeeds(
        dominant: const Color(0xFF202020),
        vibrant: const Color(0xFF202830),
        muted: const Color(0xFF303030),
        darkMuted: const Color(0xFF101010),
      );
      expect(_contrast(palette.accent, palette.surface), greaterThanOrEqualTo(3.0));
    });

    test('lerp reaches the target at t=1', () {
      final a = DynamicThemePalette.neutral;
      final b = DynamicThemePalette.fromSeeds(
        dominant: const Color(0xFFAA2030),
        vibrant: const Color(0xFFEE3050),
        muted: const Color(0xFF602030),
        darkMuted: const Color(0xFF200810),
      );
      final mid = DynamicThemePalette.lerp(a, b, 0.5);
      final end = DynamicThemePalette.lerp(a, b, 1);
      expect(mid.dominant, isNot(a.dominant));
      expect(end.dominant, b.dominant);
    });
  });
}
