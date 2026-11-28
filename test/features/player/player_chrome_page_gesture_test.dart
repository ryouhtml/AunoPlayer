import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/features/player/widgets/player_chrome_page_gesture.dart';

Widget _host({
  required Widget child,
  bool pageSwipeEnabled = true,
  GlobalKey? queueRegionKey,
  VoidCallback? onSwipeLeft,
  VoidCallback? onSwipeRight,
  VoidCallback? onQueueDrag,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PlayerChromePageGesture(
        pageSwipeEnabled: pageSwipeEnabled,
        queueDragRegionKey: queueRegionKey,
        onSwipeLeft: onSwipeLeft,
        onSwipeRight: onSwipeRight,
        onQueueDrag: onQueueDrag,
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chrome flings page left and right', (tester) async {
    var left = 0;
    var right = 0;

    await tester.pumpWidget(
      _host(
        child: const Center(child: Text('chrome')),
        onSwipeLeft: () => left++,
        onSwipeRight: () => right++,
      ),
    );

    await tester.fling(find.text('chrome'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(left, 1);
    expect(right, 0);

    await tester.fling(find.text('chrome'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(left, 1);
    expect(right, 1);
  });

  testWidgets('vertical and slow horizontal chrome drags do not page', (
    tester,
  ) async {
    var left = 0;
    var right = 0;

    await tester.pumpWidget(
      _host(
        child: const Center(child: Text('chrome')),
        onSwipeLeft: () => left++,
        onSwipeRight: () => right++,
      ),
    );

    await tester.fling(find.text('chrome'), const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    expect(left, 0);
    expect(right, 0);

    final center = tester.getCenter(find.text('chrome'));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(left, 0);
    expect(right, 0);
  });

  testWidgets('disabled page swipe still keeps legacy queue drag', (
    tester,
  ) async {
    final queueRegionKey = GlobalKey();
    var left = 0;
    var queueDrags = 0;

    await tester.pumpWidget(
      _host(
        pageSwipeEnabled: false,
        queueRegionKey: queueRegionKey,
        onSwipeLeft: () => left++,
        onQueueDrag: () => queueDrags++,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: queueRegionKey,
                width: 160,
                height: 80,
                alignment: Alignment.center,
                child: const Text('queue chip'),
              ),
              const SizedBox(width: 160),
              const Text('chrome'),
            ],
          ),
        ),
      ),
    );

    await tester.fling(find.text('queue chip'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(queueDrags, 1);
    expect(left, 0);

    await tester.fling(find.text('chrome'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(queueDrags, 1);
    expect(left, 0);
  });
}
