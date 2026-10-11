import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'support/public_fixtures.dart';
import 'package:yogen_portfolio/features/validation/scene_page.dart';

Future<void> boot(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'theme': 'light'});
  final storage = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialLocationProvider.overrideWithValue('/validation/foundation'),
        preferencesStorageProvider.overrideWithValue(storage),
        publicRepositoryProvider.overrideWithValue(
          FixturePublicRepository(count: 0),
        ),
      ],
      child: const YogenApp(),
    ),
  );
  ProviderScope.containerOf(
    tester.element(find.byType(YogenApp)),
  ).read(routerProvider).go('/validation/foundation');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Arabic/English, theme and persistent settings', (tester) async {
    await boot(tester);
    expect(find.text('أساس واحد. تجارب واضحة.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language')));
    await tester.pumpAndSettle();
    expect(find.text('One foundation. Measurable checks.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(FoundationPage))).brightness,
      Brightness.dark,
    );
    final storage = await SharedPreferences.getInstance();
    expect(storage.getString('language'), 'en');
    expect(storage.getString('theme'), 'dark');
  });
  for (final size in [
    const Size(360, 640),
    const Size(768, 900),
    const Size(1366, 657),
  ]) {
    testWidgets('Layout stays usable at $size', (tester) async {
      await boot(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('YOGEN'), findsOneWidget);
    });
  }
  testWidgets(
    'Native scene supports full rotation, pause, reduced motion and static fallback',
    (tester) async {
      await boot(tester);
      await tester.tap(find.text('تجربة 3D'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('rotation')),
      );
      slider.onChanged!(1);
      await tester.pump();
      expect(find.textContaining('360° / 360°'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pause')));
      await tester.pump();
      final before =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('native-scene')),
                  )
                  .painter
              as IdentityPainter;
      await tester.pump(const Duration(seconds: 1));
      final after =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('native-scene')),
                  )
                  .painter
              as IdentityPainter;
      expect(before.orbit, after.orbit);
      await tester.tap(find.text('تقليل الحركة'));
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('rotation'))).onChanged,
        isNull,
      );
      await tester.tap(find.text('البديل الثابت'));
      await tester.pump();
      expect(
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('native-scene')),
                    )
                    .painter
                as IdentityPainter)
            .fallback,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
