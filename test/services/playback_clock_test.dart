import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/services/playback_clock.dart';

void main() {
  group('PlaybackClock.interpolatePositionMs', () {
    test('returns the anchor while paused', () {
      expect(
        PlaybackClock.interpolatePositionMs(
          anchorPositionMs: 4200,
          elapsedMicros: 900000,
          playbackRate: 1,
          playing: false,
        ),
        4200,
      );
    });

    test('advances one millisecond per millisecond at 1x', () {
      expect(
        PlaybackClock.interpolatePositionMs(
          anchorPositionMs: 1000,
          elapsedMicros: 16000,
          playbackRate: 1,
          playing: true,
        ),
        1016,
      );
    });

    test('respects playback rate', () {
      expect(
        PlaybackClock.interpolatePositionMs(
          anchorPositionMs: 0,
          elapsedMicros: 500000,
          playbackRate: 1.5,
          playing: true,
        ),
        750,
      );
    });

    test('clamps non-positive rates to the anchor', () {
      expect(
        PlaybackClock.interpolatePositionMs(
          anchorPositionMs: 800,
          elapsedMicros: 500000,
          playbackRate: 0,
          playing: true,
        ),
        800,
      );
    });
  });
}
