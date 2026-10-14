import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart' show tr;
import '../../auth/admin_session.dart';
import '../../domain/project.dart';
import '../../data/public_content_repository.dart';
import '../media/media_preview.dart';
import 'admin_shell.dart';
import 'admin_providers.dart';
import 'editor_session.dart';

String newProjectId() => 'p${DateTime.now().microsecondsSinceEpoch}';
String statusText(BuildContext c, ProjectStatus value) => switch (value) {
  ProjectStatus.draft => tr(c, 'مسودة', 'Draft'),
  ProjectStatus.published => tr(c, 'منشور', 'Published'),
  ProjectStatus.archived => tr(c, 'مؤرشف', 'Archived'),
};
String operationError(BuildContext c, Object e) => switch (adminError(e)) {
  'conflict' => tr(
    c,
    'تغير المشروع في جلسة أخرى. حدّث البيانات قبل إعادة الإجراء.',
    'Another session changed this project. Refresh before retrying.',
  ),
  'access' => tr(
    c,
    'الوصول غير متاح. سجّل الدخول بحساب مخول.',
    'Access is unavailable. Sign in with an authorized account.',
  ),
  _ => tr(
    c,
    'العملية لم تتأكد من الخادم. أعد تحميل الحالة قبل المحاولة مجددًا.',
    'The server has not confirmed this operation. Reload its state before retrying.',
  ),
};

class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final access = ref.watch(adminSessionProvider).value;
    final recovery = access?.uid == null
        ? null
        : ref.watch(draftRecoveryProvider(access!.uid!));
    return AdminPage(
      title: tr(c, 'مساحة الفريق', 'Team workspace'),
      description: tr(
        c,
        'كل عمل يبدأ بمسودة، وينشر بعد مراجعة اللغتين والوسائط.',
        'Start with a draft, then review both languages and media before publishing.',
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => c.go('/admin/projects/${newProjectId()}/edit'),
          icon: const Icon(Icons.add),
          label: Text(tr(c, 'إضافة مشروع', 'Add project')),
        ),
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(adminProjectsProvider),
          icon: const Icon(Icons.refresh),
          label: Text(tr(c, 'تحديث', 'Refresh')),
        ),
      ],
      child: ref
          .watch(adminProjectsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => AdminFailure(
              e,
              onRetry: () => ref.invalidate(adminProjectsProvider),
            ),
            data: (projects) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (c, b) => Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: ProjectStatus.values
                        .map(
                          (status) => SizedBox(
                            width: b.maxWidth < 600
                                ? b.maxWidth
                                : (b.maxWidth - 32) / 3,
                            child: AdminSurface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(statusText(c, status)),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${projects.where((p) => p.status == status).length}',
                                    style: Theme.of(c).textTheme.headlineLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                AdminSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(c, 'آخر تحديث', 'Latest update'),
                        style: Theme.of(c).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        projects.isEmpty
                            ? tr(c, 'لا توجد مشاريع بعد.', 'No projects yet.')
                            : projects
                                      .map((p) => p.updatedAt)
                                      .whereType<DateTime>()
                                      .fold<DateTime?>(
                                        null,
                                        (a, b) =>
                                            a == null || b.isAfter(a) ? b : a,
                                      )
                                      ?.toLocal()
                                      .toString() ??
                                  tr(c, 'غير متاح', 'Unavailable'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => c.go('/admin/projects'),
                        child: Text(tr(c, 'إدارة المشاريع', 'Manage projects')),
                      ),
                    ],
                  ),
                ),
                if (recovery != null && recovery.pendingIds.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  AdminSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            c,
                            'مسودات محلية تحتاج استكمالًا',
                            'Local drafts to recover',
                          ),
                          style: Theme.of(c).textTheme.titleLarge,
                        ),
                        Text(
                          tr(
                            c,
                            'لم تؤكد هذه التعديلات على الخادم. افتح المسودة لمراجعتها قبل الحفظ.',
                            'These changes have not been confirmed by the server. Open a draft to review them before saving.',
                          ),
                        ),
                        ...recovery.pendingIds.map(
                          (id) => TextButton(
                            onPressed: () => c.go('/admin/projects/$id/edit'),
                            child: Text(id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: adminNavigation
                      .skip(1)
                      .where((v) => !v.manager || access?.manager == true)
                      .map(
                        (v) => OutlinedButton.icon(
                          onPressed: () => c.go(v.path),
                          icon: Icon(v.icon),
                          label: Text(tr(c, v.ar, v.en)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
    );
  }
}

class AdminFailure extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const AdminFailure(this.error, {super.key, required this.onRetry});
  @override
  Widget build(BuildContext c) => AdminSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined),
        const SizedBox(height: 12),
        Text(operationError(c, error)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(tr(c, 'إعادة المحاولة', 'Retry')),
        ),
      ],
    ),
  );
}

class AdminProjectsPage extends ConsumerStatefulWidget {
  const AdminProjectsPage({super.key});
  @override
  ConsumerState<AdminProjectsPage> createState() => _AdminProjectsPageState();
}

