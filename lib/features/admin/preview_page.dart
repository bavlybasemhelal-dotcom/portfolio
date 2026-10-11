import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart' show tr;
import '../../auth/admin_session.dart';
import '../../data/public_content_repository.dart';
import '../../data/media_settings_repository.dart';
import '../../domain/project.dart';
import '../public/public_pages.dart';
import '../public/project_widgets.dart';
import 'admin_shell.dart';
import 'admin_providers.dart';
import 'projects_pages.dart';

class AdminPreviewRegistry {
  final values = <String, PublicContent>{};
}

final adminPreviewRegistryProvider = Provider((ref) {
  ref.watch(adminSessionProvider.select((v) => v.value?.uid));
  return AdminPreviewRegistry();
});

class PrivatePreviewContent extends PublicContentNotifier {
  final PublicContent value;
  PrivatePreviewContent(this.value);
  @override
  Future<PublicContent> build() async => value;
  @override
  Future<void> refresh() async {
    state = AsyncData(value);
  }
}

class ProjectPreviewPage extends ConsumerStatefulWidget {
  final String id;
  const ProjectPreviewPage({super.key, required this.id});
  @override
  ConsumerState<ProjectPreviewPage> createState() => _ProjectPreviewPageState();
}

class _ProjectPreviewPageState extends ConsumerState<ProjectPreviewPage> {
  PublicContent? data;
  AdminPreviewRegistry? registry;
  Object? error;
  bool mobile = false, card = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    registry?.values.remove(widget.id);
    super.dispose();
  }

  Future<void> load() async {
    try {
      registry = ref.read(adminPreviewRegistryProvider);
      final memory = registry!.values[widget.id];
      if (memory != null) {
        if (mounted) setState(() => data = memory);
        return;
      }
      final repo = await ref.read(adminContentRepositoryProvider.future);
      final draft = await repo.projects.getDraft(widget.id);
      if (draft == null) throw const ContentFailure('project_missing');
      final cat = draft.content.categoryId.isEmpty
          ? null
          : await repo.store.get(
              repo.path('categories', draft.content.categoryId),
            );
      final media = await (await ref.read(
        adminMediaRepositoryProvider.future,
      )).list();
      final value = PublicContent(
        projects: [
          PublicProject(
            widget.id,
            draft.content,
            cat == null
                ? const LocalizedText()
                : LocalizedText.fromMap(
                    Map<String, dynamic>.from(cat.data['name'] as Map),
                  ),
            draft.content.mediaIds
                .map((id) => media.where((m) => m.id == id).firstOrNull)
                .where((m) => m != null)
                .map((m) => Map<String, dynamic>.from(m!.public))
                .toList(),
          ),
        ],
        endpoint: await MediaSettingsRepository.endpoint(repo.store, repo.site),
      );
      if (mounted) setState(() => data = value);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext c) => AdminPage(
    title: tr(c, 'معاينة خاصة', 'Private preview'),
    description: tr(
      c,
      'هذه المعاينة لا تنشر المسودة. بدّل اللغة والمظهر من أعلى اللوحة.',
      'Preview does not publish the draft. Change language and theme from the toolbar.',
    ),
    actions: [
      TextButton.icon(
        onPressed: () =>
            c.canPop() ? c.pop() : c.go('/admin/projects/${widget.id}/edit'),
        icon: const Icon(Icons.edit_outlined),
        label: Text(tr(c, 'عودة للمحرر', 'Back to editor')),
      ),
    ],
    child: error != null
        ? AdminFailure(error!, onRetry: load)
        : data == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ChoiceChip(
                    label: Text(tr(c, 'كمبيوتر', 'Desktop')),
                    selected: !mobile,
                    onSelected: (_) => setState(() => mobile = false),
                  ),
                  ChoiceChip(
                    label: Text(tr(c, 'موبايل', 'Mobile')),
                    selected: mobile,
                    onSelected: (_) => setState(() => mobile = true),
                  ),
                  ChoiceChip(
                    label: Text(tr(c, 'صفحة المشروع', 'Project page')),
                    selected: !card,
                    onSelected: (_) => setState(() => card = false),
                  ),
                  ChoiceChip(
                    label: Text(tr(c, 'بطاقة المشروع', 'Project card')),
                    selected: card,
                    onSelected: (_) => setState(() => card = true),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (c, b) {
                  final width = mobile ? 360.0 : 1280.0;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: width,
                        height: card ? 620 : 760,
                        child: MediaQuery(
                          data: MediaQuery.of(
                            c,
                          ).copyWith(size: Size(width, card ? 620 : 760)),
                          child: ProviderScope(
                            overrides: [
                              publicContentProvider.overrideWith(
                                () => PrivatePreviewContent(data!),
                              ),
                            ],
                            child: Material(
                              color: Theme.of(c).colorScheme.surface,
                              child: card
                                  ? SingleChildScrollView(
                                      child: Center(
                                        child: SizedBox(
                                          width: mobile ? 360 : 440,
                                          child: ProjectCard(
                                            project: data!.projects.first,
                                            endpoint: data!.endpoint,
                                            onOpen: () =>
                                                setState(() => card = false),
                                          ),
                                        ),
                                      ),
                                    )
                                  : ProjectPage(
                                      id: widget.id,
                                      privatePreview: true,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
  );
}
