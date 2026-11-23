// BitChord-style karaoke span helpers for Auno Player.
//
// Attribution: the span/reveal algorithm is adapted from the GPL-3.0 BitChord
// karaoke implementation. See NOTICE for attribution.
//
// Important invariant: no timing is ever inferred. A line only gets word or
// syllable spans when the source actually supplied timestamps; otherwise it
// gets one whole-line span and reveals as a line.

import 'package:auno_player/services/karaoke_model.dart';
import 'package:auno_player/services/lyrics_service.dart';
import 'package:auno_player/services/online_lyrics_service.dart';

export 'package:auno_player/services/karaoke_model.dart';

/// One span together with its current sweep progress.
class SweptSpan {
  const SweptSpan({
    required this.span,
    required this.fill,
    required this.revealedChars,
  });

  final KaraokeSpan span;
  final double fill;
  final int revealedChars;
}

/// Builds [KaraokeLine] objects from existing LRC parsers and from LRCLib
/// results without changing those APIs.
class KaraokeNormalizer {
  KaraokeNormalizer({LyricsService? lyricsService})
    : _lyricsService = lyricsService ?? LyricsService();

  final LyricsService _lyricsService;
  static final RegExp _lineTimestamp = RegExp(
    r'^\[(\d{1,2}:\d{2}(?::\d{2})?(?:\.\d{1,3})?)\]',
  );
  static final RegExp _wordTimestamp = RegExp(
    r'<(\d{1,2}:\d{2}(?::\d{2})?(?:\.\d{1,3})?)>',
  );
  static final RegExp _metadataTag = RegExp(r'^\[[a-zA-Z][^\]]*:\s*.*\]\s*$');
  static const int _fallbackLineWindowMs = 5000;

  TimingSource _sourceFor(String? source, bool hasWordTimings) {
    if (!hasWordTimings) return TimingSource.lineOnly;
    final value = source?.toLowerCase() ?? '';
    if (value.contains('embedded')) return TimingSource.embeddedEnhancedLrc;
    if (value.contains('lrclib') || value.contains('online')) {
      return TimingSource.onlineProvider;
    }
    if (value.contains('manual')) return TimingSource.manual;
    return TimingSource.sidecarEnhancedLrc;
  }

  /// Normalizes already-parsed [LyricsData]. This path preserves the existing
  /// enhanced-LRC parser: word timestamps are real, syllable details require
  /// [fromRawLrc], which reads the original tag positions.
  List<KaraokeLine> fromLyricsData(
    LyricsData data, {
    TimingSource? source,
  }) {
    final result = <KaraokeLine>[];
    var charOffset = 0;
    for (var i = 0; i < data.lines.length; i++) {
      final line = data.lines[i];
      final endMs = _nextLineStart(data.lines, i, line.timestamp);
      final resolvedSource =
          source ?? _sourceFor(data.source, line.words?.isNotEmpty ?? false);
      final words = _wordsFromParsedLine(line, endMs, resolvedSource);
      result.add(
        KaraokeLine(
          text: line.text,
          startMs: line.timestamp.inMilliseconds,
          endMs: endMs,
          startChar: charOffset,
          endChar: charOffset + line.text.length,
          source: words.isEmpty ? TimingSource.lineOnly : resolvedSource,
          words: words,
        ),
      );
      charOffset += line.text.length + 1; // implicit newline
    }
    return result;
  }

  List<KaraokeWord> _wordsFromParsedLine(
    LyricsLine line,
    int lineEndMs,
    TimingSource source,
  ) {
    if (source == TimingSource.lineOnly) return const [];
    final parsed = line.words;
    if (parsed == null || parsed.isEmpty) return const [];

    var charOffset = 0;
    final words = <KaraokeWord>[];
    for (var i = 0; i < parsed.length; i++) {
      final word = parsed[i];
      final startMs = word.start.inMilliseconds;
      final nextMs = i + 1 < parsed.length
          ? parsed[i + 1].start.inMilliseconds
          : lineEndMs;
      final endMs = nextMs > startMs ? nextMs : -1;
      if (endMs <= startMs) return const [];
      final text = word.text;
      words.add(
        KaraokeWord(
          text: text,
          startMs: startMs,
          endMs: endMs,
          startChar: charOffset,
          endChar: charOffset + text.length,
        ),
      );
      charOffset += text.length;
    }
    return words;
  }

  /// Normalizes LRCLib synced lyrics directly, preserving syllable tags when
  /// the provider carries them.
  List<KaraokeLine> fromOnline(OnlineLyricsResult result) {
    final synced = result.syncedLyrics;
    if (synced == null || synced.trim().isEmpty) return const [];
    return fromRawLrc(synced, source: TimingSource.onlineProvider);
  }

