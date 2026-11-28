import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auno_player/models/song.dart';
import 'package:auno_player/models/synced_lyric_document.dart';
import 'package:auno_player/services/lyrics_engine_settings.dart';
import 'package:auno_player/services/lyrics_parser.dart';
import 'package:auno_player/services/lyrics_providers.dart';
import 'package:auno_player/services/lyrics_repository.dart';

class _FakeLyricsProvider extends LyricsProvider {
  _FakeLyricsProvider({
    required this.id,
    this.payload,
    this.fail = false,
    this.delay = Duration.zero,
  });

  @override
  final String id;
  final String? payload;
  final bool fail;
  final Duration delay;

  @override
  String get displayName => id;

  @override
  String get endpoint => 'https://fake.invalid/lyrics';

  @override
  Future<SyncedLyricDocument?> fetch(
    LyricsTrackQuery query, {
    required Duration timeout,
    required LyricsCancellationToken cancellationToken,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    cancellationToken.throwIfCancelled();
    if (fail) throw StateError('provider exploded');
    if (payload == null) return null;
    return const LyricsParser().parse(payload!, providerId: id);
  }
}

Song _song() {
  return const Song(
    id: 'song-1',
    title: 'Midnight',
    artist: 'Auno',
    album: 'Night',
    duration: Duration(minutes: 3, seconds: 20),
    fileType: 'flac',
  );
}

LyricsEngineSettings _settings(List<String> order) {
  return LyricsEngineSettings(
    providerOrder: order,
    enabledProviderIds: order.toSet(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('default registry exposes all 15 providers in priority order', () {
    expect(allLyricsProviders.length, 15);
    expect(LyricsEngineSettings.defaults.providerOrder, [
      for (final provider in allLyricsProviders) provider.id,
    ]);
    expect(
      allLyricsProviders.map((provider) => provider.displayName),
      containsAll([
        'lrc.red',
        'BiniLyrics',
        'BetterLyrics',
        'BetterLyrics Portato',
        'PaxSenix',
        'PaxSenix: Spotify',
        'PaxSenix: Musixmatch',
        'LyricsPlus',
        'Unison',
        'YouTube captions',
        'YouTube Music',
        'KuGou',
        'LRCLIB',
        'Musixmatch',
        'Genius',
      ]),
    );
  });

  test('falls through failing providers to the next enabled one', () async {
    final repository = LyricsRepository(
      providers: [
        _FakeLyricsProvider(id: 'a', fail: true),
        _FakeLyricsProvider(id: 'b', payload: '[00:01.00]Hello'),
      ],
    );

    final document = await repository.loadForSong(
      _song(),
      settings: _settings(['a', 'b']),
    );

    expect(document, isNotNull);
    expect(document!.providerId, 'b');
    expect(document.lines.single.text, 'Hello');
  });

  test('skips disabled providers', () async {
    final repository = LyricsRepository(
      providers: [
        _FakeLyricsProvider(id: 'a', payload: '[00:01.00]From A'),
        _FakeLyricsProvider(id: 'b', payload: '[00:01.00]From B'),
      ],
    );

    final document = await repository.loadForSong(
      _song(),
      settings: LyricsEngineSettings(
        providerOrder: const ['a', 'b'],
        enabledProviderIds: const {'b'},
      ),
    );

    expect(document!.providerId, 'b');
  });

  test('keeps a plain result only after every synced option failed', () async {
    final repository = LyricsRepository(
      providers: [
        _FakeLyricsProvider(id: 'a', payload: 'Plain fallback'),
        _FakeLyricsProvider(id: 'b'),
      ],
    );

    final document = await repository.loadForSong(
      _song(),
      settings: _settings(['a', 'b']),
    );

    expect(document!.syncLevel, LyricSyncLevel.plain);
    expect(document.lines.single.text, 'Plain fallback');
  });

  test('a newer request cancels the older one', () async {
    final repository = LyricsRepository(
      providers: [
        _FakeLyricsProvider(
          id: 'a',
          payload: '[00:01.00]Slow',
          delay: const Duration(milliseconds: 40),
        ),
      ],
    );
    final settings = _settings(['a']);

    final first = repository.loadForSong(_song(), settings: settings);
    final second = repository.loadForSong(_song(), settings: settings);

    expect(await first, isNull);
    expect(await second, isNotNull);
  });
}
