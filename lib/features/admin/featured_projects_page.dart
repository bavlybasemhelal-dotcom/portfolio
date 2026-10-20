import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/yogen_app.dart' show tr;
import '../../data/public_content_repository.dart';
import 'admin_providers.dart';
import 'admin_shell.dart';
import 'projects_pages.dart' show AdminFailure, operationError;

class FeaturedProjectsPage extends ConsumerStatefulWidget {
  const FeaturedProjectsPage({super.key});
  @override
  ConsumerState<FeaturedProjectsPage> createState() =>
      _FeaturedProjectsPageState();
}

class _FeaturedProjectsPageState extends ConsumerState<FeaturedProjectsPage> {
  final saving = <String>{};
  String? error;

  Future<void> select(String id, bool selected, bool previous) async {
    if (saving.contains(id)) return;
    setState(() {
      saving.add(id);
      error = null;
    });
    try {
      await (await ref.read(
        featuredProjectsRepositoryProvider.future,
      )).select(id, selected, expectedSelected: previous);
      if (!mounted) return;
      ref.invalidate(adminFeaturedIdsProvider);
      await ref.read(adminFeaturedIdsProvider.future);
      if (!mounted) return;
      await ref.read(publicContentProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'اتحفظ اختيارك.', 'Selection saved.')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = operationError(context, e));
        ref.invalidate(adminFeaturedIdsProvider);
      }
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

  void reload() {
    ref.invalidate(adminFeaturedIdsProvider);
    ref.invalidate(publicContentProvider);
  }

  @override
  Widget build(BuildContext c) {
    final content = ref.watch(publicContentProvider);
    final selection = ref.watch(adminFeaturedIdsProvider);
    final code = Localizations.localeOf(c).languageCode;
    return AdminPage(
      title: tr(c, 'اختيار أهم المشاريع', 'Choose featured projects'),
      description: tr(
        c,
        'حدد المشاريع المنشورة التي تظهر في معرض التمرير بالصفحة الرئيسية. كل اختيار يُحفظ فورًا، وباقي الأعمال تظل متاحة في صفحة كل المشاريع.',
        'Choose the published projects shown in the homepage scroll showcase. Each selection saves immediately; all projects remain available on the work page.',
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: saving.isEmpty ? reload : null,
          icon: const Icon(Icons.refresh),
          label: Text(tr(c, 'تحديث', 'Refresh')),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) Semantics(liveRegion: true, child: Text(error!)),
          if (content.hasError || selection.hasError)
            AdminFailure(content.error ?? selection.error!, onRetry: reload)
          else if (!content.hasValue || !selection.hasValue)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text(
              tr(
                c,
                'المختار: ${content.requireValue.projects.where((p) => selection.requireValue.contains(p.id)).length}',
                'Selected: ${content.requireValue.projects.where((p) => selection.requireValue.contains(p.id)).length}',
              ),
            ),
            const SizedBox(height: 16),
            if (content.requireValue.projects.isEmpty)
              Text(
                tr(
                  c,
                  'انشر مشروعًا أولًا لتختاره هنا.',
                  'Publish a project first to feature it here.',
                ),
              ),
            for (final project in content.requireValue.projects)
              Card(
                child: CheckboxListTile(
                  key: ValueKey('featured-${project.id}'),
                  value: selection.requireValue.contains(project.id),
                  onChanged: saving.contains(project.id)
                      ? null
                      : (value) => select(
                          project.id,
                          value!,
                          selection.requireValue.contains(project.id),
                        ),
                  title: Text(localized(project.content.title, code)),
                  subtitle: Text(localized(project.category, code)),
                  secondary: saving.contains(project.id)
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.star_outline),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
