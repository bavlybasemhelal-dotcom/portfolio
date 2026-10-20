import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart' show tr;
import '../../auth/admin_session.dart';
import '../../core/preferences.dart';
import '../../core/page_metadata.dart';
import '../public/depth_scene.dart';
import 'editor_session.dart';
import 'access_pages.dart' show showChangePasswordDialog;

class AdminNav {
  final String path, ar, en;
  final IconData icon;
  final bool manager;
  const AdminNav(
    this.path,
    this.ar,
    this.en,
    this.icon, {
    this.manager = false,
  });
}

const adminNavigation = [
  AdminNav('/admin', 'نظرة عامة', 'Overview', Icons.space_dashboard_outlined),
  AdminNav('/admin/projects', 'المشاريع', 'Projects', Icons.layers_outlined),
  AdminNav(
    '/admin/featured-projects',
    'اختيار أهم المشاريع',
    'Choose featured projects',
    Icons.star_outline,
  ),
  AdminNav(
    '/admin/requests',
    'طلبات العملاء',
    'Client requests',
    Icons.inbox_outlined,
  ),
  AdminNav('/admin/verification', 'حسابي', 'My account', Icons.person_outline),
  AdminNav(
    '/admin/media',
    'التخزين والوسائط',
    'Storage and media',
    Icons.cloud_outlined,
  ),
  AdminNav(
    '/admin/categories',
    'التصنيفات',
    'Categories',
    Icons.category_outlined,
    manager: true,
  ),
  AdminNav(
    '/admin/team',
    'ملفات الفريق',
    'Public team profiles',
    Icons.groups_outlined,
    manager: true,
  ),
  AdminNav(
    '/admin/company',
    'الشركة والتواصل',
    'Company and contact',
    Icons.business_outlined,
    manager: true,
  ),
  AdminNav(
    '/admin/accounts',
    'حسابات الوصول',
    'Access accounts',
    Icons.admin_panel_settings_outlined,
    manager: true,
  ),
];

class AdminShell extends ConsumerWidget {
  final Uri uri;
  final Widget child;
  const AdminShell({super.key, required this.uri, required this.child});
  Future<void> go(BuildContext c, WidgetRef ref, String path) async {
    if (await ref.read(editorLeaveGuardProvider).confirm(c) && c.mounted) {
      c.go(path);
    }
  }

  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final access = ref.watch(adminSessionProvider).value;
    final pref = ref.watch(preferencesProvider);
    setPageMetadata(
      tr(c, 'لوحة الفريق | YOGEN', 'Team workspace | YOGEN'),
      'YOGEN',
      pref.locale.languageCode,
    );
    final wide = MediaQuery.sizeOf(c).width >= 1000,
        allowed = access?.allowed == true;
    final selected = adminNavigation
        .where(
          (v) =>
              uri.path == v.path ||
              (v.path != '/admin' && uri.path.startsWith('${v.path}/')),
        )
        .firstOrNull;
    Widget menu() => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      children: [
        if (allowed)
          ...adminNavigation
              .where((v) => !v.manager || access!.manager)
              .map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    selected: selected?.path == v.path,
                    selectedTileColor: Theme.of(
                      c,
                    ).colorScheme.primary.withValues(alpha: .12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(v.icon),
                    title: Text(tr(c, v.ar, v.en)),
                    onTap: () async {
                      if (!wide) Navigator.of(c).pop();
                      await go(c, ref, v.path);
                    },
                  ),
                ),
              ),
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(tr(c, 'زيارة الموقع', 'Visit website')),
          onTap: () => go(c, ref, '/'),
        ),
      ],
    );
    return Scaffold(
      drawer: !wide && allowed ? Drawer(child: SafeArea(child: menu())) : null,
      appBar: AppBar(
        toolbarHeight: 80,
        title: Semantics(
          label: 'YOGEN',
          image: true,
          child: ExcludeSemantics(
            child: Image.asset(
              'planning-assets/yogen-logo-horizontal.png',
              width: 155,
              height: 36,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: tr(c, 'تغيير المظهر', 'Change theme'),
            onPressed: () => ref
                .read(preferencesProvider.notifier)
                .theme(Theme.of(c).brightness),
            icon: Icon(
              Theme.of(c).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(preferencesProvider.notifier).language();
              if (c.mounted) {
                Router.neglect(
                  c,
                  () => c.replace(
                    uri
                        .replace(
                          queryParameters: {
                            ...uri.queryParameters,
                            'lang': ref
                                .read(preferencesProvider)
                                .locale
                                .languageCode,
                          },
                        )
                        .toString(),
                  ),
                );
              }
            },
            child: Text(
              pref.locale.languageCode == 'ar' ? 'English' : 'العربية',
            ),
          ),
          if (allowed)
            PopupMenuButton<String>(
              tooltip: tr(c, 'إعدادات الحساب', 'Account settings'),
              onSelected: (value) async {
                if (value == 'password') {
                  await showChangePasswordDialog(c);
                  return;
                }
                if (await ref.read(editorLeaveGuardProvider).confirm(c)) {
                  await ref.read(adminSessionProvider.notifier).signOut();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'password',
                  child: Text(tr(c, 'تغيير كلمة المرور', 'Change password')),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Text(tr(c, 'تسجيل الخروج', 'Sign out')),
                ),
              ],
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(c).brightness == Brightness.dark
                ? [const Color(0xff0a2030), const Color(0xff17162e)]
                : [const Color(0xffedf7ff), const Color(0xfff4efff)],
          ),
        ),
        child: Row(
          // Paint navigation after the nested route so BlockSemantics keeps it
          // available to screen readers. Reverse layout preserves its position.
          textDirection: Directionality.of(c) == TextDirection.ltr
              ? TextDirection.rtl
              : TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: child),
            if (wide && allowed)
              Container(
                width: 252,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(c).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(c).colorScheme.outlineVariant,
                  ),
                ),
                child: menu(),
              ),
          ],
        ),
      ),
    );
  }
}

