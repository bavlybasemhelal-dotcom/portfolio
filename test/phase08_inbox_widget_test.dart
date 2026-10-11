import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/auth/admin_session.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/data/contact_repository.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/domain/contact_request.dart';
import 'package:yogen_portfolio/features/admin/contact_inbox_page.dart';
import 'media_repository_test.dart' show MemoryStore;
import 'media_widgets_test.dart' show ManagerFixture;

void main() {
  for (final width in [360.0, 768.0, 1440.0]) {
    for (final language in ['ar', 'en']) {
      for (final theme in ['light', 'dark']) {
        testWidgets(
          'P08-T07 private inbox $width $language $theme with long request',
          (t) async {
            t.view.physicalSize = Size(width, 950);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({
              'language': language,
              'theme': theme,
              'motionPaused': true,
            });
            final prefs = await SharedPreferences.getInstance(),
                store = MemoryStore();
            final id = newContactId();
            await ContactRepository(store).submit(
              id,
              ContactInput(
                name: 'QA ${'LongName ' * 10}',
                contact: '+201234567890',
                details: 'QA request ${'Details to review. ' * 20}',
                language: 'en',
              ),
            );
            await store.commit([
              DocumentWrite.set('sites/yogen/contactRequests/$id', {
                ...store.docs['sites/yogen/contactRequests/$id']!,
                'note': 'ملاحظة خاصة بالاختبار / Private QA note',
              }),
            ]);
            await t.pumpWidget(
              ProviderScope(
                overrides: [
                  initialLocationProvider.overrideWithValue('/admin/requests'),
                  preferencesStorageProvider.overrideWithValue(prefs),
                  adminSessionProvider.overrideWith(ManagerFixture.new),
                  adminContactRepositoryProvider.overrideWith(
                    (ref) async => ContactRepository(store),
                  ),
                ],
                child: const YogenApp(),
              ),
            );
            await t.pumpAndSettle();
            expect(
              find.widgetWithText(
                TextField,
                language == 'ar' ? 'بحث الطلبات' : 'Search requests',
              ),
              findsOneWidget,
            );
            expect(find.textContaining('QA LongName'), findsOneWidget);
            expect(t.takeException(), isNull);
            if (width == 1440 && language == 'en' && theme == 'light') {
              final manage = find.text('Manage request');
              await Scrollable.ensureVisible(t.element(manage), alignment: .65);
              await t.pumpAndSettle();
              await t.tap(manage);
              await t.pumpAndSettle();
              final note = find.widgetWithText(TextField, 'Private team note');
              await t.enterText(note, 'QA cancelled note');
              await t.tap(find.text('Cancel'));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
              expect(
                store.docs['sites/yogen/contactRequests/$id']!['note'],
                'ملاحظة خاصة بالاختبار / Private QA note',
              );
              await t.tap(manage);
              await t.pumpAndSettle();
              await t.enterText(note, 'QA follow-up saved');
              await t.tap(find.text('Save'));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
              expect(
                store.docs['sites/yogen/contactRequests/$id']!['note'],
                'QA follow-up saved',
              );
              expect(
                store.docs['sites/yogen/contactRequests/$id']!['contact'],
                '+201234567890',
              );
            }
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
          },
        );
      }
    }
  }
}
