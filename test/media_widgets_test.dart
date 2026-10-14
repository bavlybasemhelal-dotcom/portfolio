import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/auth/admin_session.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/features/media/media_preview.dart';
import 'package:yogen_portfolio/features/media/media_transport.dart';
import 'admin_access_widget_test.dart' show FixtureAuth;
import 'media_repository_test.dart' show MemoryStore, FixtureTransport;

class ManagerFixture extends AdminSession {
  @override
  Future<AdminAccess> build() async => const AdminAccess(
    uid: 'fixture',
    loginName: 'manager',
    role: 'manager',
    enabled: true,
  );
}

class LayoutStore extends FirestoreRestStore {
  LayoutStore() : super(projectId: 'fixture', token: () async => null);
  @override
  Future<StoredDocument?> get(String path) async {
    if (path.endsWith('/settings/drive')) {
      return StoredDocument(path, {
        'administrativeEmail': 'stored@example.invalid',
      });
    }
    if (path.endsWith('/mediaRouting/current')) {
      return StoredDocument(path, {
        'endpoint': 'https://script.google.com/macros/s/fixture/exec',
      });
    }
    return null;
  }

  @override
  Future<List<StoredDocument>> listAll(String path) async => [];
}

void main() {
  testWidgets('Hosted image failure retries locally without a Drive receipt', (
    tester,
  ) async {
    final transport = FixtureTransport(MemoryStore());
    final cache = MediaByteCache(transport);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriveImage(
            cache: cache,
            endpoint: 'https://script.google.com/macros/s/fixture/exec',
            site: 'yogen',
            assetId: 'hosted-fixture',
            alt: 'Hosted cover',
            publicUrl:
                'https://portfolio-14d15.web.app/project-media/${'a' * 64}.jpg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(transport.reads, 0);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(transport.reads, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    cache.clear();
  });
  testWidgets('Public cover falls back to its receipt when image host fails', (
    tester,
  ) async {
    final transport = FixtureTransport(MemoryStore());
    final cache = MediaByteCache(transport);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriveImage(
            cache: cache,
            endpoint: 'https://script.google.com/macros/s/fixture/exec',
            site: 'yogen',
            assetId: 'fixture-receipt',
            publicFileId: 'public-drive-file',
            alt: 'Public cover',
          ),
        ),
      ),
    );
    // Widget tests return HTTP 400 for network images. The existing receipt
    // transport then returns invalid bytes, exercising its handled retry UI.
    await tester.pumpAndSettle();
    expect(transport.reads, 1);
    expect(find.text('Image unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(transport.reads, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    cache.clear();
  });
  for (final language in ['ar', 'en']) {
    for (final theme in ['light', 'dark']) {
      for (final width in [360.0, 768.0, 1440.0]) {
        testWidgets(
          'Media manager settings restore and layout $language/$theme/$width',
          (tester) async {
            tester.view.physicalSize = Size(width, 850);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({
              'language': language,
              'theme': theme,
              'motionPaused': true,
              'motionReduced': true,
            });
            final prefs = await SharedPreferences.getInstance(),
                store = LayoutStore();
            final container = ProviderContainer(
              overrides: [
                initialLocationProvider.overrideWithValue(
                  '/validation/foundation',
                ),
                preferencesStorageProvider.overrideWithValue(prefs),
                adminSessionProvider.overrideWith(ManagerFixture.new),
                accountAuthProvider.overrideWith((ref) async => FixtureAuth()),
                documentStoreProvider.overrideWith((ref) async => store),
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
            container.read(routerProvider).go('/admin/media');
            await tester.pumpAndSettle();
            expect(
              find.text(
                language == 'ar' ? 'التخزين والوسائط' : 'Storage and media',
              ),
              findsWidgets,
            );
            expect(find.text('stored@example.invalid'), findsOneWidget);
            await tester.ensureVisible(
              find.text(language == 'ar' ? 'الكل' : 'All'),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
  testWidgets(
    'Failed Drive image has local placeholder and retries its request',
    (tester) async {
      final transport = FixtureTransport(MemoryStore());
      final cache = MediaByteCache(transport);
      // FixtureTransport reports four invalid image bytes, causing a handled decode failure.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriveImage(
              cache: cache,
              endpoint: 'https://script.google.com/macros/s/fixture/exec',
              site: 'yogen',
              assetId: 'fixture',
              alt: 'test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Image unavailable'), findsOneWidget);
      final before = transport.reads;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(transport.reads, before + 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      cache.clear();
    },
  );
}
