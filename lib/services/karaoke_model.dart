// Karaoke timing model for Auno Player.
//
// Attribution: the span model and reveal rules follow the GPL-3.0 karaoke
// implementation pattern used by BitChord. See NOTICE for attribution.

/// Where the timing information in a [KaraokeLine] came from.
///
/// Only sources that actually carry timestamps may use word or syllable
/// spans. Plain synced lyrics are explicitly [lineOnly]; no timing is guessed.
enum TimingSource {
  embeddedEnhancedLrc,
  sidecarEnhancedLrc,
  onlineProvider,
  manual,
  lineOnly,
}

/// A single revealed span in a lyric line: a syllable when syllable timing
/// exists, otherwise a word, otherwise the whole line as a reveal fallback.
class KaraokeSpan {
  const KaraokeSpan({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.startChar,
    required this.endChar,
  });

  final String text;
  final int startMs;
  final int endMs;
  final int startChar;
  final int endChar;

  int get length => endChar - startChar;
}

/// A syllable with its own real timestamp inside a word.
class KaraokeSyllable {
  const KaraokeSyllable({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.startChar,
    required this.endChar,
  });

  final String text;
  final int startMs;
  final int endMs;
  final int startChar;
  final int endChar;
}

/// A word with a real timing window. [syllables] is empty unless the source
/// carried syllable-level timestamps.
class KaraokeWord {
  const KaraokeWord({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.startChar,
    required this.endChar,
    this.syllables = const [],
  });

  final String text;
  final int startMs;
  final int endMs;
  final int startChar;
  final int endChar;
  final List<KaraokeSyllable> syllables;
}

/// A normalized karaoke line.
///
/// [startChar]/[endChar] delimit this line inside the full lyric text.
/// [sungUntilMs] is the last position applied to the line by the controller.
/// [background] marks a currently inactive line and [alignment] is the
/// renderer alignment hint.
class KaraokeLine {
  const KaraokeLine({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.startChar,
    required this.endChar,
    required this.source,
    this.words = const [],
    this.sungUntilMs = 0,
    this.background = false,
    this.alignment = KaraokeAlignment.center,
  });

  final String text;
  final int startMs;
  final int endMs;
  final int startChar;
  final int endChar;
  final TimingSource source;
  final List<KaraokeWord> words;
  final int sungUntilMs;
  final bool background;
  final KaraokeAlignment alignment;

  /// True when the line has no real word/syllable timestamps. The renderer
  /// reveals the whole line inside its own window instead of guessing words.
  bool get isLineOnly => source == TimingSource.lineOnly || words.isEmpty;
}

enum KaraokeAlignment { left, center, right }
