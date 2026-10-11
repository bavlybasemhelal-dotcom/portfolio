import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'package:yogen_portfolio/features/media/media_transport.dart';
import 'package:yogen_portfolio/features/public/home_page.dart';
import 'package:yogen_portfolio/features/public/project_widgets.dart';
import 'package:yogen_portfolio/features/validation/scene_page.dart';
import 'support/public_fixtures.dart';

Future<ProviderContainer> boot(
  WidgetTester t, {
  required FixturePublicRepository repo,
  String path = '/',
  Size size = const Size(1440, 900),
  String language = 'en',
  String theme = 'dark',
  bool reduced = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'theme': theme,
    'language': language,
    'motionPaused': true,
    'motionReduced': reduced,
  });
  final storage = await SharedPreferences.getInstance();
  final overrides = [
    initialLocationProvider.overrideWithValue(path),
    preferencesStorageProvider.overrideWithValue(storage),
    publicRepositoryProvider.overrideWithValue(repo),
    publicMediaCacheProvider.overrideWithValue(
      MediaByteCache(FixtureMediaTransport()),
    ),
  ];
  for (final entry in {
    'PlexSans': 'assets/fonts/ibmplexsans/IBMPlexSans[wdth,wght].ttf',
    'PlexArabic':
        'assets/fonts/ibmplexsansarabic/IBMPlexSansArabic-Regular.ttf',
  }.entries) {
    final font = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await font.load();
  }
  await t.pumpWidget(
    ProviderScope(overrides: overrides, child: const YogenApp()),
  );
  final container = ProviderScope.containerOf(t.element(find.byType(YogenApp)));
  container.read(routerProvider).go(path);
  await t.pumpAndSettle();
  return container;
}

void main() {
  test(
    'Story geometry makes a full turn and advances/exits for arbitrary project counts',
    () {
      const g = StoryGeometry(560, true, 38);
      expect(g.turn(g.heroTravel), 1);
      expect(g.selected(240), 1);
      expect(g.selected(g.stageTravel), 37);
      expect(g.selected(g.stageTravel + 900), 37);
      expect(const StoryGeometry(500, false, 0).turn(100), 0);
    },
  );
  testWidgets(
    'P06-T03/T04 filters and detail context survive locale switching and browser back',
    (t) async {
      final container = await boot(
        t,
        repo: FixturePublicRepository(),
        path: Uri(
          path: '/work',
          queryParameters: {
            'lang': 'en',
            'filters': jsonEncode(['tag:web', 'tag:applications']),
          },
        ).toString(),
      );
      expect(find.byKey(const ValueKey('work-count')), findsOneWidget);
      expect(find.text('3 projects'), findsOneWidget);
      final cards = find.byType(ProjectCard);
      expect(cards, findsNWidgets(3));
      await t.ensureVisible(cards.first);
      await t.pumpAndSettle();
      final semantics = t.ensureSemantics();
      expect(
        find.bySemanticsLabel('Explore project: Test project 0'),
        findsOneWidget,
      );
      semantics.dispose();
      await t.tap(cards.first);
      await t.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.path,
        '/projects/fixture-0',
      );
      await t.tap(find.byKey(const ValueKey('language')));
      await t.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.path,
        '/projects/fixture-0',
      );
      container.read(routerProvider).pop();
      await t.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.queryParameters['filters'],
        contains('tag:web'),
      );
      expect(find.text('3 projects'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'P06-T05 empty/error/retry and unpublished direct link reveal no draft',
    (t) async {
      final repo = FixturePublicRepository(count: 0);
      final container = await boot(t, repo: repo, path: '/work');
      expect(find.text('No published projects yet'), findsOneWidget);
      repo.fail = true;
      await container.read(publicContentProvider.notifier).refresh();
      await t.pumpAndSettle();
      expect(find.text('Content unavailable'), findsOneWidget);
      repo.fail = false;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('No published projects yet'), findsOneWidget);
      container.read(routerProvider).go('/projects/private-id');
      await t.pumpAndSettle();
      expect(find.text('Project unavailable'), findsOneWidget);
    },
  );
  testWidgets('P06-T05 first-load failure is visible and Retry recovers', (
    t,
  ) async {
    final repo = FixturePublicRepository(count: 0)..fail = true;
    await boot(t, repo: repo, path: '/work');
    expect(find.text('Content unavailable'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    repo.fail = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('No published projects yet'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('P06-T06/T10 image next/Escape returns focus to opener', (
    t,
  ) async {
    await boot(t, repo: FixturePublicRepository(), path: '/projects/fixture-0');
    final button = find.byKey(const ValueKey('zoom-image-0'));
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.byType(GalleryDialog), findsOneWidget);
    await t.tap(find.text('Next image'));
    await t.pumpAndSettle();
    expect(find.textContaining('2 / 2'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(GalleryDialog), findsNothing);
    expect(t.widget<OutlinedButton>(button).focusNode!.hasFocus, true);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'P06-T08 contact project and entered fields survive locale changes',
    (t) async {
      final container = await boot(
        t,
        repo: FixturePublicRepository(),
        path: '/contact?lang=en&project=fixture-0&nameAr=تجربة&nameEn=Fixture',
      );
      final name = find.widgetWithText(TextField, 'Your name');
      await t.ensureVisible(name);
      await t.enterText(name, 'My name');
      await t.tap(find.byKey(const ValueKey('language')));
      await t.pumpAndSettle();
      expect(find.text('My name'), findsOneWidget);
      expect(
        container.read(routerProvider).state.uri.queryParameters['project'],
        'fixture-0',
      );
      expect(find.textContaining('مشروع اختبار 0'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Compact sticky showcase follows page scroll in both directions and resize preserves selection',
    (t) async {
      await boot(
        t,
        repo: FixturePublicRepository(),
        size: const Size(1366, 657),
      );
      final scroll = t
          .widget<CustomScrollView>(
            find.byKey(const PageStorageKey('home-scroll')),
          )
          .controller!;
      final height = 657 - 86.0;
      final g = StoryGeometry(height, true, 3);
      scroll.jumpTo(g.heroTravel);
      await t.pumpAndSettle();
      final painter =
          t
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('public-identity-scene')).first,
                  )
                  .painter!
              as IdentityPainter;
      expect(painter.angle, closeTo(6.283185307179586 - .18, .001));
      scroll.jumpTo(g.heroExtent + 240);
      await t.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      scroll.jumpTo(g.heroExtent + 480);
      await t.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      t.view.physicalSize = const Size(1440, 800);
      await t.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await t.tap(find.byTooltip('Previous project'));
      await t.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(360, 850),
    const Size(768, 900),
    const Size(1440, 900),
  ]) {
    for (final lang in ['ar', 'en']) {
      for (final theme in ['light', 'dark']) {
        testWidgets('P06-T09 all routes $size $lang $theme', (t) async {
          final container = await boot(
            t,
            repo: FixturePublicRepository(),
            size: size,
            language: lang,
            theme: theme,
          );
          for (final path in [
            '/',
            '/work',
            '/projects/fixture-0',
            '/services',
            '/about',
            '/contact',
          ]) {
            container.read(routerProvider).go('$path?lang=$lang');
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: path);
            final scrolls = find.byType(Scrollable);
            for (final element in scrolls.evaluate()) {
              final state =
                  (element as StatefulElement).state as ScrollableState;
              if (state.position.axis == Axis.vertical) {
                state.position.jumpTo(state.position.maxScrollExtent);
              }
            }
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: '$path bottom');
          }
        });
      }
    }
  }
}
