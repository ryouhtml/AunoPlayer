import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auno_player/core/theme/app_theme.dart';
import 'package:auno_player/features/queue/screens/queue_screen.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/providers/player_provider.dart';

class _FakePlayer extends PlayerNotifier {
  final List<List<int>> queueMoves = [];
  final List<List<int>> upNextMoves = [];

  @override
  PlayerState build() => const PlayerState(
        queue: [_queueA, _queueB],
        upNext: [_upNextA, _upNextB],
      );

  @override
  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    queueMoves.add([oldIndex, newIndex]);
  }

  @override
  Future<void> moveUpNextItem(int oldIndex, int newIndex) async {
    upNextMoves.add([oldIndex, newIndex]);
  }
}

const _queueA = Song(
  id: 'queue-a',
  title: 'Queue A',
  artist: 'Auno Tests',
  duration: Duration(minutes: 1),
  fileType: 'FLAC',
);

const _queueB = Song(
  id: 'queue-b',
  title: 'Queue B',
  artist: 'Auno Tests',
  duration: Duration(minutes: 1),
  fileType: 'FLAC',
);

const _upNextA = Song(
  id: 'up-next-a',
  title: 'Up Next A',
  artist: 'Auno Tests',
  duration: Duration(minutes: 1),
  fileType: 'FLAC',
);

const _upNextB = Song(
  id: 'up-next-b',
  title: 'Up Next B',
  artist: 'Auno Tests',
  duration: Duration(minutes: 1),
  fileType: 'FLAC',
);

Widget _host(PlayerNotifier player) => ProviderScope(
      overrides: [
        playerProvider.overrideWith(() => player),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: kFallbackLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        localeResolutionCallback: resolveAppLocale,
        builder: (context, child) {
          LocaleController.instance.bind(AppLocalizations.of(context));
          return child!;
        },
        home: const Scaffold(body: QueuePanel()),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('embedded queue panel keeps both reorder callbacks', (
    tester,
  ) async {
    final player = _FakePlayer();
    await tester.pumpWidget(_host(player));
    await tester.pumpAndSettle();

    final lists = find.byType(SliverReorderableList);
    expect(lists, findsNWidgets(2));

    tester.widget<SliverReorderableList>(lists.at(0)).onReorder!(0, 2);
    tester.widget<SliverReorderableList>(lists.at(1)).onReorder!(1, 0);
    await tester.pump();

    expect(player.upNextMoves, [
      [0, 1],
    ]);
    expect(player.queueMoves, [
      [1, 0],
    ]);
    expect(tester.takeException(), isNull);
  });
}
