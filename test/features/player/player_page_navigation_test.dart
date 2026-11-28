import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/features/player/widgets/player_chrome_page_gesture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chrome swipe switches between now playing and queue pages', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);

    Future<void> goToPage(int page) {
      return controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PlayerChromePageGesture(
                onSwipeLeft: () => unawaited(goToPage(1)),
                onSwipeRight: () => unawaited(goToPage(0)),
                child: const SizedBox(
                  height: 80,
                  child: Center(child: Text('chrome')),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    Center(child: Text('now playing slot')),
                    Center(child: Text('queue slot')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('now playing slot'), findsOneWidget);
    expect(controller.page, 0.0);

    await tester.fling(find.text('chrome'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 1.0);
    expect(find.text('queue slot'), findsOneWidget);

    await tester.fling(find.text('chrome'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 0.0);
    expect(find.text('now playing slot'), findsOneWidget);
  });
}
