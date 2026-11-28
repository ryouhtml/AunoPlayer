import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:auno_player/models/synced_lyric_document.dart';
import 'package:auno_player/services/lyrics_providers.dart';

/// Translates a document after it is fetched.
///
/// Nothing runs unless a translation endpoint was supplied at build time:
/// `--dart-define=AUNO_LYRICS_TRANSLATE_ENDPOINT=https://…`. Embedded TTML
/// translations are parsed by [LyricsParser] and never overwritten here.
class LyricsTranslationService {
  LyricsTranslationService();

  static const String endpoint = String.fromEnvironment(
    'AUNO_LYRICS_TRANSLATE_ENDPOINT',
  );

  static const Duration _timeout = Duration(milliseconds: 4500);
  static final http.Client _client = http.Client();
  static final Map<String, List<String>> _cache = {};

  bool get isConfigured => endpoint.trim().isNotEmpty;

  Future<SyncedLyricDocument> translate(
    SyncedLyricDocument document, {
    required String target,
    required LyricsCancellationToken cancellationToken,
  }) async {
    final language = target.trim().toLowerCase();
    if (!isConfigured || language.isEmpty || language == 'off') {
      return document;
    }
    if (document.lines.isEmpty) return document;

    final texts = [for (final line in document.lines) line.text];
    final key = '$language|${texts.join('\n')}';
    var translated = _cache[key];

    if (translated == null) {
      try {
        cancellationToken.throwIfCancelled();
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'User-Agent': 'AunoPlayer/1.0 (lyrics engine)',
              },
              body: jsonEncode({
                'text': texts.join('\n'),
                'lines': texts,
                'target': language,
                'source': 'auto',
                'format': 'text',
              }),
            )
            .timeout(_timeout);
        cancellationToken.throwIfCancelled();
        if (response.statusCode != 200) return document;

        final decoded = jsonDecode(response.body);
        translated = _extractTranslations(decoded, expected: texts.length);
        if (translated == null) return document;
        if (_cache.length > 200) _cache.remove(_cache.keys.first);
        _cache[key] = translated;
      } on LyricsFetchCancelled {
        rethrow;
      } catch (_) {
        return document;
      }
    }

    final values = translated;
    if (values.length != document.lines.length) {
      return document;
    }

    return SyncedLyricDocument(
      lines: [
        for (var i = 0; i < document.lines.length; i++)
          document.lines[i].copyWith(translation: values[i].trim()),
      ],
      syncLevel: document.syncLevel,
      raw: document.raw,
      sourceKind: document.sourceKind,
      providerId: document.providerId,
      language: document.language,
      title: document.title,
      artist: document.artist,
    );
  }

  List<String>? _extractTranslations(Object? payload, {required int expected}) {
    if (payload is List && payload.length == expected) {
      final values = payload.map((item) => '$item').toList();
      return values;
    }
    if (payload is Map) {
      final direct = payload['translations'];
      if (direct is List && direct.length == expected) {
        return direct.map((item) => '$item').toList();
      }
      for (final key in const [
        'translatedText',
        'translated_text',
        'translation',
        'text',
        'result',
      ]) {
        final value = payload[key];
        if (value is String && value.trim().isNotEmpty) {
          final lines = value.split('\n');
          if (lines.length == expected) return lines;
        }
      }
    }
    return null;
  }
}
