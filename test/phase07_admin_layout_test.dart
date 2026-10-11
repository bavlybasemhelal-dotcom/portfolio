import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/auth/admin_session.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/data/admin_content_repository.dart';
import 'package:yogen_portfolio/data/company_repository.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/media_repository.dart';
import 'package:yogen_portfolio/domain/project.dart';
import 'package:yogen_portfolio/features/admin/admin_providers.dart';
import 'package:yogen_portfolio/features/admin/editor_session.dart';
import 'admin_access_widget_test.dart' show FixtureAuth;
import 'media_repository_test.dart' show MemoryStore, FixtureTransport;
import 'media_widgets_test.dart' show ManagerFixture;

class ManagementLayoutStore extends FirestoreRestStore {
  final MemoryStore source;
  ManagementLayoutStore(this.source)
    : super(projectId: 'fixture', token: () async => null);
  @override
  Future<StoredDocument?> get(String path) => source.get(path);
  @override
  Future<List<StoredDocument>> listAll(String path) =>
      source.list(path, limit: 100);
}

class RevocableManager extends ManagerFixture {
  void access(bool enabled) => state = AsyncData(
    AdminAccess(
      uid: 'fixture',
      loginName: 'manager',
      role: 'manager',
      enabled: enabled,
    ),
  );
}

void main() {
  testWidgets(
    'P07-T05 expired access retains unsaved form for same-account recovery',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'language': 'en',
        'motionPaused': true,
      });
      final prefs = await SharedPreferences.getInstance(),
          memory = MemoryStore();
      final admin = AdminContentRepository(memory, actor: 'fixture');
      await admin.projects.saveDraft(
        'expiry',
        const ProjectContent(title: LocalizedText(en: 'Server version')),
        expectedRevision: 0,
      );
      final store = ManagementLayoutStore(memory);
      final container = ProviderContainer(
        overrides: [
          preferencesStorageProvider.overrideWithValue(prefs),
          initialLocationProvider.overrideWithValue(
            '/admin/projects/expiry/edit',
          ),
          adminSessionProvider.overrideWith(RevocableManager.new),
          accountAuthProvider.overrideWith((ref) async => FixtureAuth()),
          documentStoreProvider.overrideWith((ref) async => store),
          adminContentRepositoryProvider.overrideWith((ref) async => admin),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(store.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const YogenApp(),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Project title · EN',
      );
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Unsaved retained edit');
      await tester.pump();
      (container.read(adminSessionProvider.notifier) as RevocableManager)
          .access(false);
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/admin/login',
      );
      expect(
        (await admin.projects.getDraft('expiry'))!.content.title.en,
        'Server version',
      );
      expect(
        container.read(draftRecoveryProvider('fixture')).read('expiry'),
        isNotNull,
      );
      (container.read(adminSessionProvider.notifier) as RevocableManager)
          .access(true);
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/admin/projects/expiry/edit');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recover edits'));
      await tester.pumpAndSettle();
      expect(
        (tester.widget<TextField>(title).controller!).text,
        'Unsaved retained edit',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final width in [360.0, 768.0, 1440.0]) {
    for (final lang in ['ar', 'en']) {
      for (final theme in ['light', 'dark']) {
        testWidgets(
          'P07-T12 administrative screens/editor tabs $width $lang $theme',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({
              'language': lang,
              'theme': theme,
              'motionPaused': true,
              'motionReduced': true,
            });
            final prefs = await SharedPreferences.getInstance(),
                memory = MemoryStore();
            final admin = AdminContentRepository(memory, actor: 'fixture');
            await admin.saveCategory(
              'systems',
              const LocalizedText(ar: 'أنظمة', en: 'Systems'),
            );
            memory.docs['sites/yogen/adminUsers/fixture'] = {
              'role': 'manager',
              'enabled': true,
              'loginName': 'fixture',
            };
            memory.docs['sites/yogen/mediaRouting/current'] = {
              'endpoint': 'https://script.google.com/macros/s/fixture/exec',
            };
            const content = ProjectContent(
              title: LocalizedText(ar: 'مشروع جزئي', en: 'Partial project'),
              summary: LocalizedText(ar: 'وصف', en: 'Summary'),
              categoryId: 'systems',
              slug: 'layout',
            );
            await admin.projects.saveDraft(
              'layout',
              content,
              expectedRevision: 0,
            );
            final store = ManagementLayoutStore(memory);
            final container = ProviderContainer(
              overrides: [
                preferencesStorageProvider.overrideWithValue(prefs),
                initialLocationProvider.overrideWithValue(
                  '/admin/projects/layout/edit',
                ),
                adminSessionProvider.overrideWith(ManagerFixture.new),
                accountAuthProvider.overrideWith((ref) async => FixtureAuth()),
                documentStoreProvider.overrideWith((ref) async => store),
                adminContentRepositoryProvider.overrideWith(
                  (ref) async => admin,
                ),
                adminCompanyRepositoryProvider.overrideWith(
                  (ref) async => CompanyRepository(memory, actor: 'fixture'),
                ),
                adminMediaRepositoryProvider.overrideWith(
                  (ref) async => MediaRepository(
                    memory,
                    FixtureTransport(memory),
                    () async => null,
                    actor: 'fixture',
                  ),
                ),
              ],
            );
            addTearDown(container.dispose);
            addTearDown(store.close);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: const YogenApp(),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              container
                  .read(routerProvider)
                  .routeInformationProvider
                  .value
                  .uri
                  .path,
              '/admin/projects/layout/edit',
              reason:
                  'Initial authenticated deep link must survive asynchronous session restoration',
            );
            final tabs = lang == 'ar'
                ? [
                    'التفاصيل',
                    'الوسائط',
                    'الفريق والتقنيات',
                    'الروابط',
                    'النشر والمشاركة',
                    'الأساسيات',
                  ]
                : [
                    'Details',
                    'Media',
                    'Team and technology',
                    'Links',
                    'Publication',
                    'Basics',
                  ];
            for (final tab in tabs) {
              final choice = find.widgetWithText(ChoiceChip, tab);
              await tester.ensureVisible(choice);
              await tester.tap(choice);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: tab);
            }
            for (final route in [
              '/admin',
              '/admin/projects',
              '/admin/categories',
              '/admin/team',
              '/admin/company',
              '/admin/accounts',
              '/admin/verification',
              '/admin/media',
              '/admin/projects/layout/preview',
            ]) {
              container.read(routerProvider).go(route);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: route);
            }
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