  /// Parses raw LRC text. Enhanced tags that are adjacent (no whitespace
  /// between them) are treated as syllables of one word.
  List<KaraokeLine> fromRawLrc(String raw, {required TimingSource source}) {
    final rows = <_RawLine>[];
    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      if (rawLine.trim().isEmpty || _metadataTag.hasMatch(rawLine.trim())) {
        continue;
      }
      final match = _lineTimestamp.firstMatch(rawLine);
      if (match == null) continue;
      final timestamp = _lyricsService.parseTimestamp(match.group(1)!);
      if (timestamp == null) continue;
      final body = rawLine.substring(match.end);
      rows.add(_RawLine(startMs: timestamp.inMilliseconds, body: body));
    }

    final result = <KaraokeLine>[];
    var charOffset = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final endMs = i + 1 < rows.length
          ? rows[i + 1].startMs
          : row.startMs + _fallbackLineWindowMs;
      final parsed = _parseEnhancedBody(row.body, row.startMs, endMs);
      final text = parsed.$1;
      final words = parsed.$2;
      final resolvedSource =
          words.isEmpty ? TimingSource.lineOnly : source;
      result.add(
        KaraokeLine(
          text: text,
          startMs: row.startMs,
          endMs: endMs,
          startChar: charOffset,
          endChar: charOffset + text.length,
          source: resolvedSource,
          words: words,
        ),
      );
      charOffset += text.length + 1;
    }
    return result;
  }

  ({String text, List<KaraokeWord> words}) _parseEnhancedBody(
    String body,
    int lineStartMs,
    int lineEndMs,
  ) {
    final matches = _wordTimestamp.allMatches(body).toList();
    if (matches.isEmpty) {
      final text = body.trim();
      return (text: text, words: const []);
    }

    final buffer = StringBuffer();
    final rawWords = <_RawWord>[];
    _RawWord? current;

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final parsed = _lyricsService.parseTimestamp(match.group(1)!);
      if (parsed == null) continue;
      final segmentEnd = i + 1 < matches.length
          ? matches[i + 1].start
          : body.length;
      final segment = body.substring(match.end, segmentEnd);
      final previousChar = match.start > 0 ? body[match.start - 1] : '';
      final newWord = current == null ||
          previousChar.isEmpty ||
          previousChar == '\n' ||
          RegExp(r'\s').hasMatch(previousChar);

      if (newWord) {
        current = _RawWord(
          startMs: parsed.inMilliseconds,
          textStart: buffer.length,
          segments: <_RawSyllable>[],
        );
        rawWords.add(current!);
      }
      final textStart = buffer.length;
      buffer.write(segment);
      current!.segments.add(
        _RawSyllable(
          startMs: parsed.inMilliseconds,
          textStart: textStart,
          textEnd: buffer.length,
          endsWithSpace: segment.trimRight().length != segment.length,
        ),
      );
    }

    if (rawWords.isEmpty) return (text: buffer.toString(), words: const []);

    // Close every word using the next real timestamp. The last word ends at
    // the next line's real timestamp; no per-word duration is invented.
    final flat = <_RawSyllable>[
      for (final word in rawWords) ...word.segments,
    ];
    return (
      text: buffer.toString(),
      words: _buildWords(flat, buffer.toString(), lineStartMs, lineEndMs),
    );
  }

  List<KaraokeWord> _buildWords(
    List<_RawSyllable> syllables,
    String text,
    int lineStartMs,
    int lineEndMs,
  ) {
    final words = <KaraokeWord>[];
    var i = 0;
    while (i < syllables.length) {
      final wordStart = syllables[i].startMs;
      var j = i + 1;
      while (j < syllables.length && !syllables[j - 1].endsWithSpace) {
        j++;
      }
      final wordEnd = j < syllables.length
          ? syllables[j].startMs
          : lineEndMs > wordStart
              ? lineEndMs
              : -1;
      if (wordEnd <= wordStart) return const [];

      final syllableObjects = <KaraokeSyllable>[];
      for (var k = i; k < j; k++) {
        final syllable = syllables[k];
        final nextMs = k + 1 < j ? syllables[k + 1].startMs : wordEnd;
        if (nextMs <= syllable.startMs) return const [];
        syllableObjects.add(
          KaraokeSyllable(
            text: text.substring(syllable.textStart, syllable.textEnd),
            startMs: syllable.startMs,
            endMs: nextMs,
            startChar: syllable.textStart,
            endChar: syllable.textEnd,
          ),
        );
      }

      final startChar = syllableObjects.first.startChar;
      final endChar = syllableObjects.last.endChar;
      words.add(
        KaraokeWord(
          text: text.substring(startChar, endChar),
          startMs: wordStart,
          endMs: wordEnd,
          startChar: startChar,
          endChar: endChar,
          syllables: syllableObjects,
        ),
      );
      i = j;
    }
    return words;
  }

  int _nextLineStart(List<LyricsLine> lines, int index, Duration fallback) {
    if (index + 1 < lines.length) {
      final next = lines[index + 1].timestamp.inMilliseconds;
      if (next > fallback.inMilliseconds) return next;
    }
    return fallback.inMilliseconds + _fallbackLineWindowMs;
  }
}

