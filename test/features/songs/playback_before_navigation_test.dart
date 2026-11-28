// Source-level guard for the library tap order.
//
// The artwork Hero can only land on the right song if playback has already
// updated the full player before its route is pushed. Reverse these two calls
// and the destination builds with the previous song's artwork, so the zoom
// flies into the wrong image. A source guard keeps that invariant cheap to
// check without pumping the whole Songs screen and its providers.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _songsScreenPath =
    'lib/features/songs/screens/songs_screen.dart';

/// Returns the `_playSongAndOpenPlayer` declaration through the next method.
String _playAndOpenBody(String source) {
  const marker = 'Future<void> _playSongAndOpenPlayer(';
  final start = source.indexOf(marker);
  if (start < 0) {
    throw StateError('$marker not found in $_songsScreenPath');
  }
  final nextMethod = source.indexOf('\n  Future<', start + marker.length);
  final end = nextMethod < 0 ? source.length : nextMethod;
  return source.substring(start, end);
}

void main() {
  final source = File(_songsScreenPath).readAsStringSync();
  final body = _playAndOpenBody(source);

  test('playback starts before full-player navigation', () {
    final play = body.indexOf('.play(');
    final navigate = body.indexOf('NavigationHelper.navigateToFullPlayer(');

    expect(play, greaterThanOrEqualTo(0), reason: 'play(...) call is missing');
    expect(
      navigate,
      greaterThanOrEqualTo(0),
      reason: 'navigateToFullPlayer(...) call is missing',
    );
    expect(
      play,
      lessThan(navigate),
      reason: 'playback must start before the full-player route is pushed',
    );
  });

  test('navigation passes the canonical song_art_ Hero tag', () {
    expect(
      body,
      contains(r"heroTag: 'song_art_${songToPlay.id}'"),
      reason: 'wheel and player must share song_art_<id> (not song-art-<id>)',
    );
  });
}
