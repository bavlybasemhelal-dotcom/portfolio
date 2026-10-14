import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'package:yogen_portfolio/features/media/media_preview.dart';
import 'package:yogen_portfolio/features/media/media_transport.dart';
import 'package:yogen_portfolio/features/public/depth_scene.dart';
import 'package:yogen_portfolio/features/public/home_page.dart';
import 'package:yogen_portfolio/features/validation/scene_page.dart';
import 'public_website_test.dart' show boot;
import 'support/public_fixtures.dart';

void main() {
  testWidgets(
    'P09-T09 offscreen gallery defers reads and retains image extent',
    (t) async {
      t.view.physicalSize = const Size(400, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final transport = FixtureMediaTransport();
      final cache = MediaByteCache(transport);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: List.generate(
                30,
                (i) => DriveImage(
                  key: ValueKey('image-$i'),
                  cache: cache,
                  endpoint: 'fixture',
                  site: 'test',
                  assetId: 'image-$i',
                  alt: 'Image $i',
                  height: 180,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(transport.requested.length, inInclusiveRange(3, 4));
      expect(transport.requested, isNot(contains('image-29')));
      expect(t.getSize(find.byKey(const ValueKey('image-0'))).height, 180);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pumpAndSettle();
      expect(transport.requested, contains('image-29'));
      expect(transport.requested.length, lessThan(10));
      final count = transport.requested.length;
      scroll.jumpTo(0);
      await t.pumpAndSettle();
      expect(transport.requested.length, count);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'P09-T02/T04 depth freezes exactly on pause, hidden, offscreen and OS reduced motion',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await SharedPreferences.getInstance();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await t.pumpWidget(
        ProviderScope(
          overrides: [preferencesStorageProvider.overrideWithValue(storage)],
          child: MaterialApp(
            home: SingleChildScrollView(
              controller: scroll,
              child: const Column(
                children: [
                  SizedBox(height: 350, child: DepthScene()),
                  SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        t.element(find.byType(DepthScene)),
      );
      IdentityPainter painter() =>
          t
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('public-identity-scene')),
                  )
                  .painter!
              as IdentityPainter;
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(seconds: 2));
      final before = painter().angle;
      container.read(preferencesProvider.notifier).pause();
      await t.pump();
      expect(painter().angle, before);
      await t.pump(const Duration(seconds: 4));
      expect(painter().angle, before);
      container.read(preferencesProvider.notifier).pause();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(painter().angle, isNot(before));
      scroll.jumpTo(700);
      await t.pump();
      await t.pump();
      final outside = painter().angle;
      await t.pump(const Duration(seconds: 3));
      expect(painter().angle, outside);
      scroll.jumpTo(0);
      await t.pump();
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      final clock =
          t
                  .widget<AnimatedBuilder>(
                    find
                        .descendant(
                          of: find.byType(DepthScene),
                          matching: find.byType(AnimatedBuilder),
                        )
                        .first,
                  )
                  .animation
              as AnimationController;
      expect(
        clock.isAnimating,
        false,
        reason: 'Stop even before a hidden tab can render another frame',
      );
      await t.pump();
      final hidden = painter().angle;
      await t.pump(const Duration(seconds: 3));
      expect(painter().angle, hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(seconds: 2));
      expect(painter().angle, isNot(hidden));
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(painter().fallback, true);
      expect(painter().angle, -.18);
      t.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'P09-T01/T03 rapid transitions and locale leave a usable final page',
    (t) async {
      final c = await boot(
        t,
        repo: FixturePublicRepository(count: 38),
        path: '/work',
      );
      c.read(preferencesProvider.notifier).pause();
      final router = c.read(routerProvider);
      for (final path in [
        '/projects/fixture-0',
        '/work',
        '/projects/fixture-1',
        '/about',
        '/',
        '/contact',
      ]) {
        router.go('$path?lang=en');
        await t.pump(const Duration(milliseconds: 60));
        await c.read(preferencesProvider.notifier).language();
        await t.pump(const Duration(milliseconds: 50));
        expect(t.takeException(), isNull, reason: path);
      }
      c.read(preferencesProvider.notifier).reduce();
      await t.pumpAndSettle();
      expect(router.state.uri.path, '/contact');
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'P09-T04 long sticky gallery exits and OS reduction preserves access',
    (t) async {
      await boot(t, repo: FixturePublicRepository(count: 38));
      final scroll = t
          .widget<CustomScrollView>(
            find.byKey(const PageStorageKey('home-scroll')),
          )
          .controller!;
      const geometry = StoryGeometry(814, true, 38);
      for (final index in [0, 1, 17, 37, 9]) {
        scroll.jumpTo(geometry.heroExtent + index * 240);
        await t.pumpAndSettle();
        expect(find.text('${index + 1} / 38'), findsOneWidget);
        expect(t.takeException(), isNull);
      }
      await t.tap(find.text('Skip showcase'));
      await t.pumpAndSettle();
      expect(
        scroll.offset,
        greaterThan(geometry.heroExtent + geometry.stageTravel),
      );
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await t.pumpAndSettle();
      expect(find.byType(ProjectStage), findsNothing);
      t.platformDispatcher.clearAccessibilityFeaturesTestValue();
    },
  );

  for (final size in [const Size(360, 850), const Size(768, 900)]) {
    testWidgets(
      'P09 touch story $size follows scroll, cycles projects and exits',
      (t) async {
        final c = await boot(
          t,
          repo: FixturePublicRepository(count: 38),
          size: size,
        );
        IdentityPainter painter() =>
            t
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('public-identity-scene')).first,
                    )
                    .painter!
                as IdentityPainter;
        final scroll = t
            .widget<CustomScrollView>(
              find.byKey(const PageStorageKey('home-scroll')),
            )
            .controller!;
        final geometry = StoryGeometry(
          t.getSize(find.byType(HomePage)).height,
          true,
          38,
        );
        final initial = painter().angle;
        scroll.jumpTo(geometry.heroTravel / 4);
        await t.pumpAndSettle();
        expect(painter().angle, closeTo(initial + 1.5707963268, .0001));
        scroll.jumpTo(geometry.heroTravel);
        await t.pumpAndSettle();
        expect(painter().angle, closeTo(initial + 6.2831853072, .0001));
        scroll.jumpTo(0);
        await t.pumpAndSettle();
        expect(painter().angle, initial);
        c.read(preferencesProvider.notifier).pause();
        await t.pump();
        await t.pump(const Duration(milliseconds: 16));
        final first = painter().angle;
        await t.pump(const Duration(seconds: 4));
        expect(painter().angle - first, inExclusiveRange(.2, .45));
        c.read(preferencesProvider.notifier).pause();
        await t.pump();
        final stopped = painter().angle;
        await t.pump(const Duration(seconds: 4));
        expect(painter().angle, stopped);
        for (final index in [0, 1, 17, 37, 9]) {
          scroll.jumpTo(geometry.heroExtent + index * 240);
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('mobile-stage-selector')),
            findsOneWidget,
          );
          expect(find.text('${index + 1} / 38'), findsOneWidget);
          expect(t.takeException(), isNull);
        }
        await t.tap(find.byTooltip('Next project'));
        await t.pumpAndSettle();
        expect(find.text('11 / 38'), findsOneWidget);
        await t.tap(find.text('Skip showcase'));
        await t.pumpAndSettle();
        expect(
          scroll.offset,
          greaterThan(geometry.heroExtent + geometry.stageTravel),
        );
        scroll.jumpTo(0);
        await t.pumpAndSettle();
        t.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await t.pump();
        expect(painter().fallback, true);
        expect(painter().angle, -.18);
        expect(find.byType(ProjectStage), findsNothing);
        t.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'P09 miniature previews cycle every published project and pause outside view',
    (t) async {
      SharedPreferences.setMockInitialValues({'motionPaused': true});
      final storage = await SharedPreferences.getInstance();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStorageProvider.overrideWithValue(storage),
            publicMediaCacheProvider.overrideWithValue(
              MediaByteCache(FixtureMediaTransport()),
            ),
          ],
          child: MaterialApp(
            home: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  HeroProjectOrbit(
                    projects: List.generate(3, publicFixture),
                    endpoint: 'fixture',
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final c = ProviderScope.containerOf(
        t.element(find.byType(HeroProjectOrbit)),
      );
      Text counter() =>
          t.widget<Text>(find.byKey(const ValueKey('hero-orbit-index')));
      expect(counter().data, '1 · 3');
      c.read(preferencesProvider.notifier).pause();
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      for (final expected in ['2 · 3', '3 · 3', '1 · 3']) {
        await t.pump(const Duration(seconds: 7));
        await t.pump();
        expect(counter().data, expected);
      }
      c.read(preferencesProvider.notifier).pause();
      await t.pump();
      await t.pump(const Duration(seconds: 7));
      expect(counter().data, '1 · 3');
      c.read(preferencesProvider.notifier).pause();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pump();
      await t.pump();
      await t.pump(const Duration(seconds: 7));
      expect(counter().data, '1 · 3');
      scroll.jumpTo(0);
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(seconds: 7));
      await t.pump();
      expect(counter().data, '2 · 3');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await t.pump();
      await t.pump(const Duration(seconds: 7));
      expect(counter().data, '2 · 3');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(seconds: 7));
      await t.pump();
      expect(counter().data, '3 · 3');
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'P09-T06 contrast uses actual Flutter themes and gradient surfaces',
    (t) async {
      final report = <Map<String, Object>>[];
      for (final mode in ['light', 'dark']) {
        await boot(t, repo: FixturePublicRepository(), theme: mode);
        final scheme = Theme.of(t.element(find.byType(HomePage))).colorScheme;
        final surfaces = [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainerHighest,
          ...(mode == 'dark'
              ? const [Color(0xff0b2035), Color(0xff081120), Color(0xff211a36)]
              : const [
                  Color(0xffe5f2ff),
                  Color(0xfff7f9fd),
                  Color(0xffefe8ff),
                ]),
        ];
        double ratio(Color a, Color b) {
          final x = a.computeLuminance(), y = b.computeLuminance();
          return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
        }

        for (final fg in {
          'body': scheme.onSurface,
          'secondary': scheme.onSurfaceVariant,
          'link': scheme.primary,
          'eyebrow': scheme.tertiary,
        }.entries) {
          for (var i = 0; i < surfaces.length; i++) {
            final value = ratio(fg.value, surfaces[i]);
            report.add({
              'mode': mode,
              'text': fg.key,
              'surface': i,
              'ratio': value,
            });
            expect(
              value,
              greaterThanOrEqualTo(4.5),
              reason: '$mode ${fg.key} surface $i',
            );
          }
        }
        expect(ratio(scheme.error, scheme.surface), greaterThanOrEqualTo(4.5));
        expect(
          ratio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(ratio(scheme.primary, scheme.surface), greaterThanOrEqualTo(3));
      }
      File(
        'phases/results/09/checks/contrast.json',
      ).writeAsStringSync(jsonEncode(report));
    },
  );
}
