import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/features/player/widgets/song_stage_carousel.dart';
import 'package:auno_player/models/song.dart';

const _current = Song(
  id: 'artwork-a',
  title: 'A',
  artist: 'Auno Tests',
  duration: Duration(minutes: 1),
  fileType: 'FLAC',
);

const _next = Song(
  id: 'artwork-b',
  title: 'B',
  artist: 'Auno Tests',
  duration: Duration(minutes: 1),
  fileType: 'FLAC',
);

const _previous = Song(
  id: 'artwork-c',
  title: 'C',
  artist: 'Auno Tests',
  duration: Duration(minutes: 1),
  fileType: 'FLAC',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('artwork carousel swipe still changes song inside the page host', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    var nextCount = 0;
    var previousCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 80, child: Text('chrome')),
              Expanded(
                child: PageView(
                  controller: controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SongStageCarousel(
                      currentSong: _current,
                      nextSong: _next,
                      prevSong: _previous,
                      stageBuilder: (song) => Center(child: Text(song.id)),
                      onNext: () async {
                        nextCount++;
                      },
                      onPrevious: () async {
                        previousCount++;
                      },
                    ),
                    const SizedBox.expand(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.text('artwork-a'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(nextCount, 1);
    expect(previousCount, 0);
    expect(controller.page, 0.0);
    expect(tester.takeException(), isNull);
  });
}
