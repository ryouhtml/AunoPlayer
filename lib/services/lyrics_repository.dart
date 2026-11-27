import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'package:auno_player/models/song.dart';
import 'package:auno_player/models/synced_lyric_document.dart';
import 'package:auno_player/services/lyrics_engine_settings.dart';
import 'package:auno_player/services/lyrics_parser.dart';
import 'package:auno_player/services/lyrics_providers.dart';
import 'package:auno_player/services/lyrics_service.dart';
import 'package:auno_player/services/lyrics_translation_service.dart';

/// Resolves lyrics in a fixed order:
///
/// 1. embedded tag / sidecar / manual file
/// 2. in-memory document cache
/// 3. on-disk provider cache
/// 4. enabled providers, sequentially, 4.5 s each
///
/// A newer request cancels the previous one: track skips never leave a stale
/// lyric panel waiting on an old provider.
class LyricsRepository {
  LyricsRepository({
    LyricsService? localService,
    LyricsParser parser = const LyricsParser(),
    List<LyricsProvider>? providers,
    LyricsTranslationService? translationService,
  })  : _localService = localService ?? LyricsService(),
        _parser = parser,
        _providers = providers,
        _translationService = translationService ?? LyricsTranslationService();

  static const Duration providerTimeout = Duration(milliseconds: 4500);

  final LyricsService _localService;
  final LyricsParser _parser;
  final List<LyricsProvider>? _providers;
  final LyricsTranslationService _translationService;

  final Map<String, SyncedLyricDocument> _memory = {};
  int _generation = 0;
  LyricsCancellationToken? _activeToken;

  void cancelPending() {
    _generation++;
    _activeToken?.cancel();
    _activeToken = null;
  }

  void invalidate(Song song) {
    _memory.remove(_memoryKey(song));
  }

  void clearMemoryCache() => _memory.clear();

  Future<SyncedLyricDocument?> loadForSong(
    Song song, {
    required LyricsEngineSettings settings,
    bool forceRefresh = false,
  }) async {
    cancelPending();
    final generation = _generation;
    final token = LyricsCancellationToken();
    _activeToken = token;
    final memoryKey = _memoryKey(song);

    bool stale() => generation != _generation || token.isCancelled;

    // Local files always win and are cheap to re-read.
    final local = await _loadLocal(song);
    if (stale()) return null;
    if (local != null) {
      _memory[memoryKey] = local;
      return local;
    }

    if (!forceRefresh) {
      final memory = _memory[memoryKey];
      if (memory != null) return memory;

      final disk = await _readDiskCache(memoryKey);
      if (stale()) return null;
      if (disk != null) {
        _memory[memoryKey] = disk;
        return disk;
      }
    }

    if (!settings.onlineEnabled) return null;

    var document = await _searchProviders(song, settings, token);
    if (stale()) return null;
    if (document == null) return null;

    document = await _translationService.translate(
      document,
      target: settings.translationLanguage,
      cancellationToken: token,
    );
    if (stale()) return null;

    _memory[memoryKey] = document;
    await _writeDiskCache(memoryKey, document);
    return document;
  }

  Future<SyncedLyricDocument?> _loadLocal(Song song) async {
    final data = await _localService.loadLyricsForSong(song, forceRefresh: true);
    if (data == null || data.lines.isEmpty) return null;

    final source = data.source ?? '';
    final kind = source.contains('embedded') || source.contains('tag')
        ? LyricSourceKind.embedded
        : LyricSourceKind.sidecar;

    final lines = <LyricLine>[];
    for (var i = 0; i < data.lines.length; i++) {
      final line = data.lines[i];
      var end = i + 1 < data.lines.length
          ? data.lines[i + 1].timestamp
          : line.timestamp + const Duration(seconds: 5);
      if (end <= line.timestamp) {
        end = line.timestamp + const Duration(seconds: 2);
      }

      final words = <LyricWord>[];
      final sourceWords = line.words ?? const <LyricsWord>[];
      for (var w = 0; w < sourceWords.length; w++) {
        final word = sourceWords[w];
        if (word.text.trim().isEmpty) continue;
        var wordEnd = w + 1 < sourceWords.length
            ? sourceWords[w + 1].start
            : end;
        if (wordEnd <= word.start) {
          wordEnd = word.start + const Duration(milliseconds: 500);
        }
        words.add(
          LyricWord(text: word.text, start: word.start, end: wordEnd),
        );
      }

      lines.add(
        LyricLine(
          text: line.text,
          start: line.timestamp,
          end: end,
          words: words.isEmpty ? const [] : List.unmodifiable(words),
        ),
      );
    }

    final hasWords = lines.any((line) => line.hasWordTiming);
    return SyncedLyricDocument(
      lines: List.unmodifiable(lines),
      syncLevel: hasWords
          ? LyricSyncLevel.word
          : data.isSynchronized
              ? LyricSyncLevel.line
              : LyricSyncLevel.plain,
      raw: data.rawContent,
      sourceKind: kind,
      providerId: source.isEmpty ? null : source,
    );
  }

