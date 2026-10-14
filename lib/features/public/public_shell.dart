import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart' show tr;
import '../../auth/admin_session.dart' show activeSite;
import '../../core/preferences.dart';
import '../../core/page_metadata.dart';
import '../../data/public_content_repository.dart';
import 'atmospheric_3d_background.dart';
import 'depth_scene.dart';

String publicLocation(
  BuildContext c,
  String path, [
  Map<String, String> query = const {},
]) => Uri(
  path: path,
  queryParameters: {'lang': Localizations.localeOf(c).languageCode, ...query},
).toString();
void publicGo(
  BuildContext c,
  String path, [
  Map<String, String> query = const {},
]) => c.go(publicLocation(c, path, query));
void publicPush(
  BuildContext c,
  String path, [
  Map<String, String> query = const {},
]) => c.push(publicLocation(c, path, query));
void openProject(BuildContext c, String id) {
  publicPush(c, '/projects/$id', {
    'return': base64Url.encode(utf8.encode(GoRouterState.of(c).uri.toString())),
  });
}

bool reducedMotion(BuildContext c, WidgetRef ref) =>
    ref.watch(preferencesProvider).reduced || MediaQuery.disableAnimationsOf(c);

class PublicShell extends ConsumerStatefulWidget {
  final Widget child;
  final Uri uri;
  const PublicShell({super.key, required this.child, required this.uri});
  @override
  ConsumerState<PublicShell> createState() => _PublicShellState();
}

class _PublicShellState extends ConsumerState<PublicShell> {
  final scaffold = GlobalKey<ScaffoldState>();
  @override
  void initState() {
    super.initState();
    sync();
  }

  @override
  void didUpdateWidget(PublicShell old) {
    super.didUpdateWidget(old);
    if (old.uri != widget.uri) sync();
  }