class _RawLine {
  const _RawLine({required this.startMs, required this.body});

  final int startMs;
  final String body;
}

class _RawSyllable {
  const _RawSyllable({
    required this.startMs,
    required this.textStart,
    required this.textEnd,
    required this.endsWithSpace,
  });

  final int startMs;
  final int textStart;
  final int textEnd;
  final bool endsWithSpace;
}

class _RawWord {
  _RawWord({
    required this.startMs,
    required this.textStart,
    required List<_RawSyllable> segments,
  }) : segments = segments;

  final int startMs;
  final int textStart;
  final List<_RawSyllable> segments;
}

/// Sweep granularity selected in lyrics settings. [auto] uses the finest
/// timing that actually exists in the source; the explicit modes never infer
/// missing timestamps.
enum KaraokeSweepStyle { auto, word, syllable }

KaraokeSweepStyle karaokeSweepStyleFromString(String? value) {
  switch (value) {
    case 'word':
      return KaraokeSweepStyle.word;
    case 'syllable':
      return KaraokeSweepStyle.syllable;
    default:
      return KaraokeSweepStyle.auto;
  }
}

/// Returns the renderable spans for [line], preferring syllables when the
/// source supplied them, then words, then one whole-line reveal span.
List<KaraokeSpan> wordSpans(
  KaraokeLine line, [
  KaraokeSweepStyle style = KaraokeSweepStyle.auto,
]) {
  if (style == KaraokeSweepStyle.syllable && line.words.isEmpty) {
    return [
      KaraokeSpan(
        text: line.text,
        startMs: line.startMs,
        endMs: line.endMs,
        startChar: 0,
        endChar: line.text.length,
      ),
    ];
  }
  if (line.words.isEmpty || style == KaraokeSweepStyle.word) {
    return [
      KaraokeSpan(
        text: line.text,
        startMs: line.startMs,
        endMs: line.endMs,
        startChar: 0,
        endChar: line.text.length,
      ),
    ];
  }

  final hasSyllables = line.words.any((word) => word.syllables.isNotEmpty);
  if (!hasSyllables) {
    return [
      for (final word in line.words)
        KaraokeSpan(
          text: word.text,
          startMs: word.startMs,
          endMs: word.endMs,
          startChar: word.startChar,
          endChar: word.endChar,
        ),
    ];
  }
  return [
    for (final word in line.words)
      for (final syllable in word.syllables.isEmpty
          ? [
              KaraokeSyllable(
                text: word.text,
                startMs: word.startMs,
                endMs: word.endMs,
                startChar: word.startChar,
                endChar: word.endChar,
              ),
            ]
          : word.syllables)
        KaraokeSpan(
          text: syllable.text,
          startMs: syllable.startMs,
          endMs: syllable.endMs,
          startChar: syllable.startChar,
          endChar: syllable.endChar,
        ),
  ];
}

double _fillFor(KaraokeSpan span, int positionMs) {
  final window = span.endMs - span.startMs;
  if (window <= 0) return positionMs >= span.endMs ? 1.0 : 0.0;
  return ((positionMs - span.startMs) / window).clamp(0.0, 1.0);
}

/// Spans paired with their sweep fill at [positionMs].
List<SweptSpan> sweepSpans(
  KaraokeLine line,
  int positionMs, [
  KaraokeSweepStyle style = KaraokeSweepStyle.auto,
]) {
  return [
    for (final span in wordSpans(line, style))
      SweptSpan(
        span: span,
        fill: _fillFor(span, positionMs),
        revealedChars: span.startChar +
            ((span.endChar - span.startChar) * _fillFor(span, positionMs)).floor(),
      ),
  ];
}

/// Characters revealed at [positionMs], including a partially swept span.
int revealedChars(
  KaraokeLine line,
  int positionMs, [
  KaraokeSweepStyle style = KaraokeSweepStyle.auto,
]) {
  var revealed = 0;
  for (final span in wordSpans(line, style)) {
    final fill = _fillFor(span, positionMs);
    if (fill <= 0) continue;
    final chars = span.startChar +
        ((span.endChar - span.startChar) * fill).floor();
    if (chars > revealed) revealed = chars;
  }
  return revealed.clamp(0, line.text.length);
}

/// Characters whose spans have fully finished by [positionMs].
int charsSungAt(
  KaraokeLine line,
  int positionMs, [
  KaraokeSweepStyle style = KaraokeSweepStyle.auto,
]) {
  var sung = 0;
  for (final span in wordSpans(line, style)) {
    if (span.endMs <= positionMs && span.endChar > sung) sung = span.endChar;
  }
  return sung.clamp(0, line.text.length);
}