  Future<SyncedLyricDocument?> _searchProviders(
    Song song,
    LyricsEngineSettings settings,
    LyricsCancellationToken token,
  ) async {
    final query = LyricsTrackQuery(
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
    );

    SyncedLyricDocument? plainFallback;
    for (final id in settings.providerOrder) {
      if (token.isCancelled) return null;
      if (!settings.enabledProviderIds.contains(id)) continue;

      final provider = _providerFor(id);
      if (provider == null || !provider.isConfigured) continue;

      try {
        final document = await provider.fetch(
          query,
          timeout: providerTimeout,
          cancellationToken: token,
        );
        if (document == null || document.lines.isEmpty) continue;
        if (document.syncLevel != LyricSyncLevel.plain) return document;
        plainFallback ??= document;
      } on LyricsFetchCancelled {
        return null;
      } catch (_) {
        // One broken provider must never stop the fallback chain.
      }
    }
    return plainFallback;
  }

  LyricsProvider? _providerFor(String id) {
    final override = _providers;
    if (override != null) {
      for (final provider in override) {
        if (provider.id == id) return provider;
      }
      return null;
    }
    return lyricsProviderById(id);
  }

  String _memoryKey(Song song) {
    final input = [
      _normalize(song.title),
      _normalize(song.artist),
      _normalize(song.album),
      song.duration.inSeconds.toString(),
    ].join('|');
    return sha1.convert(utf8.encode(input)).toString();
  }

  String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<Directory?> _cacheDirectory() async {
    try {
      final root = await getApplicationSupportDirectory();
      final directory = Directory('${root.path}${Platform.pathSeparator}lyrics_cache');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } catch (_) {
      return null;
    }
  }

  Future<SyncedLyricDocument?> _readDiskCache(String key) async {
    final directory = await _cacheDirectory();
    if (directory == null) return null;

    final file = File('${directory.path}${Platform.pathSeparator}$key.json');
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      final raw = decoded['raw'];
      if (raw is! String || raw.trim().isEmpty) return null;

      final providerId = decoded['providerId'] as String?;
      final language = decoded['language'] as String?;
      final document = _parser.parse(
        raw,
        providerId: providerId,
        sourceKind: LyricSourceKind.cached,
        language: language,
      );
      return document.lines.isEmpty ? null : document;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(
    String key,
    SyncedLyricDocument document,
  ) async {
    final directory = await _cacheDirectory();
    if (directory == null) return;

    final file = File('${directory.path}${Platform.pathSeparator}$key.json');
    try {
      await file.writeAsString(
        jsonEncode({
          'version': 1,
          'providerId': document.providerId,
          'language': document.language,
          'syncLevel': document.syncLevel.name,
          'raw': document.raw,
        }),
      );
    } catch (_) {
      // Cache writes are best-effort.
    }
  }
}

extension SyncedLyricDocumentConversion on SyncedLyricDocument {
  LyricsData toLyricsData() {
    return LyricsData(
      lines: [
        for (final line in lines)
          LyricsLine(
            timestamp: line.start,
            text: line.text,
            words: line.words.isEmpty
                ? null
                : [
                    for (final word in line.words)
                      LyricsWord(
                        start: word.start,
                        end: word.end,
                        text: word.text,
                      ),
                  ],
          ),
      ],
      isSynchronized: syncLevel != LyricSyncLevel.plain,
      source: providerId == null ? 'online' : 'online:$providerId',
      rawContent: raw,
    );
  }
}
