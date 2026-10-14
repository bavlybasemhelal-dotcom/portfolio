import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/yogen_app.dart' show tr;
import '../../auth/admin_session.dart' show activeSite;
import '../../data/public_content_repository.dart';
import '../media/media_preview.dart';
import 'public_shell.dart';

class ContentState extends ConsumerWidget {
  final Widget Function(PublicContent) builder;
  const ContentState({super.key, required this.builder});
  @override
  Widget build(BuildContext c, WidgetRef ref) => ref
      .watch(publicContentProvider)
      .when(
        data: builder,
        loading: () => PublicFrame(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(tr(c, 'جاري تحميل المحتوى…', 'Loading content…')),
            ],
          ),
        ),
        error: (_, _) => PublicFrame(
          child: PublicMessage(
            icon: Icons.cloud_off_outlined,
            title: tr(c, 'تعذر تحميل المحتوى', 'Content unavailable'),
            description: tr(
              c,
              'تحقق من اتصالك وأعد المحاولة.',
              'Check your connection and try again.',
            ),
            action: FilledButton.icon(
              onPressed: () =>
                  ref.read(publicContentProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: Text(tr(c, 'إعادة المحاولة', 'Retry')),
            ),
          ),
        ),
      );
}

class PublicMessage extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Widget? action;
  const PublicMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  @override
  Widget build(BuildContext c) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Theme.of(c).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(c).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 32, color: Theme.of(c).colorScheme.primary),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(description),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class ProjectCover extends ConsumerWidget {
  final PublicProject project;
  final String endpoint;
  final double height;
  final bool thumbnail;
  const ProjectCover({
    super.key,
    required this.project,
    required this.endpoint,
    this.height = 220,
    this.thumbnail = true,
  });
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    if (project.assets.isEmpty ||
        !(project.assets.first['mime'] as String).startsWith('image/')) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            tr(
              c,
              'اختَر صورة غلاف للمعاينة',
              'Choose a cover image to preview',
            ),
          ),
        ),
      );
    }
    final asset = project.assets.first;
    return ColoredBox(
      color: Theme.of(c).colorScheme.surfaceContainerLow,
      child: DriveImage(
        cache: ref.watch(publicMediaCacheProvider),
        endpoint: endpoint,
        site: activeSite,
        assetId: asset['id'] as String,
        publicUrl: publicImageUrl(asset),
        alt: asset['alt'][Localizations.localeOf(c).languageCode] as String,
        thumbnail:
            thumbnail &&
            (asset['thumbnailDriveFileId'] as String? ?? '').isNotEmpty,
        height: height,
      ),
    );
  }
}

