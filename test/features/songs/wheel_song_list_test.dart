import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auno_player/features/songs/widgets/orbit_scroll.dart';
import 'package:auno_player/features/songs/widgets/song_card.dart';
import 'package:auno_player/features/songs/widgets/wheel_song_list.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/models/song.dart';

final _songs = List.generate(
  12,
  (i) => Song(
    id: 'wheel-$i',
    title: 'Wheel Song $i',
    artist: 'Artist $i',
    duration: const Duration(minutes: 3),
    fileType: 'FLAC',
  ),
);

void main() {
  void setView(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> pumpWheel(
    WidgetTester tester, {
    OrbitScrollController? controller,
    int selected = 1,
    List<int>? tapped,
    List<int>? indexChanges,
    bool? reduceMotion,
    bool disableAnimations = false,
    bool isSelectionMode = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kFallbackLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: const Size(411, 900),
              disableAnimations: disableAnimations,
            ),
            child: SizedBox.expand(
              child: WheelSongList(
                songs: _songs,
                selectedIndex: selected,
                controller: controller,
                reduceMotion: reduceMotion,
                isSelectionMode: isSelectionMode,
                selectedIds: isSelectionMode ? {'wheel-1'} : const {},
                scrollDirection: Axis.vertical,
                showPath: false,
                showGlow: false,
                onSongSelected: (index) => tapped?.add(index),
                onSelectedIndexChanged: (index) => indexChanges?.add(index),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wheel list installs the distance curves and 3D transform', (
    tester,
  ) async {
    setView(tester);
    final tapped = <int>[];
    await pumpWheel(tester, tapped: tapped);

    final orbit = tester.widget<OrbitScroll>(find.byType(OrbitScroll));
    expect(orbit.scaleForDistance, isNotNull);
    expect(orbit.scaleForDistance!(0), closeTo(1.04, 1e-6));
    expect(orbit.scaleForDistance!(2), closeTo(0.90, 1e-6));
    expect(orbit.opacityForDistance, isNotNull);
    expect(orbit.opacityForDistance!(1), closeTo(0.85, 1e-6));

    final matrix = orbit.itemTransform!(1);
    expect(matrix, isNotNull);
    expect(matrix!.storage.every((value) => value.isFinite), isTrue);
    expect(matrix.storage, isNot(orderedEquals(Matrix4.identity().storage)));

    final selected = tester.widget<SongCard>(
      find.byWidgetPredicate((widget) => widget is SongCard && widget.isSelected),
    );
    expect(selected.song.id, 'wheel-1');
    expect(selected.scale, closeTo(1.04, 1e-6));
    expect(selected.opacity, closeTo(1.0, 1e-6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap forwards a play callback with meaningful semantics', (
    tester,
  ) async {
    setView(tester);
    final tapped = <int>[];
    await pumpWheel(tester, tapped: tapped);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is SongCard && widget.isSelected,
      ),
    );
    await tester.pumpAndSettle();

    expect(tapped, [1]);
    expect(
      find.bySemanticsLabel(RegExp('Wheel Song 1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection mode keeps its state and does not swipe', (
    tester,
  ) async {
    setView(tester);
    final tapped = <int>[];
    await pumpWheel(tester, tapped: tapped, isSelectionMode: true);

    final orbit = tester.widget<OrbitScroll>(find.byType(OrbitScroll));
    expect(orbit.isSelectionMode, isTrue);
    expect(orbit.swipeActionsEnabled, isFalse);
    expect(orbit.selectedIds, contains('wheel-1'));

    final selected = tester.widget<SongCard>(
      find.byWidgetPredicate((widget) => widget is SongCard && widget.isSelected),
    );
    expect(selected.isSelectionMode, isTrue);
    expect(selected.isMultiSelected, isTrue);
    expect(selected.onSwipeLeft, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fling snaps and controller jumps survive the wheel transform', (
    tester,
  ) async {
    setView(tester);
    final controller = OrbitScrollController();
    final changes = <int>[];
    await pumpWheel(tester, controller: controller, indexChanges: changes);

    final card = find.byWidgetPredicate(
      (widget) => widget is SongCard && widget.isSelected,
    );
    await tester.flingFrom(tester.getCenter(card), const Offset(0, -180), 600);
    await tester.pumpAndSettle();

    expect(changes, isNotEmpty);
    expect(changes.last, greaterThan(1));

    controller.jumpToIndex(4, animate: false);
    await tester.pump();
    expect(changes.last, 4);

    final selected = tester.widget<SongCard>(
      find.byWidgetPredicate((widget) => widget is SongCard && widget.isSelected),
    );
    expect(selected.song.id, 'wheel-4');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion removes 3D rotation but keeps the curves', (
    tester,
  ) async {
    setView(tester);
    await pumpWheel(tester, reduceMotion: true);

    var orbit = tester.widget<OrbitScroll>(find.byType(OrbitScroll));
    expect(orbit.itemTransform!(-2)!.storage,
        orderedEquals(Matrix4.identity().storage));
    expect(orbit.scaleForDistance!(0), closeTo(1.04, 1e-6));

    await pumpWheel(tester, disableAnimations: true);
    orbit = tester.widget<OrbitScroll>(find.byType(OrbitScroll));
    expect(orbit.itemTransform!(2)!.storage,
        orderedEquals(Matrix4.identity().storage));
    expect(tester.takeException(), isNull);
  });
}
