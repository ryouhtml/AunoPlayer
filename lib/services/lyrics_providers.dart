import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:auno_player/models/synced_lyric_document.dart';
import 'package:auno_player/services/lyrics_parser.dart';

/// Metadata used to look a track up across every provider.
class LyricsTrackQuery {
  const LyricsTrackQuery({
    required this.title,
    required this.artist,
    this.album,
    this.duration,
  });

  final String title;
  final String artist;
  final String? album;
  final Duration? duration;

  String get displayQuery => '$artist $title'.trim();

  Map<String, String> get queryParameters {
    final params = <String, String>{
      'track_name': title,
      'artist_name': artist,
      'q': displayQuery,
    };
    final albumName = album?.trim();
    if (albumName != null && albumName.isNotEmpty) {
      params['album_name'] = albumName;
    }
    final seconds = duration?.inSeconds ?? 0;
    if (seconds > 0) params['duration'] = seconds.toString();
    return params;
  }
}

/// Cooperative cancellation for rapidly skipped tracks.
class LyricsCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const LyricsFetchCancelled();
  }
}

class LyricsFetchCancelled implements Exception {
  const LyricsFetchCancelled();

  @override
  String toString() => 'LyricsFetchCancelled';
}

/// One remote lyric source.
///
/// Every adapter is independent: an unconfigured or failing provider returns
/// null and the repository moves to the next entry in the priority list.
abstract class LyricsProvider {
  const LyricsProvider();

  String get id;

  String get displayName;

  /// Base endpoint. Empty means "not configured in this build", which makes
  /// the provider a no-op instead of a broken request.
  String get endpoint;

  bool get isConfigured => endpoint.trim().isNotEmpty;

  Map<String, String> get headers => const {
    'Accept': 'application/json, text/plain, */*',
    'User-Agent': 'AunoPlayer/1.0 (lyrics engine)',
  };

  Future<SyncedLyricDocument?> fetch(
    LyricsTrackQuery query, {
    required Duration timeout,
    required LyricsCancellationToken cancellationToken,
  });
}

/// Shared HTTP + JSON plumbing for the community providers.
///
/// Endpoints are supplied at build time:
/// `flutter build apk --dart-define=AUNO_LYRICS_UNISON_ENDPOINT=https://…`.
abstract class HttpJsonLyricsProvider extends LyricsProvider {
  const HttpJsonLyricsProvider();

  static final http.Client _client = http.Client();
  static const LyricsParser _parser = LyricsParser();

  /// One or more URLs tried in order within the provider's timeout budget.
  List<Uri> buildUris(LyricsTrackQuery query) {
    return [_resolveUri(endpoint, query)];
  }

  @override
  Future<SyncedLyricDocument?> fetch(
    LyricsTrackQuery query, {
    required Duration timeout,
    required LyricsCancellationToken cancellationToken,
  }) async {
    if (!isConfigured) return null;
    cancellationToken.throwIfCancelled();

    final deadline = DateTime.now().add(timeout);
    for (final uri in buildUris(query)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return null;
      cancellationToken.throwIfCancelled();

      final response = await _get(uri, remaining, cancellationToken);
      if (response == null) continue;

      final payload = _decode(response);
      if (payload == null) continue;

      final text = extractLyricText(payload);
      if (text == null || text.trim().isEmpty) continue;

      final document = _parser.parse(
        text,
        providerId: id,
        sourceKind: LyricSourceKind.online,
      );
      if (document.lines.isEmpty) continue;
      return document;
    }
    return null;
  }

