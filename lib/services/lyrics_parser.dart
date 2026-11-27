import 'package:auno_player/models/synced_lyric_document.dart';

/// Normalizes every lyric payload the app can receive into one document.
///
/// Supported inputs:
/// * TTML (`<p begin="…">` with optional timed `<span>` words/syllables and
///   translation spans)
/// * Enhanced LRC (`[mm:ss.xx]<mm:ss.xx>word…`)
/// * Standard LRC (`[mm:ss.xx]line`, multiple stamps per row)
/// * Plain text
///
/// The parser never invents timing. A line only gets [LyricWord]s when the
/// source carried real word timestamps; otherwise it stays line-synced.
class LyricsParser {
  const LyricsParser();

  static const Duration _lineTail = Duration(seconds: 5);
  static const Duration _minimumLine = Duration(milliseconds: 900);

  SyncedLyricDocument parse(
    String raw, {
    String? providerId,
    LyricSourceKind sourceKind = LyricSourceKind.online,
    String? language,
  }) {
    final text = raw.replaceFirst('\uFEFF', '');
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return SyncedLyricDocument(
        lines: const [],
        syncLevel: LyricSyncLevel.plain,
        raw: raw,
        sourceKind: sourceKind,
        providerId: providerId,
        language: language,
      );
    }

    if (_looksLikeTtml(trimmed)) {
      final ttml = _parseTtml(
        text,
        providerId: providerId,
        sourceKind: sourceKind,
        language: language,
      );
      if (ttml != null && ttml.lines.isNotEmpty) return ttml;
    }