class _AdminProjectsPageState extends ConsumerState<AdminProjectsPage> {
  final search = TextEditingController();
  String status = '', category = '';
  int visible = 20;
  String? busy;
  Object? error;
  bool initial = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initial) {
      initial = true;
      final q = GoRouterState.of(context).uri.queryParameters;
      search.text = q['q'] ?? '';
      status = q['status'] ?? '';
      category = q['category'] ?? '';
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void filter() {
    setState(() => visible = 20);
    final uri = GoRouterState.of(context).uri;
    Router.neglect(
      context,
      () => context.replace(
        uri
            .replace(
              queryParameters: {
                ...uri.queryParameters,
                'q': search.text,
                'status': status,
                'category': category,
              },
            )
            .toString(),
      ),
    );
  }

  Future<void> action(ProjectDraft d, String kind) async {
    if (busy != null) return;
    if (['archive', 'unpublish'].contains(kind)) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(
            kind == 'archive'
                ? tr(c, 'أرشفة المشروع؟', 'Archive project?')
                : tr(c, 'إلغاء النشر؟', 'Unpublish project?'),
          ),
          content: Text(
            tr(
              c,
              'سيختفي من الموقع، وتبقى المسودة وملفات Drive للاستعادة.',
              'It will leave the website. The draft and Drive files remain available.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(c, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(c, 'تأكيد', 'Confirm')),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    if (!mounted) return;
    setState(() {
      busy = d.id;
      error = null;
    });
    try {
      final repo = await ref.read(adminContentRepositoryProvider.future);
      switch (kind) {
        case 'archive':
          await repo.projects.archive(d.id, expectedRevision: d.revision);
        case 'unpublish':
          await repo.projects.unpublish(d.id, expectedRevision: d.revision);
        case 'restore':
          await repo.projects.restore(d.id, expectedRevision: d.revision);
        case 'duplicate':
          final id = newProjectId();
          await repo.duplicate(d.id, id);
          if (mounted) context.go('/admin/projects/$id/edit');
        case 'order':
          if (!mounted) return;
          final control = TextEditingController(text: '${d.content.order}');
          final value = await showDialog<int>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(tr(c, 'ترتيب العرض', 'Display order')),
              content: TextField(
                controller: control,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr(c, 'رقم الترتيب', 'Order number'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(tr(c, 'إلغاء', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, int.tryParse(control.text)),
                  child: Text(tr(c, 'حفظ', 'Save')),
                ),
              ],
            ),
          );
          control.dispose();
          if (value != null) await repo.reorder(d, value);
      }
      ref.invalidate(adminProjectsProvider);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext c) {
    final code = Localizations.localeOf(c).languageCode;
    final cats = ref.watch(adminCategoriesProvider).value ?? [];
    final media = ref.watch(adminMediaEntriesProvider).value ?? [];
    final endpoint = ref.watch(adminEndpointProvider).value ?? '';
    return AdminPage(
      title: tr(c, 'المشاريع', 'Projects'),
      description: tr(
        c,
        'المسودة مستقلة عن النسخة الظاهرة للزائر.',
        'Draft changes are separate from the version visitors see.',
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => c.go('/admin/projects/${newProjectId()}/edit'),
          icon: const Icon(Icons.add),
          label: Text(tr(c, 'إضافة مشروع', 'Add project')),
        ),
        OutlinedButton(
          onPressed: () => ref.invalidate(adminProjectsProvider),
          child: Text(tr(c, 'تحديث', 'Refresh')),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: search,
                  onChanged: (_) => filter(),
                  decoration: InputDecoration(
                    labelText: tr(c, 'البحث في المشاريع', 'Search projects'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(tr(c, 'الكل', 'All')),
                      selected: status.isEmpty,
                      onSelected: (_) {
                        status = '';
                        filter();
                      },
                    ),
                    ...ProjectStatus.values.map(
                      (v) => ChoiceChip(
                        label: Text(statusText(c, v)),
                        selected: status == v.name,
                        onSelected: (_) {
                          status = v.name;
                          filter();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                      cats.any((v) => v.path.split('/').last == category)
                      ? category
                      : '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr(c, 'التصنيف', 'Category'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(tr(c, 'كل التصنيفات', 'All categories')),
                    ),
                    ...cats.map(
                      (v) => DropdownMenuItem(
                        value: v.path.split('/').last,
                        child: Text(v.data['name'][code] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    category = v ?? '';
                    filter();
                  },
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            AdminFailure(
              error!,
              onRetry: () {
                setState(() => error = null);
                ref.invalidate(adminProjectsProvider);
              },
            ),
          ],
          const SizedBox(height: 24),
          ref
              .watch(adminProjectsProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => AdminFailure(
                  e,
                  onRetry: () => ref.invalidate(adminProjectsProvider),
                ),
                data: (all) {
                  final needle = search.text.trim().toLowerCase();
                  final rows = all
                      .where(
                        (d) =>
                            (status.isEmpty || d.status.name == status) &&
                            (category.isEmpty ||
                                d.content.categoryId == category) &&
                            '${d.id} ${d.content.title.ar} ${d.content.title.en}'
                                .toLowerCase()
                                .contains(needle),
                      )
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${rows.length} ${tr(c, 'مشروع', 'projects')}'),
                      const SizedBox(height: 16),
                      if (rows.isEmpty)
                        AdminSurface(
                          child: Text(
                            tr(
                              c,
                              'لا توجد مشاريع مطابقة. أضف أول مشروع أو غيّر البحث.',
                              'No matching projects. Add your first project or change the search.',
                            ),
                          ),
                        ),
                      ...rows
                          .take(visible)
                          .map(
                            (d) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: AdminSurface(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (d.content.mediaIds.isNotEmpty &&
                                        media.any(
                                          (m) =>
                                              m.id ==
                                                  d.content.mediaIds.first &&
                                              m.image,
                                        )) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: DriveImage(
                                          cache: ref.watch(
                                            publicMediaCacheProvider,
                                          ),
                                          endpoint: endpoint,
                                          site: activeSite,
                                          assetId: d.content.mediaIds.first,
                                          publicUrl: publicImageUrl(
                                            media
                                                .firstWhere(
                                                  (m) =>
                                                      m.id ==
                                                      d.content.mediaIds.first,
                                                )
                                                .public,
                                          ),
                                          alt: localized(
                                            media
                                                .firstWhere(
                                                  (m) =>
                                                      m.id ==
                                                      d.content.mediaIds.first,
                                                )
                                                .alt,
                                            code,
                                          ),
                                          thumbnail: true,
                                          height: 160,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    Text(
                                      localized(d.content.title, code).isEmpty
                                          ? d.id
                                          : localized(d.content.title, code),
                                      style: Theme.of(c).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Chip(
                                          label: Text(statusText(c, d.status)),
                                        ),
                                        if (d.status ==
                                                ProjectStatus.published &&
                                            d.hasUnpublishedChanges)
                                          Chip(
                                            label: Text(
                                              tr(
                                                c,
                                                'تعديلات لم تنشر',
                                                'Unpublished changes',
                                              ),
                                            ),
                                          ),
                                        Text(d.id),
                                        if (cats.any(
                                          (v) =>
                                              v.path.split('/').last ==
                                              d.content.categoryId,
                                        ))
                                          Chip(
                                            label: Text(
                                              cats
                                                      .firstWhere(
                                                        (v) =>
                                                            v.path
                                                                .split('/')
                                                                .last ==
                                                            d
                                                                .content
                                                                .categoryId,
                                                      )
                                                      .data['name'][code]
                                                  as String,
                                            ),
                                          ),
                                        Text(
                                          '${tr(c, 'الترتيب', 'Order')}: ${d.content.order}',
                                        ),
                                        if (d.updatedAt != null)
                                          Text(
                                            d.updatedAt!.toLocal().toString(),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.tonal(
                                          onPressed:
                                              busy != null ||
                                                  d.status ==
                                                      ProjectStatus.archived
                                              ? null
                                              : () => c.push(
                                                  '/admin/projects/${d.id}/edit',
                                                ),
                                          child: Text(tr(c, 'تعديل', 'Edit')),
                                        ),
                                        OutlinedButton(
                                          onPressed: busy != null
                                              ? null
                                              : () => c.push(
                                                  '/admin/projects/${d.id}/preview',
                                                ),
                                          child: Text(
                                            tr(
                                              c,
                                              'معاينة خاصة',
                                              'Private preview',
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: busy != null
                                              ? null
                                              : () => action(d, 'duplicate'),
                                          child: Text(
                                            tr(
                                              c,
                                              'تكرار كمسودة',
                                              'Duplicate as draft',
                                            ),
                                          ),
                                        ),
                                        if (d.status !=
                                            ProjectStatus.archived) ...[
                                          TextButton(
                                            onPressed: busy != null
                                                ? null
                                                : () => action(d, 'order'),
                                            child: Text(
                                              tr(c, 'ترتيب', 'Reorder'),
                                            ),
                                          ),
                                          if (d.status ==
                                              ProjectStatus.published)
                                            TextButton(
                                              onPressed: busy != null
                                                  ? null
                                                  : () =>
                                                        action(d, 'unpublish'),
                                              child: Text(
                                                tr(
                                                  c,
                                                  'إلغاء النشر',
                                                  'Unpublish',
                                                ),
                                              ),
                                            ),
                                          TextButton(
                                            onPressed: busy != null
                                                ? null
                                                : () => action(d, 'archive'),
                                            child: Text(
                                              tr(c, 'أرشفة', 'Archive'),
                                            ),
                                          ),
                                        ] else
                                          TextButton(
                                            onPressed: busy != null
                                                ? null
                                                : () => action(d, 'restore'),
                                            child: Text(
                                              tr(
                                                c,
                                                'استعادة كمسودة',
                                                'Restore as draft',
                                              ),
                                            ),
                                          ),
                                        if (busy == d.id)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      if (rows.length > visible)
                        OutlinedButton(
                          onPressed: () => setState(() => visible += 20),
                          child: Text(tr(c, 'عرض المزيد', 'Show more')),
                        ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }
}
