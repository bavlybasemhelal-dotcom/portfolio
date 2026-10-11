import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/yogen_app.dart' show tr;
import '../../auth/admin_session.dart' show activeSite;
import '../../data/public_content_repository.dart';
import '../../domain/project.dart';
import '../media/media_preview.dart';
import 'project_widgets.dart';
import 'public_shell.dart';
import 'formatted_text.dart';

const serviceText = LocalizedText(
  ar: 'إنشاء تطبيقات برمجية حسب طلب العميل.',
  en: 'Custom software applications built around each client’s requirements.',
);
const aboutText = LocalizedText(
  ar: 'YOGEN فريق لتطوير التطبيقات البرمجية حسب الطلب. بنحوّل احتياجاتك لأفكار واضحة وتجارب عملية.',
  en: 'YOGEN is a team creating custom software applications. We turn your requirements into clear ideas and practical experiences.',
);

class WorkPage extends ConsumerStatefulWidget {
  const WorkPage({super.key});
  @override
  ConsumerState<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends ConsumerState<WorkPage> {
  final search = TextEditingController();
  int shown = 12;
  String lastQuery = '';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Set<String> filters(Uri uri) {
    try {
      return Set<String>.from(
        jsonDecode(uri.queryParameters['filters'] ?? '[]') as List,
      );
    } catch (_) {
      return {};
    }
  }

  void update(String q, Set<String> selected) {
    shown = 12;
    Router.neglect(
      context,
      () => context.replace(
        publicLocation(context, '/work', {
          'q': q,
          if (selected.isNotEmpty)
            'filters': jsonEncode(selected.toList()..sort()),
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final uri = GoRouterState.of(c).uri;
    final q = uri.queryParameters['q'] ?? '';
    if (search.text != q) {
      search.value = TextEditingValue(
        text: q,
        selection: TextSelection.collapsed(offset: q.length),
      );
    }
    final selected = filters(uri);
    return Focus(
      autofocus: true,
      child: CustomScrollView(
        key: const PageStorageKey('work-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: PublicIntro(
              eyebrow: tr(c, 'YOGEN / أعمالنا', 'YOGEN / OUR WORK'),
              title: tr(
                c,
                'أفكار اتحوّلت لتجارب.',
                'Ideas turned into experiences.',
              ),
              description: tr(
                c,
                'استكشف المشاريع المنشورة، واختار المجال اللي يهمك.',
                'Explore published projects and find the work that interests you.',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentState(
              builder: (data) {
                final code = Localizations.localeOf(c).languageCode;
                final choices = <String, LocalizedText>{
                  for (final p in data.projects) ...p.filters,
                };
                return PublicFrame(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: search,
                        onChanged: (v) => update(v, selected),
                        decoration: InputDecoration(
                          labelText: tr(c, 'ابحث عن مشروع', 'Search projects'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: search.text.isNotEmpty
                              ? IconButton(
                                  tooltip: tr(c, 'مسح البحث', 'Clear search'),
                                  onPressed: () => update('', selected),
                                  icon: const Icon(Icons.close),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: Text(tr(c, 'الكل', 'All')),
                            selected: selected.isEmpty,
                            onSelected: (_) => update(q, {}),
                          ),
                          ...choices.entries.map(
                            (e) => FilterChip(
                              label: Text(localized(e.value, code)),
                              selected: selected.contains(e.key),
                              onSelected: (on) {
                                final next = {...selected};
                                if (on) {
                                  next.add(e.key);
                                } else {
                                  next.remove(e.key);
                                }
                                update(q, next);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (selected.length > 1) ...[
                        const SizedBox(height: 12),
                        Text(
                          tr(
                            c,
                            'المشاريع المطابقة لأي من التصنيفات المختارة.',
                            'Projects matching any selected category.',
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          ...ref
              .watch(publicContentProvider)
              .maybeWhen(
                data: (data) {
                  final code = Localizations.localeOf(c).languageCode;
                  final needle = q.trim().toLowerCase();
                  final rows = data.projects
                      .where(
                        (p) =>
                            (selected.isEmpty ||
                                p.filters.keys.any(selected.contains)) &&
                            (needle.isEmpty ||
                                '${p.content.title.ar} ${p.content.title.en} ${p.content.summary.ar} ${p.content.summary.en} ${p.category.ar} ${p.category.en} ${p.content.tags.map((t) => '${t.ar} ${t.en}').join(' ')}'
                                    .toLowerCase()
                                    .contains(needle)),
                      )
                      .toList();
                  if (rows.isEmpty) {
                    return [
                      SliverToBoxAdapter(
                        child: PublicFrame(
                          child: PublicMessage(
                            icon: Icons.search_off,
                            title: tr(
                              c,
                              data.projects.isEmpty
                                  ? 'لا توجد مشاريع منشورة بعد'
                                  : 'مفيش نتائج مطابقة',
                              data.projects.isEmpty
                                  ? 'No published projects yet'
                                  : 'No matching projects',
                            ),
                            description: tr(
                              c,
                              data.projects.isEmpty
                                  ? 'المشاريع هتظهر هنا بمجرد نشرها.'
                                  : 'جرّب بحثًا آخر أو امسح الفلاتر.',
                              data.projects.isEmpty
                                  ? 'Projects will appear here as they are published.'
                                  : 'Try another search or clear the filters.',
                            ),
                            action: data.projects.isEmpty
                                ? null
                                : TextButton(
                                    onPressed: () => update('', {}),
                                    child: Text(
                                      tr(
                                        c,
                                        'مسح البحث والفلاتر',
                                        'Clear search and filters',
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ];
                  }
                  final width = MediaQuery.sizeOf(c).width;
                  final columns = width > 900
                      ? 3
                      : width > 600
                      ? 2
                      : 1;
                  final visible = rows.take(shown).toList();
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: PublicFrame(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Text(
                          '${rows.length} ${code == 'ar' ? 'مشروع' : 'projects'}',
                          key: const ValueKey('work-count'),
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: (visible.length / columns).ceil(),
                      itemBuilder: (c, row) => PublicFrame(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var col = 0; col < columns; col++) ...[
                              if (col > 0) const SizedBox(width: 24),
                              Expanded(
                                child: row * columns + col < visible.length
                                    ? ProjectCard(
                                        project: visible[row * columns + col],
                                        endpoint: data.endpoint,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (shown < rows.length)
                      SliverToBoxAdapter(
                        child: PublicFrame(
                          child: OutlinedButton(
                            onPressed: () => setState(() => shown += 12),
                            child: Text(tr(c, 'عرض المزيد', 'Show more')),
                          ),
                        ),
                      ),
                  ];
                },
                orElse: () => <Widget>[],
              ),
          const SliverToBoxAdapter(child: PublicFooter()),
        ],
      ),
    );
  }
}

class ProjectPage extends ConsumerStatefulWidget {
  final String id;
  final bool privatePreview;
  const ProjectPage({super.key, required this.id, this.privatePreview = false});
  @override
  ConsumerState<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends ConsumerState<ProjectPage> {
  String? selectedVideo;
  @override
  void didUpdateWidget(ProjectPage old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) selectedVideo = null;
  }

  @override
  Widget build(BuildContext c) => PublicList(
    children: [
      ContentState(
        builder: (data) {
          final rows = data.projects.where(
            (p) => p.id == widget.id || p.content.slug == widget.id,
          );
          if (rows.isEmpty) {
            return PublicFrame(
              child: PublicMessage(
                icon: Icons.link_off,
                title: tr(c, 'المشروع غير متاح', 'Project unavailable'),
                description: tr(
                  c,
                  'قد يكون الرابط غير صحيح أو تم إلغاء نشر المشروع.',
                  'This link may be incorrect or the project is no longer published.',
                ),
                action: OutlinedButton(
                  onPressed: () => widget.privatePreview
                      ? c.go('/admin/projects')
                      : publicGo(c, '/work'),
                  child: Text(tr(c, 'كل الأعمال', 'All work')),
                ),
              ),
            );
          }
          final project = rows.first;
          final content = project.content;
          final code = Localizations.localeOf(c).languageCode;
          final videos = project.assets
              .where((a) => (a['mime'] as String).startsWith('video/'))
              .toList();
          final attachments = project.assets
              .where((a) => a['mime'] == 'application/pdf')
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PublicFrame(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () {
                      if (c.canPop()) {
                        c.pop();
                      } else {
                        Uri? back;
                        try {
                          back = Uri.tryParse(
                            utf8.decode(
                              base64Url.decode(
                                GoRouterState.of(
                                      c,
                                    ).uri.queryParameters['return'] ??
                                    '',
                              ),
                            ),
                          );
                        } on FormatException {
                          // Invalid return context falls back to the catalogue.
                        }
                        if (back != null &&
                            back.scheme.isEmpty &&
                            back.host.isEmpty &&
                            ['/', '/work'].contains(back.path)) {
                          publicGo(c, back.path, {
                            ...back.queryParameters,
                            'lang': Localizations.localeOf(c).languageCode,
                          });
                        } else {
                          publicGo(c, '/work');
                        }
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: Text(tr(c, 'العودة للأعمال', 'Back to work')),
                  ),
                ),
              ),
              PublicIntro(
                eyebrow: localized(project.category, code),
                title: localized(content.title, code),
                description: localized(content.summary, code),
              ),
              PublicFrame(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Hero(
                  tag: 'project-${project.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ProjectCover(
                      project: project,
                      endpoint: data.endpoint,
                      height: MediaQuery.sizeOf(c).width < 600 ? 230 : 450,
                      thumbnail: false,
                    ),
                  ),
                ),
              ),
              PublicFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ...content.tags.map(
                          (t) => Chip(label: Text(localized(t, code))),
                        ),
                        if (content.year != null)
                          Chip(label: Text(content.year.toString())),
                      ],
                    ),
                    if (content.problem.complete)
                      CaseSection(
                        title: tr(c, 'المشكلة', 'The challenge'),
                        text: localized(content.problem, code),
                      ),
                    if (content.solution.complete)
                      CaseSection(
                        title: tr(c, 'الحل', 'The solution'),
                        text: localized(content.solution, code),
                      ),
                    CaseSection(
                      title: tr(c, 'عن المشروع', 'About the project'),
                      text: localized(content.body, code),
                    ),
                    if (content.features.isNotEmpty) ...[
                      Text(
                        tr(c, 'الوظائف الأساسية', 'Key features'),
                        style: Theme.of(c).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      ...content.features.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ExcludeSemantics(
                                child: Icon(Icons.check_circle_outline),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(localized(t, code))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    CaseSection(
                      title: tr(c, 'مساهمة الفريق', 'Team contribution'),
                      text: localized(content.contribution, code),
                    ),
                    if (content.technologies.isNotEmpty) ...[
                      Text(
                        tr(c, 'التقنيات المستخدمة', 'Technologies'),
                        style: Theme.of(c).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: content.technologies
                            .map((t) => Chip(label: Text(t)))
                            .toList(),
                      ),
                      const SizedBox(height: 32),
                    ],
                    if (content.links.isNotEmpty) ...[
                      Text(
                        tr(c, 'جرّب المشروع', 'Explore the live project'),
                        style: Theme.of(c).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: content.links
                            .where(
                              (l) => ProjectContent.validUrl(l['url'] ?? ''),
                            )
                            .map(
                              (l) => OutlinedButton.icon(
                                onPressed: () => launchUrl(
                                  Uri.parse(l['url']!),
                                  mode: LaunchMode.externalApplication,
                                ),
                                icon: const Icon(Icons.open_in_new),
                                label: Text(
                                  l[code == 'ar' ? 'labelAr' : 'labelEn']!,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 32),
                    ],
                    ProjectGallery(project: project, endpoint: data.endpoint),
                    if (videos.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Text(
                        tr(c, 'شاهد التجربة', 'Watch the experience'),
                        style: Theme.of(c).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: videos
                            .map(
                              (v) => OutlinedButton.icon(
                                onPressed: () => setState(
                                  () => selectedVideo = v['id'] as String,
                                ),
                                icon: const Icon(Icons.play_circle_outline),
                                label: Text(
                                  '${v['mime'] == 'video/mp4' ? 'MP4' : 'WebM'} · '
                                  '${v['name']}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      if (selectedVideo != null)
                        MediaViewer(
                          key: ValueKey(selectedVideo),
                          cache: ref.watch(publicMediaCacheProvider),
                          endpoint: data.endpoint,
                          site: activeSite,
                          asset: videos.firstWhere(
                            (v) => v['id'] == selectedVideo,
                            orElse: () => videos.first,
                          ),
                          cover: project.assets.first,
                        ),
                    ],
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Text(
                        tr(c, 'مرفقات المشروع', 'Project attachments'),
                        style: Theme.of(c).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      ...attachments.map(
                        (a) => MediaViewer(
                          cache: ref.watch(publicMediaCacheProvider),
                          endpoint: data.endpoint,
                          site: activeSite,
                          asset: a,
                        ),
                      ),
                    ],
                    const SizedBox(height: 48),
                    if (!widget.privatePreview)
                      FilledButton.icon(
                        onPressed: () => publicPush(c, '/contact', {
                          'project': project.id,
                          'nameAr': content.title.ar,
                          'nameEn': content.title.en,
                        }),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          tr(
                            c,
                            'اطلب حلًا مشابهًا',
                            'Request a similar solution',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class CaseSection extends StatelessWidget {
  final String title, text;
  const CaseSection({super.key, required this.title, required this.text});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(c).textTheme.headlineMedium),
        const SizedBox(height: 16),
        FormattedProjectText(text),
      ],
    ),
  );
}

class PublicList extends StatelessWidget {
  final List<Widget> children;
  const PublicList({super.key, required this.children});
  @override
  Widget build(BuildContext c) => Focus(
    autofocus: true,
    child: ListView(
      key: PageStorageKey(GoRouterState.of(c).uri.path),
      children: [...children, const PublicFooter()],
    ),
  );
}

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});
  @override
  Widget build(BuildContext c) => PublicList(
    children: [
      PublicIntro(
        eyebrow: tr(c, 'YOGEN / خدماتنا', 'YOGEN / OUR SERVICE'),
        title: tr(
          c,
          'برمجيات مبنية على احتياجك.',
          'Software shaped by your needs.',
        ),
        description: localized(
          serviceText,
          Localizations.localeOf(c).languageCode,
        ),
      ),
      ContentState(
        builder: (data) {
          final text = data.companyText('service');
          return PublicFrame(
            child: PublicMessage(
              icon: Icons.code,
              title: tr(
                c,
                'تطوير تطبيقات حسب الطلب',
                'Custom application development',
              ),
              description: localized(
                text.complete ? text : serviceText,
                Localizations.localeOf(c).languageCode,
              ),
              action: FilledButton(
                onPressed: () => publicGo(c, '/contact'),
                child: Text(
                  tr(c, 'احكيلنا عن فكرتك', 'Tell us about your idea'),
                ),
              ),
            ),
          );
        },
      ),
      PublicFrame(
        child: CaseSection(
          title: tr(c, 'نحدد النطاق معاك', 'Define the scope together'),
          text: tr(
            c,
            'نوع التطبيق ووظائفه والمنصات المطلوبة بيتحددوا حسب هدف المشروع واحتياجات المستخدمين.',
            'The application, its features and target platforms are defined around the project’s goals and users.',
          ),
        ),
      ),
    ],
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext c) => PublicList(
    children: [
      PublicIntro(
        eyebrow: tr(c, 'YOGEN / عنّا', 'YOGEN / ABOUT US'),
        title: tr(
          c,
          'أفكار لمستقبل أكثر إشراقًا.',
          'Ideas for a brighter tomorrow.',
        ),
        description: localized(
          aboutText,
          Localizations.localeOf(c).languageCode,
        ),
      ),
      ContentState(
        builder: (data) {
          final code = Localizations.localeOf(c).languageCode;
          final about = data.companyText('about');
          return PublicFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CaseSection(
                  title: tr(c, 'عن YOGEN', 'About YOGEN'),
                  text: localized(about.complete ? about : aboutText, code),
                ),
                if (data.team.isNotEmpty) ...[
                  Text(
                    tr(c, 'فريقنا', 'Our team'),
                    style: Theme.of(c).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: data.team
                        .map(
                          (member) => SizedBox(
                            width: MediaQuery.sizeOf(c).width < 400
                                ? MediaQuery.sizeOf(c).width - 48
                                : 300,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (member['photo'] != null)
                                  Consumer(
                                    builder: (c, ref, _) => ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: DriveImage(
                                        cache: ref.watch(
                                          publicMediaCacheProvider,
                                        ),
                                        endpoint: data.endpoint,
                                        site: activeSite,
                                        assetId:
                                            member['photo']['id'] as String,
                                        alt:
                                            member['photo']['alt'][code]
                                                as String,
                                        thumbnail: true,
                                        height: 220,
                                      ),
                                    ),
                                  ),
                                PublicMessage(
                                  icon: Icons.person_outline,
                                  title: member['name'][code] as String,
                                  description:
                                      '${member['role'][code]}${(member['bio']?[code] as String? ?? '').isNotEmpty ? '\n${member['bio'][code]}' : ''}',
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: (member['links'] as List? ?? [])
                                      .where(
                                        (v) => ProjectContent.validUrl(
                                          v['url'] as String? ?? '',
                                        ),
                                      )
                                      .map(
                                        (v) => TextButton.icon(
                                          onPressed: () => launchUrl(
                                            Uri.parse(v['url'] as String),
                                            mode:
                                                LaunchMode.externalApplication,
                                          ),
                                          icon: const Icon(Icons.open_in_new),
                                          label: Text(
                                            v[code == 'ar'
                                                    ? 'labelAr'
                                                    : 'labelEn']
                                                as String,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ],
  );
}

class PublicNotFound extends StatelessWidget {
  const PublicNotFound({super.key});
  @override
  Widget build(BuildContext c) => PublicList(
    children: [
      PublicIntro(
        eyebrow: '404 / YOGEN',
        title: tr(c, 'الصفحة غير موجودة', 'Page not found'),
        description: tr(
          c,
          'راجع الرابط أو ارجع للرئيسية.',
          'Check the link or return home.',
        ),
      ),
      PublicFrame(
        child: FilledButton(
          onPressed: () => publicGo(c, '/'),
          child: Text(tr(c, 'الرئيسية', 'Home')),
        ),
      ),
    ],
  );
}
