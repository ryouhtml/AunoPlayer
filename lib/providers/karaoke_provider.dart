import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/karaoke_spans.dart';
import '../services/lyrics_service.dart';

/// Normalizer instance shared by all karaoke consumers.
final karaokeNormalizerProvider = Provider<KaraokeNormalizer>((ref) {
  return KaraokeNormalizer();
});

/// A position snapshot of the karaoke state for one lyric payload.
class KaraokeFrame {
  const KaraokeFrame({
    required this.lines,
    required this.activeIndex,
    required this.positionMs,
    required this.spans,
  });

  final List<KaraokeLine> lines;
  final int activeIndex;
  final int positionMs;
  final List<SweptSpan> spans;

  KaraokeLine? get activeLine =>
      activeIndex >= 0 && activeIndex < lines.length ? lines[activeIndex] : null;
}

/// Maps a playback position to the active line and its swept spans.
///
/// The caller supplies the position from `PlayerService.positionNotifier`
/// (or the throttled notifier used by the full-screen player), so pausing
/// cannot make the sweep jump.
final karaokeControllerProvider = Provider.family<
  KaraokeFrame,
  ({LyricsData lyrics, Duration position})
>((ref, args) {
  final lines = ref.watch(karaokeNormalizerProvider).fromLyricsData(args.lyrics);
  final positionMs = args.position.inMilliseconds;

  var activeIndex = 0;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startMs <= positionMs) {
      activeIndex = i;
    } else {
      break;
    }
  }

  final spans = lines.isEmpty
      ? const <SweptSpan>[]
      : sweepSpans(lines[activeIndex], positionMs);
  return KaraokeFrame(
    lines: lines,
    activeIndex: lines.isEmpty ? -1 : activeIndex,
    positionMs: positionMs,
    spans: spans,
  );
});
