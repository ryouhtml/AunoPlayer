import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/features/player/widgets/synced_lyrics_view.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/providers/app_preferences_provider.dart';
import 'package:auno_player/services/app_preferences_service.dart';
import 'package:auno_player/services/lyrics_service.dart';
import 'package:auno_player/services/player_service.dart';

class _FakePlayerService extends Fake implements PlayerService {
  @override
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(
    Duration.zero,
  );

  @override
  void beginInteractiveSeek() {}

  @override
  void endInteractiveSeek() {}

  @override
  Future<void> seek(Duration position) async {}
}

class _DefaultPreferences extends AppPreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences();
}

void main() {
  final lyrics = LyricsData(
    lines: const [
      LyricsLine(timestamp: Duration.zero, text: 'First line'),
      LyricsLine(timestamp: Duration(seconds: 5), text: 'Active line'),
      LyricsLine(timestamp: Duration(seconds: 10), text: 'Later line'),
    ],
    isSynchronized: true,
    rawContent: '',
  );

  testWidgets('strip follows playback position and taps into full lyrics', (
    tester,
  ) async {
    final position = ValueNotifier(const Duration(seconds: 6));
    var taps = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(_DefaultPreferences.new),
        ],
        child: MaterialApp(
          locale: kFallbackLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kAppLocalizationsDelegates,
          home: Scaffold(
            body: SyncedLyricsView(
              key: const ValueKey('lyrics-strip'),
              playerService: _FakePlayerService(),
              lyricsService: LyricsService(),
              lyrics: lyrics,
              positionNotifier: position,
              strip: true,
              onStripTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active line'), findsOneWidget);
    expect(find.text('First line'), findsNothing);

    position.value = const Duration(seconds: 11);
    await tester.pumpAndSettle();
    expect(find.text('Later line'), findsOneWidget);
    expect(find.text('Active line'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lyrics-strip')));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain lyrics strip shows the first line without invented timing', (
    tester,
  ) async {
    final plain = LyricsData(
      lines: const [LyricsLine(timestamp: Duration.zero, text: 'Untimed line')],
      isSynchronized: false,
      rawContent: 'Untimed line',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(_DefaultPreferences.new),
        ],
        child: MaterialApp(
          locale: kFallbackLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kAppLocalizationsDelegates,
          home: Scaffold(
            body: SyncedLyricsView(
              playerService: _FakePlayerService(),
              lyricsService: LyricsService(),
              lyrics: plain,
              strip: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Untimed line'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