class ProjectCard extends ConsumerStatefulWidget {
  final PublicProject project;
  final String endpoint;
  final VoidCallback? onOpen;
  const ProjectCard({
    super.key,
    required this.project,
    required this.endpoint,
    this.onOpen,
  });
  @override
  ConsumerState<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<ProjectCard> {
  bool active = false;
  @override
  Widget build(BuildContext c) {
    final code = Localizations.localeOf(c).languageCode;
    final project = widget.project;
    final reduced = reducedMotion(c, ref);
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, .001)
      ..rotateY(active && !reduced ? .035 : 0)
      ..translateByDouble(0, active && !reduced ? -7 : 0, 0, 1);
    // Focus and the action stay outside the decorative perspective transform.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onHover: (v) => setState(() => active = v),
        onFocusChange: (v) => setState(() => active = v),
        onTap: widget.onOpen ?? () => openProject(c, project.id),
        child: Semantics(
          button: true,
          label:
              '${tr(c, 'استكشف المشروع', 'Explore project')}: '
              '${localized(project.content.title, code)}',
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: Duration(milliseconds: reduced ? 0 : 280),
              transform: matrix,
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(c).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? Theme.of(c).colorScheme.primary
                      : Theme.of(c).colorScheme.outlineVariant,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: Theme.of(
                            c,
                          ).colorScheme.primary.withValues(alpha: .13),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                    child: Hero(
                      tag: 'project-${project.id}',
                      child: ProjectCover(
                        project: project,
                        endpoint: widget.endpoint,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localized(project.category, code),
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(c).colorScheme.tertiary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          localized(project.content.title, code),
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          localized(project.content.summary, code),
                          style: TextStyle(
                            color: Theme.of(c).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr(c, 'استكشف المشروع', 'Explore project'),
                                style: TextStyle(
                                  color: Theme.of(c).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ExcludeSemantics(
                              child: Icon(
                                Directionality.of(c) == TextDirection.rtl
                                    ? Icons.arrow_back
                                    : Icons.arrow_forward,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProjectGallery extends ConsumerStatefulWidget {
  final PublicProject project;
  final String endpoint;
  const ProjectGallery({
    super.key,
    required this.project,
    required this.endpoint,
  });
  @override
  ConsumerState<ProjectGallery> createState() => _ProjectGalleryState();
}

class _ProjectGalleryState extends ConsumerState<ProjectGallery> {
  final nodes = <String, FocusNode>{};
  @override
  void dispose() {
    for (final n in nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final images = widget.project.assets
        .where((a) => (a['mime'] as String).startsWith('image/'))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(c, 'صور المشروع', 'Project gallery'),
          style: Theme.of(c).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        ...images.asMap().entries.map((e) {
          final asset = e.value;
          final node = nodes.putIfAbsent(
            asset['id'] as String,
            () => FocusNode(),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DriveImage(
                    cache: ref.watch(publicMediaCacheProvider),
                    endpoint: widget.endpoint,
                    site: activeSite,
                    assetId: asset['id'] as String,
                    publicUrl: publicImageUrl(asset),
                    alt:
                        asset['alt'][Localizations.localeOf(c).languageCode]
                            as String,
                    thumbnail: true,
                    height: 260,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  focusNode: node,
                  key: ValueKey('zoom-${asset['id']}'),
                  icon: const Icon(Icons.zoom_in),
                  label: Text(tr(c, 'تكبير الصورة', 'Enlarge image')),
                  onPressed: () async {
                    await showDialog<void>(
                      context: c,
                      builder: (_) => GalleryDialog(
                        images: images,
                        index: e.key,
                        endpoint: widget.endpoint,
                      ),
                    );
                    if (mounted) node.requestFocus();
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class GalleryDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> images;
  final int index;
  final String endpoint;
  const GalleryDialog({
    super.key,
    required this.images,
    required this.index,
    required this.endpoint,
  });
  @override
  ConsumerState<GalleryDialog> createState() => _GalleryDialogState();
}

class _GalleryDialogState extends ConsumerState<GalleryDialog> {
  late int index = widget.index;
  void move(int d) =>
      setState(() => index = (index + d) % widget.images.length);
  @override
  Widget build(BuildContext c) {
    final asset = widget.images[index];
    final alt = asset['alt'][Localizations.localeOf(c).languageCode] as String;
    final height = (MediaQuery.sizeOf(c).height - 220).clamp(180.0, 650.0);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => move(-1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(c).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${index + 1} / ${widget.images.length} · $alt',
                          maxLines: 2,
                        ),
                      ),
                      IconButton(
                        tooltip: tr(c, 'إغلاق', 'Close'),
                        onPressed: () => Navigator.of(c).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: height,
                    child: InteractiveViewer(
                      key: ValueKey(asset['id']),
                      minScale: 1,
                      maxScale: 4,
                      child: DriveImage(
                        cache: ref.watch(publicMediaCacheProvider),
                        endpoint: widget.endpoint,
                        site: activeSite,
                        assetId: asset['id'] as String,
                        publicUrl: publicImageUrl(asset),
                        alt: alt,
                        height: height,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.images.length > 1
                            ? () => move(-1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: Text(tr(c, 'الصورة السابقة', 'Previous image')),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.images.length > 1
                            ? () => move(1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: Text(tr(c, 'الصورة التالية', 'Next image')),
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
}
