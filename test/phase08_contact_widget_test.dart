import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/data/contact_repository.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'package:yogen_portfolio/features/media/media_transport.dart';
import 'package:yogen_portfolio/features/public/contact_session.dart';
import 'media_repository_test.dart' show MemoryStore;
import 'support/public_fixtures.dart';

Future<ProviderContainer> contactBoot(
  WidgetTester t,
  MemoryStore store, {
  String language = 'en',
  String theme = 'light',
  double width = 1440,
  String path = '/contact',
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'language': language,
    'theme': theme,
    'motionPaused': true,
  });
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        initialLocationProvider.overrideWithValue(
          '$path${path.contains('?') ? '&' : '?'}lang=$language',
        ),
        preferencesStorageProvider.overrideWithValue(prefs),
        publicRepositoryProvider.overrideWithValue(FixturePublicRepository()),
        publicMediaCacheProvider.overrideWithValue(
          MediaByteCache(FixtureMediaTransport()),
        ),
        contactRepositoryProvider.overrideWithValue(ContactRepository(store)),
      ],
      child: const YogenApp(),
    ),
  );
  final container = ProviderScope.containerOf(t.element(find.byType(YogenApp)));
  await t.pumpAndSettle();
  return container;
}

Future<void> seek(WidgetTester t, Finder finder) async {
  await Scrollable.ensureVisible(t.element(finder), alignment: .65);
  await t.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 768.0, 1440.0]) {
    for (final language in ['ar', 'en']) {
      for (final theme in ['light', 'dark']) {
        testWidgets(
          'P08-T04 contact form $width $language $theme retains responsive fields',
          (t) async {
            await contactBoot(
              t,
              MemoryStore(),
              width: width,
              language: language,
              theme: theme,
            );
            expect(find.byType(TextFormField), findsNWidgets(3));
            expect(t.takeException(), isNull);
            await seek(
              t,
              find.text(language == 'ar' ? 'إرسال الطلب' : 'Send request'),
            );
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'P08-T04 invalid submission retains fields and provides linked error summary',
    (t) async {
      final store = MemoryStore();
      final c = await contactBoot(t, store);
      await t.enterText(find.widgetWithText(TextField, 'Your name'), 'QA name');
      await t.enterText(
        find.widgetWithText(TextField, 'Contact information'),
        'bad',
      );
      final send = find.text('Send request');
      await seek(t, send);
      await t.tap(send);
      await t.pumpAndSettle();
      expect(
        find.text('Review these fields; your input has been kept.'),
        findsOneWidget,
      );
      expect(c.read(contactSessionProvider).fields['name'], 'QA name');
      expect(store.docs, isEmpty);
      expect(
        find.text(
          'Enter a valid email or an international phone number starting with +.',
        ),
        findsNWidgets(2),
      );
      await c.read(preferencesProvider.notifier).setLanguage('ar');
      await t.pumpAndSettle();
      expect(
        find.text('اكتب بريدًا صالحًا أو رقم هاتف دوليًا يبدأ بـ +.'),
        findsNWidgets(2),
      );
      expect(
        find.text(
          'Enter a valid email or an international phone number starting with +.',
        ),
        findsNothing,
      );
      final clear = find.text('مسح المسودة');
      await seek(t, clear);
      await t.tap(clear);
      await t.pumpAndSettle();
      expect(c.read(contactSessionProvider).fields, isEmpty);
      expect(
        find.text('اكتب بريدًا صالحًا أو رقم هاتف دوليًا يبدأ بـ +.'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'P08-T06 supplied query cannot spoof published title; submission saves canonical context',
    (t) async {
      final store = MemoryStore();
      final c = await contactBoot(
        t,
        store,
        path: '/contact?project=fixture-0&nameAr=Spoofed&nameEn=Spoofed',
      );
      expect(find.textContaining('Test project 0'), findsOneWidget);
      expect(find.textContaining('Spoofed'), findsNothing);
      for (final entry in {
        'Your name': 'QA visitor',
        'Contact information': 'qa@example.invalid',
        'Project idea and requirements': 'A labelled technical brief.',
      }.entries) {
        final field = find.widgetWithText(TextField, entry.key);
        await seek(t, field);
        await t.enterText(field, entry.value);
      }
      final send = find.text('Send request');
      await seek(t, send);
      await t.tap(send);
      await t.pumpAndSettle();
      final id = c.read(contactSessionProvider).confirmedId!;
      expect(
        store.docs['sites/yogen/contactRequests/$id']!['project']['nameEn'],
        'Test project 0',
      );
      expect(
        find.textContaining(
          'Your request has been received and saved for the team.',
        ),
        findsOneWidget,
      );
    },
  );
}
