import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/app/yogen_app.dart';
import 'package:yogen_portfolio/auth/admin_session.dart';
import 'package:yogen_portfolio/auth/account_auth.dart';
import 'package:yogen_portfolio/core/preferences.dart';
import 'package:yogen_portfolio/features/admin/admin_providers.dart';

class FixtureSession extends AdminSession {
  @override
  Future<AdminAccess> build() async => const AdminAccess();
  @override
  Future<void> signIn(String name, String password) async {
    if (password != 'Fixture-Password-123') {
      throw const AuthFailure('INVALID_LOGIN_CREDENTIALS');
    }
    state = const AsyncData(
      AdminAccess(
        uid: 'fixture',
        loginName: 'member',
        role: 'editor',
        enabled: true,
      ),
    );
  }

  @override
  Future<void> signOut() async => state = const AsyncData(AdminAccess());
  void revoke() => state = const AsyncData(
    AdminAccess(uid: 'fixture', role: 'editor', enabled: false),
  );
}

class FixtureAuth implements AccountAuth {
  bool changed = false;
  String? changedFrom, changedTo;
  @override
  AuthAccount? get current =>
      const AuthAccount('fixture', 'fixture@login.yogen.invalid');
  @override
  Stream<AuthAccount?> get changes => const Stream.empty();
  @override
  Future<void> restore() async {}
  @override
  Future<AuthAccount> signIn(String login, String password) async => current!;
  @override
  Future<String?> token() async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> changePassword(String old, String next) async {
    changed = true;
    changedFrom = old;
    changedTo = next;
  }
}

void main() {
  for (final locale in ['ar', 'en']) {
    testWidgets(
      'Protected route, login error, editor view, password dialog and revoke at 360px ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'language': locale,
          'theme': 'dark',
          'motionPaused': true,
          'motionReduced': true,
        });
        final prefs = await SharedPreferences.getInstance(),
            auth = FixtureAuth();
        final container = ProviderContainer(
          overrides: [
            initialLocationProvider.overrideWithValue('/validation/foundation'),
            preferencesStorageProvider.overrideWithValue(prefs),
            adminSessionProvider.overrideWith(FixtureSession.new),
            accountAuthProvider.overrideWith((ref) async => auth),
            adminProjectsProvider.overrideWith((ref) async => []),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const YogenApp(),
          ),
        );
        await tester.pumpAndSettle();
        final semantics = tester.ensureSemantics();
        await tester.pump();
        expect(
          find.bySemanticsLabel(locale == 'ar' ? 'English' : 'العربية'),
          findsOneWidget,
        );
        container.read(routerProvider).go('/admin/verification');
        await tester.pumpAndSettle();
        expect(
          find.text(locale == 'ar' ? 'أهلًا بك في YOGEN' : 'Welcome to YOGEN'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(locale == 'ar' ? 'English' : 'العربية'),
          findsOneWidget,
        );
        semantics.dispose();
        await tester.enterText(find.byType(TextField).at(0), 'member');
        await tester.enterText(find.byType(TextField).at(1), 'incorrect');
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale == 'ar'
                ? 'اسم الدخول أو كلمة المرور غير صحيحة.'
                : 'The username or password is incorrect.',
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          'Fixture-Password-123',
        );
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(
          find.text(locale == 'ar' ? 'مساحة الفريق' : 'Team workspace'),
          findsOneWidget,
        );
        expect(
          find.text(
            locale == 'ar' ? 'إضافة حساب محرر' : 'Add an editor account',
          ),
          findsNothing,
        );
        container.read(routerProvider).go('/admin/verification');
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(locale == 'ar' ? 'تغيير كلمة المرور' : 'Change password'),
        );
        await tester.pumpAndSettle();
        final savePassword = find.widgetWithText(
          FilledButton,
          locale == 'ar' ? 'حفظ كلمة المرور' : 'Save password',
        );
        final current = find.byKey(const ValueKey('password-current'));
        final next = find.byKey(const ValueKey('password-new'));
        final confirmation = find.byKey(
          const ValueKey('password-confirmation'),
        );
        await tester.enterText(current, 'old-fixture');
        await tester.enterText(next, 'short');
        await tester.enterText(confirmation, 'short');
        await tester.ensureVisible(savePassword);
        await tester.tap(savePassword);
        await tester.pumpAndSettle();
        expect(auth.changed, false);
        expect(
          find.text(
            locale == 'ar'
                ? 'استخدم من 12 إلى 128 حرفًا.'
                : 'Use 12 to 128 characters.',
          ),
          findsOneWidget,
        );
        await tester.enterText(next, 'New-Fixture-Password-123');
        await tester.enterText(confirmation, 'Different-Password-123');
        await tester.tap(savePassword);
        await tester.pumpAndSettle();
        expect(auth.changed, false);
        expect(
          find.text(
            locale == 'ar'
                ? 'تأكيد كلمة المرور غير مطابق.'
                : 'Passwords do not match.',
          ),
          findsOneWidget,
        );
        await tester.enterText(confirmation, 'New-Fixture-Password-123');
        await tester.tap(savePassword);
        await tester.pumpAndSettle();
        expect(auth.changed, true);
        expect(auth.changedFrom, 'old-fixture');
        expect(auth.changedTo, 'New-Fixture-Password-123');
        expect(tester.takeException(), isNull);
        (container.read(adminSessionProvider.notifier) as FixtureSession)
            .revoke();
        await tester.pumpAndSettle();
        expect(
          find.text(locale == 'ar' ? 'أهلًا بك في YOGEN' : 'Welcome to YOGEN'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