class AdminPage extends ConsumerWidget {
  final String title, description;
  final Widget child;
  final List<Widget> actions;
  const AdminPage({
    super.key,
    required this.title,
    required this.child,
    this.description = '',
    this.actions = const [],
  });
  @override
  Widget build(BuildContext c, WidgetRef ref) => SingleChildScrollView(
    key: PageStorageKey(GoRouterState.of(c).uri.path),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.sizeOf(c).width < 600 ? 16 : 28),
          child: Semantics(
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (c, b) => Wrap(
                    spacing: 20,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: b.maxWidth < 600
                            ? b.maxWidth
                            : (b.maxWidth - 210).clamp(200, double.infinity),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOGEN / ${tr(c, 'مساحة الفريق', 'Team workspace')}',
                              style: TextStyle(
                                color: Theme.of(c).colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              style: Theme.of(c).textTheme.headlineMedium,
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                description,
                                style: Theme.of(c).textTheme.bodyMedium,
                              ),
                            ],
                            if (actions.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: actions,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 160,
                        height: 125,
                        child: DepthScene(identity: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                child,
                const SizedBox(height: 32),
                if (ref.watch(adminSessionProvider).value?.allowed == true)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(preferencesProvider.notifier).pause(),
                        icon: Icon(
                          ref.watch(preferencesProvider).paused
                              ? Icons.play_arrow
                              : Icons.pause,
                        ),
                        label: Text(
                          tr(
                            c,
                            ref.watch(preferencesProvider).paused
                                ? 'استئناف الحركة'
                                : 'إيقاف الحركة',
                            ref.watch(preferencesProvider).paused
                                ? 'Resume motion'
                                : 'Pause motion',
                          ),
                        ),
                      ),
                      FilterChip(
                        label: Text(tr(c, 'تقليل الحركة', 'Reduce motion')),
                        selected: ref.watch(preferencesProvider).reduced,
                        onSelected: (_) =>
                            ref.read(preferencesProvider.notifier).reduce(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminSurface extends StatelessWidget {
  final Widget child;
  const AdminSurface({super.key, required this.child});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(c).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(c).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: Theme.of(c).brightness == Brightness.dark ? .16 : .05,
          ),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}
