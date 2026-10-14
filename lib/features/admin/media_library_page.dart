import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart';
import '../../auth/admin_session.dart';
import '../../data/media_repository.dart';
import '../../data/media_settings_repository.dart';
import '../../data/project_repository.dart';
import '../../domain/media.dart';
import '../../domain/project.dart';
import '../media/drive_bridge.dart';
import '../media/media_transport.dart';
import '../media/media_preview.dart';
import '../media/thumbnail.dart';

String mediaError(BuildContext c, Object error) {
  final code = error is DriveFailure
      ? error.code
      : error is ContentFailure
      ? error.code
      : '';
  return switch (code) {
    'media_alt_incomplete' => tr(
      c,
      'اكتب وصف الوسيط بالعربية والإنجليزية.',
      'Enter the media description in Arabic and English.',
    ),
    'invalid_project_id' => tr(
      c,
      'استخدم معرفًا ثابتًا بحروف إنجليزية أو أرقام أو _ أو -.',
      'Use a stable ID with English letters, digits, _ or -.',
    ),
    'unsupported_type' || 'signature_mismatch' => tr(
      c,
      'الملف غير صالح لهذا النوع. الصور PNG/JPEG/WebP، والفيديو MP4/WebM، والمرفقات PDF.',
      'The file is invalid for this type. Use PNG/JPEG/WebP images, MP4/WebM video, or PDF attachments.',
    ),
    'unverified_size' || 'file_too_large' => tr(
      c,
      'الحد الحالي 5 MiB للملف. اختار ملفًا أصغر.',
      'The current limit is 5 MiB per file. Choose a smaller file.',
    ),
    'backend_scope_required' || 'backend_permission_required' => tr(
      c,
      'حساب مالك التخزين يحتاج اعتماد صلاحية خدمة الوسائط. راجع دليل الربط.',
      'The storage owner needs to authorize the media backend. See the connection guide.',
    ),
    'selected_file_differs' || 'request_conflict' => tr(
      c,
      'الملف لا يطابق عملية الرفع الأصلية. اختار نفس الملف لاستكمالها.',
      'The file differs from the original upload. Select the same file to resume.',
    ),
    'cover_must_be_image' => tr(
      c,
      'الغلاف يجب أن يكون صورة.',
      'The cover must be an image.',
    ),
    'revision_conflict' => tr(
      c,
      'المشروع اتعدل من جلسة أخرى. حدّث بياناته ثم حاول.',
      'Another session changed the project. Reload it and try again.',
    ),
    'draft_missing' => tr(
      c,
      'معرف المشروع غير موجود. تأكد من اختيار مشروع محفوظ.',
      'The project ID does not exist. Choose a saved project.',
    ),
    'image_dimensions_exceeded' || 'thumbnail_too_large' => tr(
      c,
      'أبعاد الصورة كبيرة للمعاينة الحالية. صغّرها ثم ارفعها.',
      'The image dimensions exceed the preview limits. Resize it before uploading.',
    ),
    _ => tr(
      c,
      'تعذر إكمال العملية. تحقّق من الاتصال والصلاحية، أو استعد حالة الرفع المعلّق.',
      'The operation could not finish. Check connectivity and access, or recover the pending upload.',
    ),
  };
}