  Future<http.Response?> _get(
    Uri uri,
    Duration timeout,
    LyricsCancellationToken token,
  ) async {
    try {
      final response = await _client.get(uri, headers: headers).timeout(timeout);
      token.throwIfCancelled();
      if (response.statusCode != 200) return null;
      return response;
    } on LyricsFetchCancelled {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Object? _decode(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  Uri _resolveUri(String raw, LyricsTrackQuery query) {
    if (raw.contains('{')) {
      var resolved = raw;
      query.queryParameters.forEach((key, value) {
        resolved = resolved.replaceAll('{$key}', Uri.encodeComponent(value));
      });
      return Uri.parse(resolved);
    }
    final base = Uri.parse(raw);
    return base.replace(
      queryParameters: {...base.queryParameters, ...query.queryParameters},
    );
  }

  static const List<String> _textKeys = [
    'syncedLyrics',
    'synced_lyrics',
    'syncedLyric',
    'karaokeLyrics',
    'lrc',
    'lyrics',
    'plainLyrics',
    'plain_lyrics',
    'lyric',
    'content',
    'text',
    'ttml',
    'xml',
  ];

  static const List<String> _containerKeys = [
    'data',
    'result',
    'results',
    'response',
    'tracks',
    'items',
    'songs',
    'docs',
  ];

  /// Finds the richest lyric payload in an arbitrary provider response.
  String? extractLyricText(Object? node) {
    final candidates = <String>[];
    void collect(Object? value) {
      if (value is String) {
        if (value.trim().isNotEmpty) candidates.add(value);
        return;
      }
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
        return;
      }
      if (value is Map) {
        for (final key in _textKeys) {
          final direct = value[key];
          if (direct is String && direct.trim().isNotEmpty) {
            candidates.add(direct);
          }
        }
        for (final key in _containerKeys) {
          final nested = value[key];
          if (nested is Map || nested is List) collect(nested);
        }
        if (value['lyrics'] is Map || value['lyrics'] is List) {
          collect(value['lyrics']);
        }
      }
    }

    collect(node);
    if (candidates.isEmpty) return null;

    final synced = candidates.where(_looksTimed).toList();
    if (synced.isNotEmpty) {
      synced.sort((a, b) => b.length.compareTo(a.length));
      return synced.first;
    }
    return candidates.first;
  }

  bool _looksTimed(String text) {
    return RegExp(
      r'\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\]|<\d{1,3}:\d{2}',
    ).hasMatch(text);
  }
}

// -----------------------------------------------------------------------------
// Configured providers
// -----------------------------------------------------------------------------

class LrcRedLyricsProvider extends HttpJsonLyricsProvider {
  const LrcRedLyricsProvider();

  @override
  String get id => 'lrc_red';

  @override
  String get displayName => 'lrc.red';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_LRC_RED_ENDPOINT');
}

class BiniLyricsProvider extends HttpJsonLyricsProvider {
  const BiniLyricsProvider();

  @override
  String get id => 'bini_lyrics';

  @override
  String get displayName => 'BiniLyrics';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_BINI_ENDPOINT');
}

class BetterLyricsProvider extends HttpJsonLyricsProvider {
  const BetterLyricsProvider();

  @override
  String get id => 'better_lyrics';

  @override
  String get displayName => 'BetterLyrics';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_BETTER_ENDPOINT');
}

class BetterLyricsPortatoProvider extends HttpJsonLyricsProvider {
  const BetterLyricsPortatoProvider();

  @override
  String get id => 'better_lyrics_portato';

  @override
  String get displayName => 'BetterLyrics Portato';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_PORTATO_ENDPOINT');
}

class PaxSenixProvider extends HttpJsonLyricsProvider {
  const PaxSenixProvider();

  @override
  String get id => 'paxsenix';

  @override
  String get displayName => 'PaxSenix';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_PAXSENIX_ENDPOINT');
}

class PaxSenixSpotifyProvider extends HttpJsonLyricsProvider {
  const PaxSenixSpotifyProvider();

  @override
  String get id => 'paxsenix_spotify';

  @override
  String get displayName => 'PaxSenix: Spotify';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_PAXSENIX_SPOTIFY_ENDPOINT');
}

class PaxSenixMusixmatchProvider extends HttpJsonLyricsProvider {
  const PaxSenixMusixmatchProvider();

  @override
  String get id => 'paxsenix_musixmatch';

  @override
  String get displayName => 'PaxSenix: Musixmatch';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_PAXSENIX_MUSIXMATCH_ENDPOINT');
}

class LyricsPlusProvider extends HttpJsonLyricsProvider {
  const LyricsPlusProvider();

  @override
  String get id => 'lyrics_plus';

  @override
  String get displayName => 'LyricsPlus';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_PLUS_ENDPOINT');
}

class UnisonLyricsProvider extends HttpJsonLyricsProvider {
  const UnisonLyricsProvider();

  @override
  String get id => 'unison';

  @override
  String get displayName => 'Unison';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_UNISON_ENDPOINT');
}

class YouTubeCaptionsProvider extends HttpJsonLyricsProvider {
  const YouTubeCaptionsProvider();

  @override
  String get id => 'youtube_captions';

  @override
  String get displayName => 'YouTube captions';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_YOUTUBE_CAPTIONS_ENDPOINT');
}

class YouTubeMusicProvider extends HttpJsonLyricsProvider {
  const YouTubeMusicProvider();

  @override
  String get id => 'youtube_music';

  @override
  String get displayName => 'YouTube Music';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_YOUTUBE_MUSIC_ENDPOINT');
}

class KuGouLyricsProvider extends HttpJsonLyricsProvider {
  const KuGouLyricsProvider();

  @override
  String get id => 'kugou';

  @override
  String get displayName => 'KuGou';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_KUGOU_ENDPOINT');
}

/// Fully functional without configuration: exact lookup, then search.
class LrclibLyricsProvider extends HttpJsonLyricsProvider {
  const LrclibLyricsProvider();

  static const String _baseUrl = 'https://lrclib.net/api';

  @override
  String get id => 'lrclib';

  @override
  String get displayName => 'LRCLIB';

  @override
  String get endpoint => '$_baseUrl/get';

  @override
  List<Uri> buildUris(LyricsTrackQuery query) {
    return [
      Uri.parse('$_baseUrl/get').replace(queryParameters: query.queryParameters),
      Uri.parse('$_baseUrl/search')
          .replace(queryParameters: query.queryParameters),
    ];
  }
}

class MusixmatchLyricsProvider extends HttpJsonLyricsProvider {
  const MusixmatchLyricsProvider();

  @override
  String get id => 'musixmatch';

  @override
  String get displayName => 'Musixmatch';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_MUSIXMATCH_ENDPOINT');
}

class GeniusLyricsProvider extends HttpJsonLyricsProvider {
  const GeniusLyricsProvider();

  @override
  String get id => 'genius';

  @override
  String get displayName => 'Genius';

  @override
  String get endpoint =>
      const String.fromEnvironment('AUNO_LYRICS_GENIUS_ENDPOINT');
}

/// Registry in the default priority order shown in Settings.
const List<LyricsProvider> allLyricsProviders = [
  LrcRedLyricsProvider(),
  BiniLyricsProvider(),
  BetterLyricsProvider(),
  BetterLyricsPortatoProvider(),
  PaxSenixProvider(),
  PaxSenixSpotifyProvider(),
  PaxSenixMusixmatchProvider(),
  LyricsPlusProvider(),
  UnisonLyricsProvider(),
  YouTubeCaptionsProvider(),
  YouTubeMusicProvider(),
  KuGouLyricsProvider(),
  LrclibLyricsProvider(),
  MusixmatchLyricsProvider(),
  GeniusLyricsProvider(),
];

LyricsProvider? lyricsProviderById(String id) {
  for (final provider in allLyricsProviders) {
    if (provider.id == id) return provider;
  }
  return null;
}
