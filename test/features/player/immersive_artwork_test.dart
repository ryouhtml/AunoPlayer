import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/core/utils/app_haptics.dart';
import 'package:auno_player/features/player/widgets/album_art_box.dart';
import 'package:auno_player/features/player/widgets/song_stage.dart';
import 'package:auno_player/models/album_color_mode.dart';
import 'package:auno_player/models/player_screen_mode.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/providers/providers.dart';
import 'package:auno_player/services/app_preferences_service.dart';
import 'package:auno_player/services/lyrics_service.dart';
import 'package:auno_player/services/player_service.dart';

class _FakePlayerService extends Fake implements PlayerService {
  @override
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);

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

const _song = Song(
  id: 'phase2-song',
  title: 'Phase Two Track',
  artist: 'Auno Tests',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
  bitDepth: 24,
  sampleRate: 96000,
  filePath: '/tmp/phase2.flac',
);

Widget _host(Widget child) => ProviderScope(
  overrides: [
    appPreferencesProvider.overrideWith(_DefaultPreferences.new),
    audioOutputDiagnosticsProvider.overrideWithValue(null),
    uac2BitPerfectIndicatorProvider.overrideWithValue(false),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 1600),
          devicePixelRatio: 1,
          disableAnimations: true,
        ),
        child: child,
      ),
    ),
  ),
);

void _setPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

SongStage _stage({
  required PlayerService playerService,
  required PlayerScreenMode mode,
  required bool fullView,
  Object? heroTag,
}) {
  return SongStage(
    song: _song,
    lyricsMode: false,
    visualizationMode: false,
    immersiveFullView: fullView,
    playerScreenMode: mode,
    albumColorMode: AlbumColorMode.off,
    playerService: playerService,
    lyricsService: LyricsService(),
    positionNotifier: ValueNotifier(Duration.zero),
    formatDuration: (duration) => '3:00',
    onNavigateToArtistDetail: (_) {},
    onNavigateToAlbumDetail: (_) {},
    buildFileInfoRow: (_, __, ___) => const SizedBox.shrink(),
    onToggleLyrics: () {},
    immersiveShowFileInfo: false,
    showWaveform: false,
    heroTag: heroTag,
  );
}

void main() {
  setUp(() => AppHaptics.setEnabled(false));
  tearDown(() => AppHaptics.setEnabled(true));

  testWidgets('fullBleed art keeps tap recognizers and fades at 56% height', (
    tester,
  ) async {
    _setPhone(tester);
    final service = _FakePlayerService();
    await tester.pumpWidget(
      _host(
        AlbumArtBox(
          song: _song,
          playerService: service,
          initialVinyl: true,
          fullBleed: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detector = tester.widget<RawGestureDetector>(
      find.byType(RawGestureDetector),
    );
    expect(detector.gestures.containsKey(DoubleTapGestureRecognizer), isTrue);
    expect(detector.gestures.containsKey(TapGestureRecognizer), isTrue);
    expect(detector.gestures.length, 2);

    final box = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(RawGestureDetector),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(box.width, 800);
    expect(box.height, closeTo(896.0, 0.01));

    await tester.tap(find.byType(RawGestureDetector));
    await tester.pumpAndSettle();
    final rotated = tester.widget<RawGestureDetector>(
      find.byType(RawGestureDetector),
    );
    expect(rotated.gestures.length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive stages expose exactly one active Hero tag', (
    tester,
  ) async {
    _setPhone(tester);
    final service = _FakePlayerService();
    const tag = 'song_art_phase2-song';

    final cases = <(PlayerScreenMode, bool, bool)>[
      (PlayerScreenMode.immersive, false, false),
      (PlayerScreenMode.immersive, true, true),
      (PlayerScreenMode.artworkCard, false, false),
    ];

    for (final entry in cases) {
      final (mode, fullView, expectFullBleed) = entry;
      await tester.pumpWidget(
        _host(
          _stage(
            playerService: service,
            mode: mode,
            fullView: fullView,
            heroTag: tag,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((widget) => widget is Hero && widget.tag == tag),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AlbumArtBox &&
              widget.fullBleed == expectFullBleed,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('peek stage without heroTag does not invent a Hero', (
    tester,
  ) async {
    _setPhone(tester);
    final service = _FakePlayerService();
    await tester.pumpWidget(
      _host(
        _stage(
          playerService: service,
          mode: PlayerScreenMode.immersive,
          fullView: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Hero), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metadata badges use only real song data', (tester) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _host(
        ImmersiveMetadataRow(
          song: _song,
          onNavigateToArtistDetail: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FLAC'), findsOneWidget);
    expect(find.text('24-bit/96kHz'), findsOneWidget);

    const sparse = Song(
      id: 'sparse',
      title: 'No Metadata',
      artist: 'Unknown',
      duration: Duration(minutes: 1),
      fileType: '',
    );
    await tester.pumpWidget(
      _host(
        ImmersiveMetadataRow(
          song: sparse,
          onNavigateToArtistDetail: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FLAC'), findsNothing);
    expect(find.text('24-bit/96kHz'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