class MediaLibraryPage extends ConsumerStatefulWidget {
  final bool showTitle;
  const MediaLibraryPage({super.key, this.showTitle = true});
  @override
  ConsumerState<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends ConsumerState<MediaLibraryPage> {
  final endpoint = TextEditingController(),
      email = TextEditingController(),
      project = TextEditingController(),
      altAr = TextEditingController(),
      altEn = TextEditingController(),
      search = TextEditingController();
  final bridge = DriveBridge();
  late final transport = AppsScriptMediaTransport(bridge);
  late final cache = MediaByteCache(transport);
  List<MediaEntry> entries = [];
  List<UploadOperation> pending = [];
  List<String> bound = [];
  ProjectDraft? draft;
  String scope = 'project', filter = '';
  String Function(BuildContext)? message;
  int visible = 20, generation = 0;
  bool busy = false, loading = true;
  bool settingsLoaded = false;
  UploadStage? stage;
  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  @override
  void dispose() {
    generation++;
    cache.clear();
    bridge.close();
    for (final c in [endpoint, email, project, altAr, altEn, search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<MediaRepository> repository() async {
    final access = ref.read(adminSessionProvider).value;
    if (access?.allowed != true) throw const DriveFailure('upload_not_allowed');
    final auth = await ref.read(accountAuthProvider.future);
    return MediaRepository(
      await ref.read(documentStoreProvider.future),
      transport,
      auth.token,
      actor: access!.uid!,
      site: activeSite,
    );
  }

  Future<void> refresh() async {
    final epoch = ++generation;
    try {
      final repo = await repository();
      final savedEndpoint = await MediaSettingsRepository.endpoint(
        repo.store,
        activeSite,
      );
      final manager = ref.read(adminSessionProvider).value?.manager == true;
      final savedSettings = manager && !settingsLoaded
          ? await MediaSettingsRepository(
              repo.store,
              transport,
              repo.token,
              actor: repo.actor,
              site: activeSite,
            ).get()
          : null;
      final media = await repo.list();
      final operations = await repo.pending();
      if (!mounted || epoch != generation) return;
      setState(() {
        entries = media;
        pending = operations;
        if (endpoint.text.isEmpty) endpoint.text = savedEndpoint;
        if (manager && !settingsLoaded) {
          email.text =
              savedSettings?.data['administrativeEmail'] as String? ?? '';
          settingsLoaded = true;
        }
        loading = false;
      });
    } catch (e) {
      if (mounted && epoch == generation) {
        setState(() {
          message = (c) => mediaError(c, e);
          loading = false;
        });
      }
    }
  }

  Future<void> action(Future<void> Function(MediaRepository) operation) async {
    setState(() {
      busy = true;
      message = null;
      stage = null;
    });
    try {
      await operation(await repository());
    } catch (e) {
      if (mounted) setState(() => message = (c) => mediaError(c, e));
    } finally {
      await refresh();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> selectAndUpload(
    MediaRepository repo, {
    UploadOperation? resume,
  }) async {
    // Check size before requesting bytes; never send an unknown/oversized file.
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'mp4', 'webm', 'pdf'],
    );
    if (picked.isEmpty) return;
    final file = picked.single;
    final size = await file.length();
    MediaPolicy.validateSize(size);
    final buffer = BytesBuilder(copy: false);
    await for (final part in file.readAsByteStream()) {
      buffer.add(part);
      if (buffer.length > MediaPolicy.maxTestBytes) {
        throw const DriveFailure('file_too_large');
      }
    }
    final bytes = buffer.takeBytes();
    if (bytes.length != size) throw const DriveFailure('file_read_failed');
    final mime = MediaPolicy.mime(file.name);
    MediaPolicy.validate(bytes, mime);
    MediaRepository.validateSignature(bytes, mime);
    final thumbnail = mime.startsWith('image/')
        ? await createThumbnail(bytes)
        : null;
    final operation =
        resume ??
        await repo.prepare(
          bytes: bytes,
          name: file.name,
          mime: mime,
          projectId: project.text.trim(),
          scope: scope,
          alt: LocalizedText(ar: altAr.text.trim(), en: altEn.text.trim()),
        );
    if (resume != null) {
      final found = await repo.recover(endpoint.text, resume);
      if (found != null) {
        if (mounted) {
          setState(
            () => message = (c) => tr(
              c,
              'استعدنا نفس الملف وسجلناه.',
              'The same file was recovered and registered.',
            ),
          );
        }
        return;
      }
    }
    await repo.upload(
      endpoint.text,
      operation,
      bytes,
      thumbnail: thumbnail,
      onStage: (s) {
        if (mounted) setState(() => stage = s);
      },
    );
    if (mounted) {
      setState(
        () => message = (c) => tr(
          c,
          'اترفع الملف واتسجل في المكتبة. اربطه بالمشروع قبل النشر.',
          'Uploaded and registered in the library. Link it to a project before publishing.',
        ),
      );
    }
  }

  Future<void> preview(MediaEntry entry) async {
    List<String> users;
    try {
      users = await (await repository()).usages(entry.id);
    } catch (e) {
      if (mounted) setState(() => message = (c) => mediaError(c, e));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(entry.name),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MediaViewer(
                  cache: cache,
                  endpoint: endpoint.text,
                  site: activeSite,
                  asset: entry.public,
                  cover: entries.where((e) => e.image).firstOrNull?.public,
                ),
                const SizedBox(height: 12),
                Text(
                  users.isEmpty
                      ? tr(
                          c,
                          'غير مرتبط بمشروعات حاليًا.',
                          'No project links yet.',
                        )
                      : '${tr(c, 'مستخدم في', 'Used in')}: ${users.join(', ')}',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(c, 'إغلاق', 'Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final access = ref.watch(adminSessionProvider).value;
    if (access?.allowed != true) return const SizedBox.shrink();
    final filtered = entries
        .where(
          (e) =>
              (filter.isEmpty || e.mime.startsWith(filter)) &&
              '${e.name} ${e.alt.ar} ${e.alt.en}'.toLowerCase().contains(
                search.text.toLowerCase(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.showTitle)
              Text(
                tr(c, 'التخزين والوسائط', 'Storage and media'),
                style: Theme.of(c).textTheme.headlineMedium,
              ),
            TextButton(
              onPressed: () => c.go('/admin/verification'),
              child: Text(tr(c, 'مساحة الفريق', 'Team workspace')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            c,
            'صور PNG/JPEG/WebP، فيديو MP4/WebM، وPDF. الحد الحالي 5 MiB للملف. إزالة الارتباط أو الأرشفة تحفظ الملف على Drive.',
            'PNG/JPEG/WebP images, MP4/WebM video and PDF. Current limit: 5 MiB per file. Unlinking or archiving keeps the Drive file.',
          ),
        ),
        const SizedBox(height: 16),
        if (access!.manager)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(c, 'إعدادات الربط', 'Connection settings'),
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endpoint,
                    enabled: !busy,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'Apps Script Web App URL',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: tr(
                        c,
                        'بريد التخزين الإداري — اختياري',
                        'Administrative storage email — optional',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => action((repo) async {
                            await MediaSettingsRepository(
                              repo.store,
                              transport,
                              repo.token,
                              actor: repo.actor,
                              site: activeSite,
                            ).testAndSave(
                              endpoint.text.trim(),
                              administrativeEmail: email.text.trim(),
                            );
                            if (mounted) {
                              setState(
                                () => message = (current) => tr(
                                  current,
                                  'الاتصال ناجح والإعدادات محفوظة.',
                                  'Connection verified and settings saved.',
                                ),
                              );
                            }
                          }),
                    child: Text(
                      tr(c, 'اختبار الاتصال وحفظه', 'Test and save connection'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(c, 'إضافة ملف', 'Add media'),
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: InputDecoration(
                    labelText: tr(c, 'مكان التنظيم', 'Organize under'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'project',
                      child: Text(tr(c, 'مشروع', 'Project')),
                    ),
                    DropdownMenuItem(
                      value: 'brand',
                      child: Text(tr(c, 'هوية الشركة', 'Brand')),
                    ),
                    DropdownMenuItem(
                      value: 'team',
                      child: Text(tr(c, 'الفريق', 'Team')),
                    ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => scope = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: project,
                  enabled: !busy,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr(
                      c,
                      'المعرف الثابت للمشروع أو المادة',
                      'Stable project or material ID',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: altAr,
                  enabled: !busy,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: tr(c, 'الوصف بالعربية', 'Arabic description'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: altEn,
                  enabled: !busy,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: tr(
                      c,
                      'الوصف بالإنجليزية',
                      'English description',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => action((repo) => selectAndUpload(repo)),
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    tr(c, 'اختيار ملف ورفعه', 'Choose and upload file'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          Text(stageLabel(c, stage)),
        ],
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(liveRegion: true, child: Text(message!(c))),
          ),
        if (pending.isNotEmpty) ...[
          Text(
            tr(c, 'عمليات تحتاج استكمالًا', 'Pending uploads'),
            style: Theme.of(c).textTheme.titleLarge,
          ),
          for (final op in pending)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(op.fileName),
                    Text(stageLabel(c, op.stage)),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => action((repo) async {
                              final source = await repo.recover(
                                endpoint.text,
                                op,
                              );
                              if (mounted) {
                                setState(
                                  () => message = (current) => source == null
                                      ? tr(
                                          current,
                                          'الملف لم يكتمل. اختار نفس الملف لاستكمال نفس الطلب.',
                                          'Upload is incomplete. Select the same file to resume the same request.',
                                        )
                                      : tr(
                                          current,
                                          'استعدنا الملف وسجلناه دون رفع جديد.',
                                          'Recovered and registered without uploading again.',
                                        ),
                                );
                              }
                            }),
                      child: Text(
                        tr(c, 'استعادة حالة الرفع', 'Recover upload status'),
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => action(
                              (repo) => selectAndUpload(repo, resume: op),
                            ),
                      child: Text(
                        tr(c, 'استكمال بنفس الملف', 'Resume with same file'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        Text(
          tr(c, 'مكتبة الوسائط', 'Media library'),
          style: Theme.of(c).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {
            visible = 20;
          }),
          decoration: InputDecoration(
            labelText: tr(
              c,
              'بحث بالاسم أو الوصف',
              'Search by name or description',
            ),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final pair in [
              ('', tr(c, 'الكل', 'All')),
              ('image/', tr(c, 'صور', 'Images')),
              ('video/', tr(c, 'فيديو', 'Videos')),
              ('application/', tr(c, 'مرفقات', 'Attachments')),
            ])
              ChoiceChip(
                label: Text(pair.$2),
                selected: filter == pair.$1,
                onSelected: (_) => setState(() {
                  filter = pair.$1;
                  visible = 20;
                }),
              ),
            TextButton(
              onPressed: busy ? null : () => action((_) async {}),
              child: Text(tr(c, 'تحديث المكتبة', 'Refresh library')),
            ),
          ],
        ),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (!loading && filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr(
                c,
                'لا توجد ملفات تطابق البحث.',
                'No media matches this search.',
              ),
            ),
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (c, size) {
            final columns = size.maxWidth >= 1000
                ? 3
                : size.maxWidth >= 650
                ? 2
                : 1;
            final width = (size.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final entry in filtered.take(visible))
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (entry.image)
                              DriveImage(
                                cache: cache,
                                endpoint: endpoint.text,
                                site: activeSite,
                                assetId: entry.id,
                                publicUrl: publicImageUrl(entry.public),
                                alt:
                                    Localizations.localeOf(c).languageCode ==
                                        'ar'
                                    ? entry.alt.ar
                                    : entry.alt.en,
                                thumbnail: true,
                              ),
                            if (!entry.image)
                              SizedBox(
                                height: 120,
                                child: Icon(
                                  entry.video
                                      ? Icons.movie_outlined
                                      : Icons.picture_as_pdf_outlined,
                                  size: 52,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              entry.name,
                              style: Theme.of(c).textTheme.titleMedium,
                            ),
                            Text(
                              '${entry.mime} · ${(entry.bytes / 1024).toStringAsFixed(1)} KiB',
                            ),
                            TextButton(
                              onPressed: () => preview(entry),
                              child: Text(
                                tr(
                                  c,
                                  'معاينة واستخدامات',
                                  'Preview and usages',
                                ),
                              ),
                            ),
                            if (draft != null)
                              TextButton(
                                onPressed: busy || bound.contains(entry.id)
                                    ? null
                                    : () => setState(() => bound.add(entry.id)),
                                child: Text(
                                  tr(
                                    c,
                                    'إضافة للمشروع المحدد',
                                    'Add to selected project',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (filtered.length > visible)
          TextButton(
            onPressed: () => setState(() => visible += 20),
            child: Text(tr(c, 'عرض المزيد', 'Show more')),
          ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    c,
                    'ربط وترتيب وسائط مشروع',
                    'Link and order project media',
                  ),
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                Text(
                  tr(
                    c,
                    'استخدم المعرف المكتوب أعلاه. أول صورة هي الغلاف؛ حد النسخة الحالية 6 ملفات لكل مشروع.',
                    'Use the ID entered above. The first image is the cover; the current snapshot limit is 6 files per project.',
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => action((repo) async {
                          final value = await ProjectRepository(
                            repo.store,
                            actor: repo.actor,
                            site: activeSite,
                          ).getDraft(project.text.trim());
                          if (value == null) {
                            throw const ContentFailure('draft_missing');
                          }
                          if (mounted) {
                            setState(() {
                              draft = value;
                              bound = value.content.mediaIds.toList();
                            });
                          }
                        }),
                  child: Text(
                    tr(c, 'تحميل روابط المشروع', 'Load project links'),
                  ),
                ),
                if (draft != null) ...[
                  Text(
                    '${draft!.id} · ${tr(c, 'إصدار', 'revision')} ${draft!.revision}',
                  ),
                  for (final (index, id) in bound.indexed)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${index == 0 ? tr(c, 'غلاف', 'Cover') : '${index + 1}'}: ${entries.where((v) => v.id == id).firstOrNull?.name ?? id}',
                        ),
                        IconButton(
                          tooltip: tr(c, 'للأعلى', 'Move up'),
                          onPressed: busy || index == 0
                              ? null
                              : () => setState(() {
                                  bound.removeAt(index);
                                  bound.insert(index - 1, id);
                                }),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: tr(c, 'للأسفل', 'Move down'),
                          onPressed: busy || index == bound.length - 1
                              ? null
                              : () => setState(() {
                                  bound.removeAt(index);
                                  bound.insert(index + 1, id);
                                }),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => bound.remove(id)),
                          child: Text(tr(c, 'إزالة الارتباط', 'Unlink')),
                        ),
                      ],
                    ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => action((repo) async {
                            await repo.link(
                              draft!.id,
                              bound,
                              expectedRevision: draft!.revision,
                            );
                            final value = await ProjectRepository(
                              repo.store,
                              actor: repo.actor,
                              site: activeSite,
                            ).getDraft(draft!.id);
                            if (mounted) {
                              setState(() {
                                draft = value;
                                message = (current) => tr(
                                  current,
                                  'الترتيب والغلاف اتحفظوا كمسودة. الملفات المشتركة محفوظة.',
                                  'Order and cover saved to the draft. Shared files are preserved.',
                                );
                              });
                            }
                          }),
                    child: Text(
                      tr(
                        c,
                        'حفظ روابط وترتيب المشروع',
                        'Save project links and order',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String stageLabel(BuildContext c, UploadStage? stage) => switch (stage) {
  UploadStage.prepared => tr(c, 'تجهيز الملف', 'Preparing file'),
  UploadStage.uploading => tr(c, 'رفع الملف', 'Uploading file'),
  UploadStage.uncertain => tr(
    c,
    'حالة غير مؤكدة — استعد نتيجة الطلب أولًا',
    'Outcome unknown — recover the request first',
  ),
  UploadStage.uploaded => tr(
    c,
    'الملف على Drive؛ جارٍ تسجيل المرجع',
    'File is on Drive; registering the reference',
  ),
  UploadStage.registered => tr(
    c,
    'المرجع محفوظ في المكتبة',
    'Reference registered in the library',
  ),
  null => tr(c, 'جارٍ إكمال العملية', 'Completing the operation'),
};