    return _parseLrc(
      text,
      providerId: providerId,
      sourceKind: sourceKind,
      language: language,
    );
  }

  // ---------------------------------------------------------------------------
  // TTML
  // ---------------------------------------------------------------------------

  bool _looksLikeTtml(String trimmed) {
    if (!trimmed.startsWith('<')) return false;
    return RegExp(
      r'<tt[\s>]|<p[\s>]|<body[\s>]',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  SyncedLyricDocument? _parseTtml(
    String raw, {
    String? providerId,
    required LyricSourceKind sourceKind,
    String? language,
  }) {
    final pPattern = RegExp(
      r'<p\b([^>]*)>(.*?)</p\s*>',
      dotAll: true,
      caseSensitive: false,
    );
    final matches = pPattern.allMatches(raw).toList();
    if (matches.isEmpty) return null;

    final starts = <Duration?>[];
    final bodies = <String>[];
    for (final match in matches) {
      final attrs = match.group(1) ?? '';
      starts.add(_parseTime(_attribute(attrs, 'begin')));
      bodies.add(match.group(2) ?? '');
    }

    final lines = <LyricLine>[];
    var hasWords = false;
    for (var i = 0; i < bodies.length; i++) {
      final begin = starts[i];
      if (begin == null) continue;

      var end = _parseTime(_attribute(matches[i].group(1) ?? '', 'end'));
      end ??= _nextStart(starts, i);
      end ??= begin + _lineTail;
      if (end <= begin) end = begin + _minimumLine;

      final root = _parseSpanTree(bodies[i]);
      final text = _nodeText(root).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;

      final words = _timedWords(root, lineStart: begin, lineEnd: end);
      if (words.isNotEmpty) hasWords = true;

      String? translation;
      for (final child in root.children) {
        if (_isTranslation(child)) {
          final value = _nodeText(child, skipTranslation: false).trim();
          if (value.isNotEmpty) translation = value;
        }
      }

      lines.add(
        LyricLine(
          text: text,
          start: begin,
          end: end,
          words: words,
          translation: translation,
        ),
      );
    }

    if (lines.isEmpty) return null;
    lines.sort((a, b) => a.start.compareTo(b.start));

    return SyncedLyricDocument(
      lines: List.unmodifiable(lines),
      syncLevel: hasWords ? LyricSyncLevel.word : LyricSyncLevel.line,
      raw: raw,
      sourceKind: sourceKind,
      providerId: providerId,
      language: language,
    );
  }

  Duration? _nextStart(List<Duration?> starts, int index) {
    for (var i = index + 1; i < starts.length; i++) {
      final value = starts[i];
      if (value != null) return value;
    }
    return null;
  }

  _SpanNode _parseSpanTree(String body) {
    final root = _SpanNode();
    final stack = <_SpanNode>[root];
    final tagPattern = RegExp(
      r'<span\b([^>]*)>|</span\s*>|<br\s*/?>',
      caseSensitive: false,
    );

    var cursor = 0;
    for (final match in tagPattern.allMatches(body)) {
      if (match.start > cursor) {
        stack.last.addText(
          _decodeEntities(body.substring(cursor, match.start)),
        );
      }
      cursor = match.end;

      final token = match.group(0) ?? '';
      final lower = token.toLowerCase();
      if (lower.startsWith('</span')) {
        if (stack.length > 1) stack.removeLast();
      } else if (lower.startsWith('<br')) {
        stack.last.addText('\n');
      } else {
        final attrs = match.group(1) ?? '';
        final node = _SpanNode()
          ..begin = _parseTime(_attribute(attrs, 'begin'))
          ..end = _parseTime(_attribute(attrs, 'end'))
          ..role =
              _attribute(attrs, 'role') ?? _attribute(attrs, 'ttm:role');
        stack.last.children.add(node);
        stack.last.flow.add(node);
        stack.add(node);
      }
    }

    if (cursor < body.length) {
      stack.last.addText(_decodeEntities(body.substring(cursor)));
    }
    return root;
  }

  String _nodeText(_SpanNode node, {bool skipTranslation = true}) {
    final buffer = StringBuffer();
    void visit(_SpanNode current) {
      if (skipTranslation && _isTranslation(current)) return;
      for (final item in current.flow) {
        if (item is String) {
          buffer.write(item);
        } else if (item is _SpanNode) {
          visit(item);
        }
      }
    }

    visit(node);
    return buffer.toString();
  }

  bool _isTranslation(_SpanNode node) {
    final role = (node.role ?? '').toLowerCase();
    return role.contains('translat');
  }

  List<LyricWord> _timedWords(
    _SpanNode node, {
    required Duration lineStart,
    required Duration lineEnd,
  }) {
    final words = <LyricWord>[];
    for (final child in node.children) {
      if (_isTranslation(child)) continue;
      final begin = child.begin;
      if (begin == null) {
        words.addAll(_timedWords(child, lineStart: lineStart, lineEnd: lineEnd));
        continue;
      }

      final syllables = <LyricSyllable>[];
      final timedGrands = child.children.where((grand) {
        return !_isTranslation(grand) && grand.begin != null;
      }).toList();
      for (var g = 0; g < timedGrands.length; g++) {
        final grand = timedGrands[g];
        final grandBegin = grand.begin!;
        var grandEnd = grand.end ??
            (g + 1 < timedGrands.length ? timedGrands[g + 1].begin : null) ??
            child.end ??
            lineEnd;
        if (grandEnd <= grandBegin) grandEnd = grandBegin + _minimumLine;
        if (grandEnd > lineEnd) grandEnd = lineEnd;
        if (grandEnd <= grandBegin) grandEnd = grandBegin + _minimumLine;
        final value = _nodeText(grand).trim();
        if (value.isNotEmpty) {
          syllables.add(
            LyricSyllable(
              text: value,
              start: grandBegin,
              end: grandEnd,
            ),
          );
        }
      }

      final text = _nodeText(child).replaceAll(RegExp(r'\s+'), ' ');
      var end = child.end ?? lineEnd;
      if (end <= begin) end = begin + _minimumLine;
      if (end > lineEnd) end = lineEnd;

      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      words.add(
        LyricWord(
          text: text,
          start: begin,
          end: end,
          syllables: List.unmodifiable(syllables),
        ),
      );
    }

    // Guarantee monotonic, non-overlapping word windows.
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      var end = word.end;
      if (i + 1 < words.length && words[i + 1].start > word.start) {
        end = words[i + 1].start;
      }
      if (end <= word.start) end = word.start + _minimumLine;
      if (end != word.end) {
        words[i] = LyricWord(
          text: word.text,
          start: word.start,
          end: end,
          syllables: word.syllables,
        );
      }
    }

    return words;
  }

  // ---------------------------------------------------------------------------
  // LRC / plain
  // ---------------------------------------------------------------------------

  SyncedLyricDocument _parseLrc(
    String raw, {
    String? providerId,
    required LyricSourceKind sourceKind,
    String? language,
  }) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = normalized.split('\n');

    final offsetPattern = RegExp(
      r'^\s*\[offset:\s*([+-]?\d+)\s*\]\s*$',
      caseSensitive: false,
    );
    final lineStampPattern = RegExp(
      r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]',
    );
    final metadataPattern = RegExp(
      r'^\s*\[([a-zA-Z][a-zA-Z0-9._-]*):(.*)\]\s*$',
    );

    var offsetMs = 0;
    final timed = <_TimedLine>[];
    final plain = <String>[];

    for (final row in rows) {
      final line = row.trimRight();
      if (line.trim().isEmpty) continue;

      final offsetMatch = offsetPattern.firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1) ?? '') ?? offsetMs;
        continue;
      }

      final stamps = lineStampPattern.allMatches(line).toList();
      if (stamps.isEmpty) {
        if (metadataPattern.hasMatch(line)) continue;
        plain.add(line.trim());
        continue;
      }

      final body = line.replaceAll(lineStampPattern, '');
      final wordStarts = _extractWordStarts(body);
      final text = _stripWordMarkers(body).trim();
      if (text.isEmpty) continue;

      for (final stamp in stamps) {
        final start = _stampToDuration(stamp) +
            Duration(milliseconds: offsetMs);
        timed.add(
          _TimedLine(
            start: start.isNegative ? Duration.zero : start,
            text: text,
            wordStarts: wordStarts,
          ),
        );
      }
    }

    if (timed.isEmpty) {
      final lines = <LyricLine>[];
      for (final line in plain) {
        lines.add(
          LyricLine(text: line, start: Duration.zero, end: Duration.zero),
        );
      }
      return SyncedLyricDocument(
        lines: List.unmodifiable(lines),
        syncLevel: LyricSyncLevel.plain,
        raw: raw,
        sourceKind: sourceKind,
        providerId: providerId,
        language: language,
      );
    }

    timed.sort((a, b) => a.start.compareTo(b.start));

    var hasWords = false;
    final lines = <LyricLine>[];
    for (var i = 0; i < timed.length; i++) {
      final current = timed[i];
      var end = i + 1 < timed.length ? timed[i + 1].start : null;
      if (end == null || end <= current.start) {
        end = current.start + _lineTail;
      }

      final words = <LyricWord>[];
      final starts = current.wordStarts;
      for (var w = 0; w < starts.length; w++) {
        final wordStart = starts[w].$1;
        final nextStart = w + 1 < starts.length ? starts[w + 1].$1 : null;
        var wordEnd = nextStart ?? end;
        if (wordEnd <= wordStart) wordEnd = wordStart + _minimumLine;
        if (wordEnd > end) wordEnd = end;
        if (wordEnd <= wordStart) wordEnd = wordStart + _minimumLine;
        final value = starts[w].$2.trim();
        if (value.isEmpty) continue;
        words.add(
          LyricWord(text: starts[w].$2, start: wordStart, end: wordEnd),
        );
      }
      if (words.isNotEmpty) hasWords = true;

      lines.add(
        LyricLine(
          text: current.text,
          start: current.start,
          end: end,
          words: words.isEmpty ? const [] : List.unmodifiable(words),
        ),
      );
    }

    return SyncedLyricDocument(
      lines: List.unmodifiable(lines),
      syncLevel: hasWords ? LyricSyncLevel.word : LyricSyncLevel.line,
      raw: raw,
      sourceKind: sourceKind,
      providerId: providerId,
      language: language,
    );
  }

  /// Word starts in an enhanced-LRC body, as (start, text-with-trailing-space).
  List<(Duration, String)> _extractWordStarts(String body) {
    final markerPattern = RegExp(r'<([^<>]+)>');
    final markers = <(Duration, int, int)>[];
    for (final match in markerPattern.allMatches(body)) {
      final time = _parseTime(match.group(1));
      if (time == null) continue;
      markers.add((time, match.start, match.end));
    }
    if (markers.isEmpty) return const [];

    final result = <(Duration, String)>[];
    for (var i = 0; i < markers.length; i++) {
      final (start, _, markerEnd) = markers[i];
      final end = i + 1 < markers.length ? markers[i + 1].$2 : body.length;
      if (end <= markerEnd) continue;
      result.add((start, body.substring(markerEnd, end)));
    }
    return result;
  }

  String _stripWordMarkers(String body) {
    final markerPattern = RegExp(r'<([^<>]+)>');
    return body.replaceAllMapped(markerPattern, (match) {
      return _parseTime(match.group(1)) == null ? match.group(0)! : '';
    });
  }

  Duration _stampToDuration(RegExpMatch match) {
    final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
    final fractionRaw = match.group(3) ?? '';
    var fractionMs = 0;
    if (fractionRaw.isNotEmpty) {
      final digits = int.tryParse(fractionRaw) ?? 0;
      fractionMs = switch (fractionRaw.length) {
        1 => digits * 100,
        2 => digits * 10,
        _ => digits,
      };
    }
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: fractionMs,
    );
  }

  /// Parses TTML clock values (`hh:mm:ss.mmm`, `mm:ss.mmm`), plain seconds
  /// (`12.5`), `12.5s`, and `12500ms`.
  Duration? _parseTime(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;

    var unitScale = 1000.0;
    if (value.endsWith('ms')) {
      value = value.substring(0, value.length - 2);
      unitScale = 1;
    } else if (value.endsWith('s')) {
      value = value.substring(0, value.length - 1);
      unitScale = 1000;
    }

    final parts = value.split(':');
    if (parts.length > 3) return null;

    var totalMs = 0.0;
    for (var i = 0; i < parts.length; i++) {
      final parsed = double.tryParse(parts[i].trim());
      if (parsed == null) return null;
      final isLast = i == parts.length - 1;
      final scale = isLast
          ? (parts.length == 1 && unitScale == 1 ? 1 : 1000)
          : (parts.length - 1 - i == 1 ? 60 * 1000 : 3600 * 1000);
      totalMs += parsed * scale;
    }

    if (totalMs.isNaN || totalMs.isInfinite || totalMs < 0) return null;
    return Duration(milliseconds: totalMs.round());
  }

  String? _attribute(String attrs, String name) {
    if (attrs.isEmpty || name.isEmpty) return null;
    final pattern = RegExp(
      '(?:^|\\s)${RegExp.escape(name)}\\s*=\\s*(["\'])(.*?)\\1',
      dotAll: true,
      caseSensitive: false,
    );
    final match = pattern.firstMatch(attrs);
    return match?.group(2);
  }

  String _decodeEntities(String value) {
    if (!value.contains('&')) return value;
    return value
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }
}

class _SpanNode {
  _SpanNode();

  /// Text and child nodes in source order, used for faithful reconstruction.
  final List<Object> flow = [];
  final List<_SpanNode> children = [];
  Duration? begin;
  Duration? end;
  String? role;

  void addText(String value) {
    flow.add(value);
  }
}

class _TimedLine {
  _TimedLine({
    required this.start,
    required this.text,
    required this.wordStarts,
  });

  final Duration start;
  final String text;
  final List<(Duration, String)> wordStarts;
}
