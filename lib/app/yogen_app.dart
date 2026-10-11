import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/backend.dart';
import '../core/firebase_config.dart';
import '../core/preferences.dart';
import '../auth/admin_session.dart';
import '../features/admin/access_pages.dart';
import '../features/admin/media_library_page.dart';
import '../features/admin/admin_shell.dart';
import '../features/admin/contact_inbox_page.dart';
import '../features/public/contact_page.dart';
import '../features/admin/projects_pages.dart';
import '../features/admin/project_editor_page.dart';
import '../features/admin/preview_page.dart';
import '../features/admin/management_pages.dart';
import '../features/admin/editor_session.dart';
import '../features/validation/media_gallery_page.dart';
import '../features/validation/backend_page.dart';
import '../features/validation/media_page.dart';
import '../features/validation/scene_page.dart';
import '../features/public/public_shell.dart';
import '../features/public/public_pages.dart';
import '../features/public/home_page.dart';

String tr(BuildContext c, String ar, String en) =>
    Localizations.localeOf(c).languageCode == 'ar' ? ar : en;
Page<void> publicPage(BuildContext c, GoRouterState s, Widget child) {
  final reduced =
      MediaQuery.disableAnimationsOf(c) ||
      ProviderScope.containerOf(c).read(preferencesProvider).reduced;
  return CustomTransitionPage<void>(
    key: s.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: reduced ? 0 : 460),
    reverseTransitionDuration: Duration(milliseconds: reduced ? 0 : 300),
    transitionsBuilder: (c, a, _, child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class _AccessRefresh extends ChangeNotifier {
  void changed() => notifyListeners();
}

final initialLocationProvider = Provider<String>((ref) => '/');
const releaseBuild = bool.fromEnvironment('YOGEN_RELEASE');
final routerProvider = Provider<GoRouter>((ref) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final refresh = _AccessRefresh();
  ref.listen(adminSessionProvider, (_, _) => refresh.changed());
  final router = GoRouter(
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: refresh,
    redirect: (_, state) async {
      if (!(state.uri.path == '/admin' ||
          state.uri.path.startsWith('/admin/'))) {
        return null;
      }
      AdminAccess? access = ref.read(adminSessionProvider).value;
      if (ref.read(adminSessionProvider).isLoading) {
        try {
          access = await ref.read(adminSessionProvider.future);
        } catch (_) {
          access = null;
        }
      }
      if (state.uri.path == '/admin/login' && access?.allowed == true) {
        return '/admin';
      }
      if (!(state.uri.path == '/admin' ||
              state.uri.path.startsWith('/admin/')) ||
          ['/admin/login', '/admin/recovery'].contains(state.uri.path)) {
        return null;
      }
      if (access?.allowed != true) return '/admin/login';
      if ([
            '/admin/categories',
            '/admin/team',
            '/admin/company',
            '/admin/accounts',
          ].contains(state.uri.path) &&
          access?.manager != true) {
        return '/admin';
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (c, s, child) => PublicShell(uri: s.uri, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (c, s) => publicPage(c, s, const HomePage()),
          ),
          GoRoute(
            path: '/work',
            pageBuilder: (c, s) => publicPage(c, s, const WorkPage()),
          ),
          GoRoute(
            path: '/projects/:id',
            pageBuilder: (c, s) =>
                publicPage(c, s, ProjectPage(id: s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/services',
            pageBuilder: (c, s) => publicPage(c, s, const ServicesPage()),
          ),
          GoRoute(
            path: '/about',
            pageBuilder: (c, s) => publicPage(c, s, const AboutPage()),
          ),
          GoRoute(
            path: '/contact',
            pageBuilder: (c, s) => publicPage(c, s, const ContactPage()),
          ),
        ],
      ),
      ShellRoute(
        builder: (c, s, child) => AdminShell(uri: s.uri, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const AdminOverviewPage()),
          GoRoute(
            path: '/admin/requests',
            builder: (_, _) => const ContactInboxPage(),
          ),
          GoRoute(
            path: '/admin/projects',
            builder: (_, _) => const AdminProjectsPage(),
          ),
          GoRoute(
            path: '/admin/projects/:id/edit',
            builder: (_, s) => ProjectEditorPage(
              key: ValueKey('editor-${s.pathParameters['id']}'),
              id: s.pathParameters['id']!,
            ),
            onExit: (c, s) => ref.read(editorLeaveGuardProvider).confirm(c),
          ),
          GoRoute(
            path: '/admin/projects/:id/preview',
            builder: (_, s) => ProjectPreviewPage(
              key: ValueKey('preview-${s.pathParameters['id']}'),
              id: s.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/admin/categories',
            builder: (_, _) => const AdminCategoriesPage(),
          ),
          GoRoute(
            path: '/admin/team',
            builder: (_, _) => const AdminTeamPage(),
          ),
          GoRoute(
            path: '/admin/company',
            builder: (_, _) => const AdminCompanyPage(),
          ),
          GoRoute(
            path: '/admin/accounts',
            builder: (_, _) => const AdminAccountsPage(),
          ),
          GoRoute(
            path: '/admin/verification',
            builder: (c, _) => AdminPage(
              title: tr(c, 'حسابي', 'My account'),
              child: const AdminAccessPage(),
            ),
          ),
          GoRoute(
            path: '/admin/media',
            builder: (c, _) => AdminPage(
              title: tr(c, 'التخزين والوسائط', 'Storage and media'),
              child: const MediaLibraryPage(showTitle: false),
            ),
          ),
          GoRoute(
            path: '/admin/login',
            builder: (c, _) => AdminPage(
              title: tr(c, 'دخول الفريق', 'Team sign in'),
              child: const AdminLoginPage(),
            ),
          ),
          GoRoute(
            path: '/admin/recovery',
            builder: (c, _) => AdminPage(
              title: tr(c, 'استعادة الوصول', 'Recover access'),
              child: const RecoveryPage(),
            ),
          ),
        ],
      ),
      if (!releaseBuild) ShellRoute(
        builder: (c, s, child) => VerificationShell(child: child),
        routes: [
          GoRoute(
            path: '/validation/foundation',
            builder: (_, _) => const _PageScroll(child: FoundationPage()),
          ),
          GoRoute(
            path: '/validation/backend',
            builder: (_, _) => const _PageScroll(child: BackendPage()),
          ),
          GoRoute(
            path: '/validation/media',
            builder: (_, _) => const _PageScroll(child: MediaPage()),
          ),
          GoRoute(
            path: '/validation/scene',
            builder: (_, _) => const _PageScroll(child: ScenePage()),
          ),
          GoRoute(
            path: '/validation/media-gallery',
            builder: (_, _) => const _PageScroll(child: MediaGalleryPage()),
          ),
          GoRoute(
            path: '/validation/fixture',
            builder: (_, _) => const _PageScroll(child: FixturePage()),
          ),
        ],
      ),
    ],
    errorBuilder: (c, s) =>
        PublicShell(uri: s.uri, child: const PublicNotFound()),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class YogenApp extends ConsumerStatefulWidget {
  const YogenApp({super.key});
  @override
  ConsumerState<YogenApp> createState() => _YogenAppState();
}

class _YogenAppState extends ConsumerState<YogenApp> {
  @override
  void initState() {
    super.initState();
    if (FirebaseConfig.environment.isConfigured) {
      Future.microtask(
        () => ref
            .read(backendProvider.notifier)
            .configure(FirebaseConfig.environment),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    ThemeData theme(Brightness b) {
      final base = ColorScheme.fromSeed(
        seedColor: const Color(0xff1264df),
        brightness: b,
        surface: Color(b == Brightness.dark ? 0xff0c162b : 0xfff5f8ff),
      );
      final dark = b == Brightness.dark;
      final scheme = base.copyWith(
        primary: Color(dark ? 0xff91bcff : 0xff125bc4),
        onPrimary: Color(dark ? 0xff09234c : 0xffffffff),
        tertiary: Color(dark ? 0xff6ddcf1 : 0xff146a8a),
        surface: Color(dark ? 0xff101d32 : 0xffffffff),
        onSurface: Color(dark ? 0xfff3f6fc : 0xff101e36),
        onSurfaceVariant: Color(dark ? 0xffb5c4db : 0xff485a75),
        outline: Color(dark ? 0xff7188a8 : 0xff7788a3),
        outlineVariant: Color(dark ? 0xff344967 : 0xffcbd6e5),
      );
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: prefs.locale.languageCode == 'ar'
            ? 'PlexArabic'
            : 'PlexSans',
        scaffoldBackgroundColor: scheme.surface,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, height: 1.6),
        ),
      );
    }

    return MaterialApp.router(
      title: 'YOGEN',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      locale: prefs.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: prefs.theme,
    );
  }
}

class VerificationShell extends ConsumerWidget {
  final Widget child;
  const VerificationShell({super.key, required this.child});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final dark = Theme.of(c).brightness == Brightness.dark;
    final scheme = Theme.of(c).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [
                    Color(0xff081625),
                    Color(0xff101528),
                    Color(0xff201632),
                  ]
                : const [
                    Color(0xffe5f7ff),
                    Color(0xfff7faff),
                    Color(0xffece9ff),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            // Paint the header after the nested Navigator so its route's
            // BlockSemantics cannot hide shared navigation from screen readers.
            verticalDirection: VerticalDirection.up,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: child),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: .9),
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => c.go('/'),
                      child: const Text(
                        'YOGEN',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    Text(
                      tr(
                        c,
                        'فحص تقني · المرحلة 05',
                        'Technical verification · Phase 05',
                      ),
                    ),
                    OutlinedButton(
                      key: const ValueKey('language'),
                      onPressed: () =>
                          ref.read(preferencesProvider.notifier).language(),
                      child: Text(
                        prefs.locale.languageCode == 'ar'
                            ? 'English'
                            : 'العربية',
                      ),
                    ),
                    OutlinedButton(
                      key: const ValueKey('theme'),
                      onPressed: () => ref
                          .read(preferencesProvider.notifier)
                          .theme(Theme.of(c).brightness),
                      child: Text(tr(c, 'المظهر', 'Theme')),
                    ),
                    OutlinedButton(
                      key: const ValueKey('pause'),
                      onPressed: () =>
                          ref.read(preferencesProvider.notifier).pause(),
                      child: Text(
                        prefs.paused
                            ? tr(c, 'تشغيل الحركة', 'Resume motion')
                            : tr(c, 'إيقاف الحركة', 'Pause motion'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageScroll extends StatelessWidget {
  final Widget child;
  const _PageScroll({required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );
}

class FoundationPage extends StatelessWidget {
  const FoundationPage({super.key});
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr(c, 'أساس واحد. تجارب واضحة.', 'One foundation. Measurable checks.'),
        style: Theme.of(
          c,
        ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Text(
        tr(
          c,
          'نموذج تحقق Flutter للويب والموبايل والديسكتوب. بيانات التجارب معزولة عن أعمال الشركة.',
          'Flutter verification for web, mobile and desktop. Experiments are isolated from company work.',
        ),
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _Tile(
            icon: Icons.cloud_outlined,
            title: 'Firebase',
            description: tr(
              c,
              'الدخول وقراءة وكتابة سجل تجربة',
              'Authentication and a test record round trip',
            ),
            path: '/validation/backend',
          ),
          _Tile(
            icon: Icons.image_outlined,
            title: tr(c, 'وسائط Drive', 'Drive media'),
            description: tr(
              c,
              'رفع Base64 وحفظ المرجع وعرض الصورة',
              'Base64 transfer, metadata and image rendering',
            ),
            path: '/validation/media',
          ),
          _Tile(
            icon: Icons.view_in_ar_outlined,
            title: tr(c, 'تجربة 3D', '3D experiment'),
            description: tr(
              c,
              'مجسم Flutter ودورة 360° وبديل ثابت',
              'Flutter mesh, 360° rotation and a static fallback',
            ),
            path: '/validation/scene',
          ),
        ],
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => c.go('/validation/fixture'),
        child: Text(tr(c, 'فحص رابط داخلي', 'Internal link fixture')),
      ),
    ],
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, description, path;
  const _Tile({
    required this.icon,
    required this.title,
    required this.description,
    required this.path,
  });
  @override
  Widget build(BuildContext c) => SizedBox(
    width: 340,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => c.go(path),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: Theme.of(c).colorScheme.primary),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 20),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    ),
  );
}

class FixturePage extends StatelessWidget {
  const FixturePage({super.key});
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr(c, 'صفحة تجربة للرابط الداخلي', 'Internal route fixture'),
        style: Theme.of(c).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      Text(
        tr(
          c,
          'المعرف phase03-fixture ثابت. حدّث الصفحة لاختبار حفظ المسار. هذا سجل تقني تجريبي.',
          'The phase03-fixture ID is stable. Refresh to verify routing. This is a technical fixture.',
        ),
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => c.go('/'),
        child: Text(tr(c, 'الرئيسية', 'Home')),
      ),
    ],
  );
}
