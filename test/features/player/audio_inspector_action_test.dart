import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auno_player/core/theme/app_theme.dart';
import 'package:auno_player/data/repositories/song_repository.dart';
import 'package:auno_player/features/player/widgets/player_navigation.dart';
import 'package:auno_player/features/player/widgets/song_actions_sheet.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/providers/player_provider.dart';
import 'package:auno_player/services/player_service.dart';

class _EmptyPlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _FakePlayerService extends Fake implements PlayerService {
  @override
  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier(null);

  @override
  final ValueNotifier<double> playbackSpeedNotifier = ValueNotifier(1.5);

  @override
  final ValueNotifier<double> pitchSemitonesNotifier = ValueNotifier(0.0);

  @override
  final ValueNotifier<Duration?> sleepTimerRemainingNotifier = ValueNotifier(
    null,
  );
}

class _FakeSongRepository extends Fake implements SongRepository {}

const _inspectable = Song(
  id: 'inspector-eligible',
  title: 'Inspectable Track',
  artist: 'Auno Tests',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
  filePath: '/music/inspectable.flac',
);

const _documentProvider = Song(
  id: 'inspector-blocked',
  title: 'Document Provider Track',
  artist: 'Auno Tests',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
  filePath: 'content://com.example.document/audio',
);

Widget _host(Widget child) => ProviderScope(
  overrides: [
    playerProvider.overrideWith(_EmptyPlayer.new),
    currentSongProvider.overrideWithValue(null),
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Widget _sheet(PlayerService service, Song song) => Builder(
  builder: (context) => SongActionsSheet(
    parentContext: context,
    playerService: service,
    song: song,
    isVisualizationMode: false,
    onShowLyrics: () {},
    onToggleVisualization: (_) {},
    onShowPlayerLayout: (_) {},
    navigation: PlayerNavigation(
      playerService: service,
      songRepository: _FakeSongRepository(),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('inspector entry appears only for analyzable local tracks', (
    tester,
  ) async {
    final en = lookupFlickLocalizations(kFallbackLocale);
    final service = _FakePlayerService();

    await tester.pumpWidget(_host(_sheet(service, _inspectable)));
    await tester.pumpAndSettle();
    expect(find.text(en.analyzeTrack), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(_sheet(service, _documentProvider)));
    await tester.pumpAndSettle();
    expect(find.text(en.analyzeTrack), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
