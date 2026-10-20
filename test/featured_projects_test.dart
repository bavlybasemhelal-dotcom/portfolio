import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/auth/admin_session.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/data/featured_projects_repository.dart';
import 'package:yogen_portfolio/data/project_repository.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'package:yogen_portfolio/domain/project.dart';
import 'package:yogen_portfolio/features/admin/admin_providers.dart';
import 'package:yogen_portfolio/features/public/home_page.dart';
import 'media_repository_test.dart' show MemoryStore;
import 'public_website_test.dart' show boot;
import 'support/public_fixtures.dart';

class FeaturedEditorFixture extends AdminSession {
  @override
  Future<AdminAccess> build() async =>
      const AdminAccess(uid: 'fixture', role: 'editor', enabled: true);
}

void main() {
  test(
    'Only published selected projects enter the showcase in catalogue order',
    () {
      final projects = List.generate(4, publicFixture);
      final content = PublicContent(
        projects: projects,
        featuredProjectIds: {'fixture-3', 'fixture-1', 'unpublished'},
      );
      expect(content.featuredProjects.map((p) => p.id), [
        'fixture-1',
        'fixture-3',
      ]);
      expect(content.projects, hasLength(4));
      expect(PublicContent(projects: projects).featuredProjects, isEmpty);
    },
  );

  test(
    'Selection persists separately and stale edits cannot overwrite it',
    () async {
      final store = MemoryStore();
      store.docs['sites/yogen/projects/project-a'] = {'projectId': 'project-a'};
      final repo = FeaturedProjectsRepository(store, actor: 'editor');
      await repo.select('project-a', true, expectedSelected: false);
      expect(await repo.selectedIds(), {'project-a'});
      await expectLater(
        repo.select('project-a', false, expectedSelected: false),
        throwsA(isA<ContentFailure>()),
      );
      await expectLater(
        repo.select('private-draft', true, expectedSelected: false),
        throwsA(isA<ContentFailure>()),
      );
      expect(await repo.selectedIds(), {'project-a'});
      await repo.select('project-a', false, expectedSelected: true);
      expect(await repo.selectedIds(), isEmpty);
      expect(store.docs.containsKey('sites/yogen/projects/project-a'), true);
    },
  );

  test(
    'Unpublishing and archiving clear featured status without deleting drafts',
    () async {
      for (final archive in [false, true]) {
        final store = MemoryStore();
        final repo = ProjectRepository(store, actor: 'editor');
        final content = publicFixture(0).content;
        await repo.saveDraft('fixture-0', content, expectedRevision: 0);
        store.docs['sites/yogen/projectDrafts/fixture-0']!.addAll({
          'status': 'published',
          'revision': 2,
          'publishedRevision': 2,
          'stableSlug': content.slug,
        });
        store.docs['sites/yogen/projects/fixture-0'] = {
          'projectId': 'fixture-0',
          'content': content.toMap(),
        };
        store.docs['sites/yogen/featuredProjects/fixture-0'] = {
          'projectId': 'fixture-0',
        };
        if (archive) {
          await repo.archive('fixture-0', expectedRevision: 2);
        } else {
          await repo.unpublish('fixture-0', expectedRevision: 2);
        }
        expect(
          store.docs.containsKey('sites/yogen/featuredProjects/fixture-0'),
          false,
        );
        expect(
          store.docs.containsKey('sites/yogen/projectDrafts/fixture-0'),
          true,
        );
      }
    },
  );

  testWidgets(
    'Homepage scroll shows selected work and its button opens all work',
    (t) async {
      final repo = FixturePublicRepository();
      repo.value = PublicContent(
        projects: repo.value.projects,
        featuredProjectIds: {'fixture-1'},
        endpoint: repo.value.endpoint,
      );
      final container = await boot(t, repo: repo);
      final scroll = t
          .widget<CustomScrollView>(
            find.byKey(const PageStorageKey('home-scroll')),
          )
          .controller!;
      const geometry = StoryGeometry(820, true, 1);
      scroll.jumpTo(geometry.heroExtent);
      await t.pumpAndSettle();
      final stage = t.widget<ProjectStage>(find.byType(ProjectStage));
      expect(stage.project.id, 'fixture-1');
      expect(stage.count, 1);
      final all = find.byKey(const ValueKey('home-all-projects'));
      await t.ensureVisible(all);
      await t.pumpAndSettle();
      await t.tap(all);
      await t.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/work',
      );
      expect(find.text('3 projects'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('No selection never falls back to showcasing every project', (
    t,
  ) async {
    final repo = FixturePublicRepository();
    repo.value = PublicContent(projects: repo.value.projects);
    await boot(t, repo: repo, reduced: true);
    expect(find.byType(ProjectStage), findsNothing);
    final all = find.byKey(const ValueKey('home-all-projects'));
    await t.ensureVisible(all);
    await t.pumpAndSettle();
    expect(all, findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  for (final language in ['ar', 'en']) {
    testWidgets(
      'Admin saves and removes featured choices on a phone ($language)',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'language': language,
          'motionPaused': true,
          'motionReduced': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final store = MemoryStore();
        final repo = FixturePublicRepository();
        for (final project in repo.value.projects) {
          store.docs['sites/yogen/projects/${project.id}'] = {
            'projectId': project.id,
          };
        }
        final selection = FeaturedProjectsRepository(store, actor: 'fixture');
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              initialLocationProvider.overrideWithValue(
                '/admin/featured-projects',
              ),
              preferencesStorageProvider.overrideWithValue(prefs),
              adminSessionProvider.overrideWith(FeaturedEditorFixture.new),
              publicRepositoryProvider.overrideWithValue(repo),
              featuredProjectsRepositoryProvider.overrideWith(
                (ref) async => selection,
              ),
            ],
            child: const YogenApp(),
          ),
        );
        await t.pumpAndSettle();
        final check = find.byKey(const ValueKey('featured-fixture-1'));
        await t.ensureVisible(check);
        await t.tap(check);
        await t.pumpAndSettle();
        expect(await selection.selectedIds(), {'fixture-1'});
        expect(t.widget<CheckboxListTile>(check).value, true);
        await t.tap(check);
        await t.pumpAndSettle();
        expect(await selection.selectedIds(), isEmpty);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
