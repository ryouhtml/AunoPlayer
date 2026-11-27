import 'package:flutter/foundation.dart';

/// How precisely a lyric document is timed.
enum LyricSyncLevel {
  /// Real per-word (or per-syllable) timestamps.
  word,

  /// Line timestamps only.
  line,

  /// No timestamps at all.
  plain,
}

/// Where a document came from.
enum LyricSourceKind { embedded, sidecar, manual, online, cached }

/// A syllable with its own real timestamp inside a word.
@immutable
class LyricSyllable {
  const LyricSyllable({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final Duration start;
  final Duration end;
}

/// A word with a real timing window. [syllables] is empty unless the source
/// carried syllable-level timestamps (TTML nested spans).
@immutable
class LyricWord {
  const LyricWord({
    required this.text,
    required this.start,
    required this.end,
    this.syllables = const [],
  });

  final String text;
  final Duration start;
  final Duration end;
  final List<LyricSyllable> syllables;

  bool get hasSyllables => syllables.isNotEmpty;
}

/// One normalized lyric line.
@immutable
class LyricLine {
  const LyricLine({
    required this.text,
    required this.start,
    required this.end,
    this.words = const [],
    this.translation,
    this.romanization,
  });

  final String text;
  final Duration start;
  final Duration end;
  final List<LyricWord> words;
  final String? translation;
  final String? romanization;

  bool get hasWordTiming => words.isNotEmpty;

  LyricLine copyWith({
    String? text,
    Duration? start,
    Duration? end,
    List<LyricWord>? words,
    String? translation,
    String? romanization,
  }) {
    return LyricLine(
      text: text ?? this.text,
      start: start ?? this.start,
      end: end ?? this.end,
      words: words ?? this.words,
      translation: translation ?? this.translation,
      romanization: romanization ?? this.romanization,
    );
  }
}

/// Provider-agnostic lyric payload used by the multi-provider engine.
@immutable
class SyncedLyricDocument {
  const SyncedLyricDocument({
    required this.lines,
    required this.syncLevel,
    required this.raw,
    this.sourceKind = LyricSourceKind.online,
    this.providerId,
    this.language,
    this.title,
    this.artist,
  });

  final List<LyricLine> lines;
  final LyricSyncLevel syncLevel;
  final String raw;
  final LyricSourceKind sourceKind;
  final String? providerId;
  final String? language;
  final String? title;
  final String? artist;

  bool get isSynced => syncLevel != LyricSyncLevel.plain;
  bool get hasWordTiming => syncLevel == LyricSyncLevel.word;
  bool get isEmpty => lines.isEmpty;

  /// Index of the line active at [position], or -1 before the first line.
  int lineIndexAt(Duration position) {
    if (!isSynced || lines.isEmpty) return -1;
    final target = position.inMilliseconds;
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = low + ((high - low) ~/ 2);
      if (lines[mid].start.inMilliseconds <= target) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  SyncedLyricDocument withTranslation(String language) {
    return SyncedLyricDocument(
      lines: lines,
      syncLevel: syncLevel,
      raw: raw,
      sourceKind: sourceKind,
      providerId: providerId,
      language: language,
      title: title,
      artist: artist,
    );
  }
}
