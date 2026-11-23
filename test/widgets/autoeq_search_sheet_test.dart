import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/core/theme/app_theme.dart';
import 'package:auno_player/features/settings/screens/widgets/autoeq_search_sheet.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/l10n/settings_l10n.dart';
import 'package:auno_player/services/autoeq_catalog_service.dart';

final _entry = AutoEqEntry.fromJson({
  'id': 'bundled-hd650',
  'b': 'Sennheiser',
  'm': 'HD 650',
  't': 'over-ear',
  's': 'oratory1990',
  'pa': -6.1,
  'g': [
    [205, -12.2, 0.18, 'PK'],
  ],
});

class _Catalog extends Fake implements AutoEqCatalogService {
  List<AutoEqSearchResult> searchResults = const [];

  @override
  Future<List<AutoEqEntry>> loadBundled() async => [_entry];

  @override
  Future<List<String>> loadBrands() async => ['Sennheiser'];

  @override
  List<AutoEqSearchResult> search(
    String query, {
    String? brand,
    int limit = 60,
  }) => searchResults;
}

Future<void> _open(
  WidgetTester tester,
  _Catalog service, {
  Size size = const Size(390, 844),
  double keyboardHeight = 0,
  double textScale = 1,
  void Function(AutoEqEntry?)? onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      locale: kFallbackLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kAppLocalizationsDelegates,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showAutoEqSearchSheet(
                context,
                service: service,
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder get _applyButton => find.byType(FilledButton);
Finder get _result => find.widgetWithText(ListTile, _entry.displayName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('bundled results can be selected and applied', (tester) async {
    final service = _Catalog()
      ..searchResults = [AutoEqSearchResult(_entry, 1000)];
    AutoEqEntry? applied;
    await _open(tester, service, onResult: (value) => applied = value);
    expect(_result, findsOneWidget);
    expect(tester.widget<FilledButton>(_applyButton).onPressed, isNotNull);
    await tester.tap(_applyButton);
    await tester.pumpAndSettle();
    expect(applied, same(_entry));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no match stays offline and cannot apply', (tester) async {
    await _open(tester, _Catalog());
    await tester.enterText(find.byType(TextField), 'Unknown Model');
    await tester.pumpAndSettle();
    expect(find.text(l10n.noMatchesTryFewerWordsOr), findsOneWidget);
    expect(tester.widget<FilledButton>(_applyButton).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [kFallbackLocale, const Locale('zh', 'CN')]) {
    testWidgets('picker and Apply stay above the keyboard ($locale)', (
      tester,
    ) async {
      final service = _Catalog()
        ..searchResults = [AutoEqSearchResult(_entry, 1000)];
      await _open(tester, service, keyboardHeight: 300);
      expect(tester.getRect(_applyButton).bottom, lessThanOrEqualTo(544));
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(891, 411), Size(1024, 800), Size(320, 800)]) {
    testWidgets('picker actions fit at $size', (tester) async {
      final service = _Catalog()
        ..searchResults = [AutoEqSearchResult(_entry, 1000)];
      await _open(
        tester,
        service,
        size: size,
        textScale: size.width == 320 ? 2 : 1,
      );
      expect(_result, findsOneWidget);
      expect(_applyButton, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