  void sync() {
    final lang = widget.uri.queryParameters['lang'];
    if (['ar', 'en'].contains(lang)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(preferencesProvider).locale.languageCode != lang) {
          ref.read(preferencesProvider.notifier).setLanguage(lang!);
        }
      });
    }
  }

  Future<void> language() async {
    await ref.read(preferencesProvider.notifier).language();
    if (mounted) {
      Router.neglect(
        context,
        () => context.replace(
          widget.uri
              .replace(
                queryParameters: {
                  ...widget.uri.queryParameters,
                  'lang': ref.read(preferencesProvider).locale.languageCode,
                },
              )
              .toString(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    final prefs = ref.watch(preferencesProvider);
    final code = prefs.locale.languageCode;
    final data = ref.watch(publicContentProvider).value;
    final requested = widget.uri.path.startsWith('/projects/')
        ? widget.uri.path.split('/').last
        : null;
    final project = data?.projects
        .where((p) => p.id == requested || p.content.slug == requested)
        .firstOrNull;
    final label = switch (widget.uri.path) {
      '/work' => tr(c, 'أعمالنا', 'Our work'),
      '/services' => tr(c, 'خدماتنا', 'Our services'),
      '/about' => tr(c, 'عن YOGEN', 'About YOGEN'),
      '/contact' => tr(c, 'ابدأ مشروعك', 'Start your project'),
      '/' => tr(c, 'تطبيقات برمجية حسب الطلب', 'Custom software applications'),
      _ =>
        project == null
            ? tr(c, 'المشروع غير متاح', 'Project unavailable')
            : localized(project.content.title, code),
    };
    setPageMetadata(
      '$label | YOGEN',
      project == null
          ? tr(
              c,
              'تطوير تطبيقات برمجية حسب احتياجاتك. اكتشف أعمال YOGEN وابدأ طلب مشروعك.',
              'Software applications built around your requirements. Explore YOGEN work and start your project request.',
            )
          : localized(project.content.summary, code),
      code,
    );
    final dark = Theme.of(c).brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(c).width > 1050;
    final links = [
      ('/', tr(c, 'الرئيسية', 'Home')),
      ('/work', tr(c, 'الأعمال', 'Work')),
      ('/services', tr(c, 'خدماتنا', 'Services')),
      ('/about', tr(c, 'عن YOGEN', 'About')),
      ('/contact', tr(c, 'تواصل معنا', 'Contact')),
    ];
    Widget nav(String path, String label) => TextButton(
      style: TextButton.styleFrom(
        foregroundColor: widget.uri.path == path
            ? Theme.of(c).colorScheme.primary
            : Theme.of(c).colorScheme.onSurface,
      ),
      onPressed: () {
        if (scaffold.currentState?.isEndDrawerOpen == true) {
          Navigator.of(c).pop();
        }
        publicGo(c, path);
      },
      child: Text(
        label,
        style: TextStyle(
          fontWeight: widget.uri.path == path
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
    );
    return Scaffold(
      key: scaffold,
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  tooltip: tr(c, 'إغلاق القائمة', 'Close menu'),
                  onPressed: () => Navigator.of(c).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              ...links.map((l) => nav(l.$1, l.$2)),
              const SizedBox(height: 24),
              Text('YOGEN', style: Theme.of(c).textTheme.titleLarge),
            ],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xff091a2c),
                        Color(0xff081120),
                        Color(0xff181329),
                      ]
                    : const [
                        Color(0xffe5f2ff),
                        Color(0xfff7f9fd),
                        Color(0xffefe8ff),
                      ],
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: Atmospheric3DBackground(),
            ),
          ),
          SafeArea(
            child: Column(
              verticalDirection: VerticalDirection.up,
              children: [
                Expanded(child: widget.child),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: wide ? 86 : 76,
                      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 12),
                      decoration: BoxDecoration(
                        color: Color(
                          dark ? 0xff081120 : 0xfff7f9fd,
                        ).withValues(alpha: dark ? 0.78 : 0.82),
                        border: Border(
                          bottom: BorderSide(
                            color: (dark
                                    ? const Color(0xff12c6eb)
                                    : const Color(0xff1678f5))
                                .withValues(alpha: dark ? 0.18 : 0.12),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => publicGo(c, '/'),
                            child: Image.asset(
                              'planning-assets/yogen-logo-horizontal.png',
                              width: wide
                                  ? 156
                                  : MediaQuery.sizeOf(c).width < 400
                                  ? 90
                                  : 110,
                              height: 42,
                              fit: BoxFit.contain,
                              semanticLabel: tr(
                                c,
                                'YOGEN — الرئيسية',
                                'YOGEN — home',
                              ),
                            ),
                          ),
                    const Spacer(),
                    if (wide) ...links.map((l) => nav(l.$1, l.$2)),
                    TextButton(
                      key: const ValueKey('language'),
                      onPressed: language,
                      child: Text(
                        prefs.locale.languageCode == 'ar'
                            ? 'English'
                            : 'العربية',
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('theme'),
                      tooltip: tr(c, 'تغيير المظهر', 'Change theme'),
                      onPressed: () => ref
                          .read(preferencesProvider.notifier)
                          .theme(Theme.of(c).brightness),
                      icon: Icon(
                        dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                    ),
                    if (!wide)
                      IconButton(
                        tooltip: tr(c, 'فتح القائمة', 'Open menu'),
                        onPressed: () => scaffold.currentState?.openEndDrawer(),
                        icon: const Icon(Icons.menu),
                      ),
                  ],
                  ),
                ),
              ),
            ),
            if (activeSite != 'yogen')
              Container(
                width: double.infinity,
                color: Theme.of(c).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  tr(
                    c,
                    'بيئة اختبار معزولة — البيانات التوضيحية ليست أعمال YOGEN',
                    'Isolated test environment — fixtures are not YOGEN client work',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    ],
  ),
);
  }
}

class PublicFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PublicFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
  });
  @override
  Widget build(BuildContext c) => Semantics(
    container: true,
    explicitChildNodes: true,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class PublicIntro extends StatelessWidget {
  final String eyebrow, title, description;
  const PublicIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext c) => PublicFrame(
    child: LayoutBuilder(
      builder: (c, box) {
        final small = box.maxWidth < 800;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                color: Theme.of(c).colorScheme.tertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: Localizations.localeOf(c).languageCode == 'en'
                    ? 2
                    : 0,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: small ? 36 : 52,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: TextStyle(
                fontSize: 18,
                height: 1.7,
                color: Theme.of(c).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        final scene = SizedBox(
          height: small ? 210 : 300,
          width: small ? double.infinity : 330,
          child: const DepthScene(),
        );
        return small
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, scene],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 48),
                  scene,
                ],
              );
      },
    ),
  );
}

class PublicFooter extends ConsumerWidget {
  const PublicFooter({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    return PublicFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Theme.of(c).colorScheme.outlineVariant),
          const SizedBox(height: 28),
          Wrap(
            spacing: 36,
            runSpacing: 20,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOGEN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                        color: Theme.of(c).colorScheme.primary,
                      ),
                    ),
                    Text(
                      tr(
                        c,
                        'أفكار لمستقبل أكثر إشراقًا.',
                        'Ideas for a brighter tomorrow.',
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => publicGo(c, '/work'),
                child: Text(tr(c, 'استكشف كل الأعمال', 'Explore all work')),
              ),
              TextButton(
                onPressed: () => publicGo(c, '/contact'),
                child: Text(tr(c, 'ابدأ مشروعك', 'Start your project')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () =>
                    ref.read(publicContentProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: Text(tr(c, 'تحديث المحتوى', 'Refresh content')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} YOGEN',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(c).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
