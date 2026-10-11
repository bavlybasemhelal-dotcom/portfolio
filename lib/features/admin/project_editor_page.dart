import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart' show tr;
import '../../auth/admin_session.dart';
import '../../data/media_settings_repository.dart';
import '../../domain/media.dart';
import '../../domain/project.dart';
import '../media/thumbnail.dart';
import '../media/drive_bridge.dart';
import '../media/media_preview.dart';
import '../../data/public_content_repository.dart';
import 'admin_shell.dart';
import 'admin_providers.dart';
import 'editor_session.dart';
import 'draft_guard.dart';
import 'formatted_editor.dart';
import 'projects_pages.dart';
import 'preview_page.dart';
import 'media_library_page.dart' show mediaError;

class ProjectEditorPage extends ConsumerStatefulWidget {
  final String id;
  const ProjectEditorPage({super.key, required this.id});
  @override
  ConsumerState<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends ConsumerState<ProjectEditorPage> {
  final form = GlobalKey<FormState>();
  final controls = <String, TextEditingController>{};
  final fieldKeys = <String, GlobalKey>{};
  ProjectEditorSession? session;
  ProjectDraft? remote;
  Object? loadError, operationFailure;
  bool loading = true,
      externalBusy = false,
      showMissing = false,
      leaving = false;
  String language = 'ar', section = 'basic', endpoint = '';
  List<MediaEntry> media = [];
  List<String> bound = [];
  String category = '', usage = 'unspecified', attribution = 'unspecified';
  DraftBrowserGuard? browserGuard;
  EditorLeaveGuard? guard;
  Future<bool> Function(BuildContext)? exitCallback;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  TextEditingController controller(String key) =>
      controls.putIfAbsent(key, () => TextEditingController());
  void hydrate(ProjectContent content, String note) {
    for (final e in {
      'title': content.title,
      'summary': content.summary,
      'body': content.body,
      'contribution': content.contribution,
      'problem': content.problem,
      'solution': content.solution,
    }.entries) {
      controller('${e.key}.ar').text = e.value.ar;
      controller('${e.key}.en').text = e.value.en;
    }
    controller('slug').text = content.slug;
    controller('year').text = content.year?.toString() ?? '';
    controller('order').text = '${content.order}';
    controller('note').text = note;
    controller('technologies').text = content.technologies.join('\n');
    for (var i = 0; i < 6; i++) {
      for (final name in ['tags', 'features']) {
        final list = name == 'tags' ? content.tags : content.features;
        controller('$name.$i.ar').text = i < list.length ? list[i].ar : '';
        controller('$name.$i.en').text = i < list.length ? list[i].en : '';
      }
    }
    for (var i = 0; i < 6; i++) {
      for (final key in ['url', 'labelAr', 'labelEn']) {
        controller('links.$i.$key').text = i < content.links.length
            ? content.links[i][key] ?? ''
            : '';
      }
    }
    bound = List.of(content.mediaIds);
    category = content.categoryId;
    usage = content.usage;
    attribution = content.attribution;
  }

  LocalizedText pair(String name) => LocalizedText(
    ar: controller('$name.ar').text,
    en: controller('$name.en').text,
  );
  List<LocalizedText> lines(String name) => List.generate(
    6,
    (i) => LocalizedText(
      ar: controller('$name.$i.ar').text,
      en: controller('$name.$i.en').text,
    ),
  ).where((v) => v.ar.isNotEmpty || v.en.isNotEmpty).toList();
  ProjectContent value() => ProjectContent(
    title: pair('title'),
    summary: pair('summary'),
    body: pair('body'),
    contribution: pair('contribution'),
    problem: pair('problem'),
    solution: pair('solution'),
    tags: lines('tags'),
    features: lines('features'),
    technologies: controller(
      'technologies',
    ).text.split('\n').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
    categoryId: category,
    slug: controller('slug').text.trim(),
    usage: usage,
    attribution: attribution,
    order: int.tryParse(controller('order').text) ?? 0,
    year: int.tryParse(controller('year').text),
    mediaIds: List.of(bound),
    links: List.generate(
      6,
      (i) => {
        for (final key in ['url', 'labelAr', 'labelEn'])
          key: controller('links.$i.$key').text.trim(),
      },
    ).where((v) => v.values.any((s) => s.isNotEmpty)).toList(),
  );
  void changed() {
    if (session == null ||
        externalBusy ||
        remote?.status == ProjectStatus.archived) {
      return;
    }
    leaving = false;
    operationFailure = null;
    session!.changed(value(), controller('note').text);
  }

  void redraw() {
    if (mounted) setState(() {});
  }

  Future<void> load({bool recovery = true}) async {
    try {
      final repo = await ref.read(adminContentRepositoryProvider.future);
      final draft = await repo.projects.getDraft(widget.id);
      final entries = await (await ref.read(
        adminMediaRepositoryProvider.future,
      )).list();
      final route = await MediaSettingsRepository.endpoint(
        repo.store,
        activeSite,
      );
      if (!mounted) return;
      session?.removeListener(redraw);
      session?.dispose();
      remote = draft;
      session = ProjectEditorSession(
        widget.id,
        repo.projects,
        ref.read(draftRecoveryProvider(repo.actor)),
        draft,
      )..addListener(redraw);
      hydrate(session!.content, session!.note);
      media = entries;
      endpoint = route;
      language = Localizations.localeOf(context).languageCode;
      guard = ref.read(editorLeaveGuardProvider);
      exitCallback = (c) async {
        if (leaving) return true;
        if (ref.read(adminSessionProvider).value?.allowed != true) {
          await session?.persist();
          return true;
        }
        final result = await session!.canLeave(c);
        if (result) leaving = true;
        return result;
      };
      guard!.callback = exitCallback;
      browserGuard?.dispose();
      browserGuard = DraftBrowserGuard(() => session?.dirty == true);
      setState(() {
        loading = false;
        loadError = null;
      });
      final local = session!.recovery.read(widget.id);
      if (recovery && local != null) {
        final use = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(
              tr(
                c,
                'توجد نسخة استكمال محلية',
                'A local recovery draft is available',
              ),
            ),
            content: Text(
              tr(
                c,
                'التعديلات لم تتأكد من الخادم. استعدها لمراجعتها؛ اختلاف الإصدار سيعرض تعارضًا ولن يكتب فوق عمل شخص آخر.',
                'These edits were not confirmed by the server. Recover and review them; a newer server revision will raise a conflict.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(
                  tr(c, 'استخدام المحفوظ على الخادم', 'Use server version'),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(tr(c, 'استكمال التعديلات', 'Recover edits')),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (use == true) {
          session!.restoreRecovery(local);
          hydrate(session!.content, session!.note);
          setState(() {});
        } else if (use == false) {
          await session!.recovery.clear(widget.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = e;
        });
      }
    }
  }

  @override
  void dispose() {
    browserGuard?.dispose();
    if (guard?.callback == exitCallback) guard?.callback = null;
    session?.removeListener(redraw);
    session?.dispose();
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> missing() {
    try {
      value().validatePublication();
      return [];
    } on ContentFailure catch (e) {
      return e.fields.isEmpty ? [e.code] : e.fields;
    }
  }

  Future<void> publish() async {
    setState(() => showMissing = true);
    if (!form.currentState!.validate() || missing().isNotEmpty) return;
    if (session!.busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      externalBusy = true;
      operationFailure = null;
    });
    try {
      if (!await session!.save() || session!.dirty) return;
      session!.revision = await session!.repository.publish(
        widget.id,
        expectedRevision: session!.revision,
      );
      remote = await session!.repository.getDraft(widget.id);
      session!.confirmedAt = remote?.updatedAt;
      ref.invalidate(adminProjectsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'تم نشر النسخة الجديدة من الخادم.',
                'The server confirmed the new published version.',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      operationFailure = e;
    } finally {
      if (mounted) setState(() => externalBusy = false);
    }
  }

  Future<void> preview() async {
    if (session!.dirty) await session!.persist();
    if (!mounted) return;
    final repo = await ref.read(adminContentRepositoryProvider.future);
    final cat = category.isEmpty
        ? null
        : await repo.store.get(repo.path('categories', category));
    final snapshots = bound
        .map((id) => media.where((m) => m.id == id).firstOrNull)
        .whereType<MediaEntry>()
        .map((m) => Map<String, dynamic>.from(m.public))
        .toList();
    ref.read(adminPreviewRegistryProvider).values[widget.id] = PublicContent(
      projects: [
        PublicProject(
          widget.id,
          value(),
          cat == null
              ? const LocalizedText()
              : LocalizedText.fromMap(
                  Map<String, dynamic>.from(cat.data['name'] as Map),
                ),
          snapshots,
        ),
      ],
      endpoint: endpoint,
    );
    if (mounted) context.push('/admin/projects/${widget.id}/preview');
  }

  String fieldLabel(String key) => switch (key) {
    'title' => tr(context, 'عنوان المشروع', 'Project title'),
    'summary' => tr(context, 'وصف مختصر', 'Short summary'),
    'body' => tr(context, 'وصف المشروع', 'Project description'),
    'contribution' => tr(context, 'مساهمة الفريق', 'Team contribution'),
    'problem' => tr(context, 'المشكلة', 'Challenge'),
    'solution' => tr(context, 'الحل', 'Solution'),
    'slug' => tr(context, 'اسم الرابط الثابت', 'Stable URL name'),
    'categoryId' => tr(context, 'التصنيف', 'Category'),
    'cover' => tr(context, 'صورة الغلاف', 'Cover image'),
    'usage' => tr(context, 'حالة الاستخدام', 'Usage'),
    'attribution' => tr(context, 'نسبة العمل', 'Attribution'),
    _ => key,
  };
  Widget input(
    String key,
    String label, {
    int lines = 1,
    int max = 30000,
    bool required = false,
    bool numeric = false,
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: fieldKeys.putIfAbsent(key, () => GlobalKey()),
      controller: controller(key),
      enabled: !externalBusy,
      readOnly: readOnly,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
      maxLength: max,
      keyboardType: numeric ? TextInputType.number : null,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      textDirection: key.endsWith('.ar')
          ? TextDirection.rtl
          : key.endsWith('.en') || key == 'slug'
          ? TextDirection.ltr
          : null,
      decoration: InputDecoration(labelText: label),
      autovalidateMode: showMissing
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      validator: (v) {
        if (showMissing && required && (v ?? '').trim().isEmpty) {
          return tr(context, 'مطلوب قبل النشر', 'Required before publishing');
        }
        if (key == 'slug' &&
            (v ?? '').isNotEmpty &&
            !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v!)) {
          return tr(
            context,
            'حروف إنجليزية صغيرة وأرقام وشرطة بين الكلمات',
            'Lowercase letters, digits and hyphens between words',
          );
        }
        if (key == 'year' &&
            (v ?? '').isNotEmpty &&
            ((int.tryParse(v!) ?? 0) < 1990 || (int.tryParse(v) ?? 0) > 2100)) {
          return tr(context, 'من 1990 إلى 2100', 'From 1990 to 2100');
        }
        return null;
      },
      onChanged: (_) => changed(),
    ),
  );
  Widget selector(
    String label,
    String selected,
    Map<String, String> items,
    void Function(String) set,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$selected'),
      initialValue: items.containsKey(selected) ? selected : items.keys.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: externalBusy
          ? null
          : (v) {
              set(v!);
              changed();
            },
      validator: (v) => showMissing && (v ?? '').isEmpty
          ? tr(context, 'مطلوب قبل النشر', 'Required before publishing')
          : null,
    ),
  );
  Widget languageFields(List<String> keys) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'ar', label: Text('العربية')),
          ButtonSegment(value: 'en', label: Text('English')),
        ],
        selected: {language},
        onSelectionChanged: (v) => setState(() => language = v.first),
      ),
      const SizedBox(height: 20),
      ...keys.map(
        (key) => key == 'body'
            ? FormattedEditor(
                controller: controller('body.$language'),
                label: '${fieldLabel(key)} · ${language.toUpperCase()}',
                onChanged: changed,
                requiredForPublication: showMissing,
              )
            : input(
                '$key.$language',
                '${fieldLabel(key)} · ${language.toUpperCase()}',
                required: ['title', 'summary', 'contribution'].contains(key),
                lines: key == 'title' ? 1 : 3,
              ),
      ),
    ],
  );
  Widget sectionBody() {
    final c = context,
        categories = ref.watch(adminCategoriesProvider).value ?? [];
    return switch (section) {
      'basic' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          languageFields(['title', 'summary']),
          input(
            'slug',
            fieldLabel('slug'),
            max: 80,
            required: true,
            readOnly: (remote?.stableSlug ?? '').isNotEmpty,
          ),
          selector(fieldLabel('categoryId'), category, {
            '': tr(c, 'اختَر تصنيفًا', 'Choose a category'),
            for (final cat in categories)
              cat.path.split('/').last:
                  '${cat.data['name'][Localizations.localeOf(c).languageCode]}${cat.data['enabled'] == true ? '' : tr(c, ' (غير متاح للنشر)', ' (not available for publishing)')}',
          }, (v) => category = v),
          input(
            'year',
            tr(c, 'سنة التنفيذ (اختياري)', 'Year (optional)'),
            numeric: true,
            max: 4,
          ),
          input(
            'order',
            tr(c, 'ترتيب العرض', 'Display order'),
            numeric: true,
            max: 7,
          ),
        ],
      ),
      'details' => languageFields(['body', 'problem', 'solution']),
      'media' => mediaSection(),
      'team' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          languageFields(['contribution']),
          input(
            'technologies',
            tr(
              c,
              'التقنيات: واحدة في كل سطر، حتى 6',
              'Technologies: one per line, up to 6',
            ),
            lines: 4,
            max: 485,
          ),
          ...['tags', 'features'].map(
            (name) => ExpansionTile(
              key: PageStorageKey('editor-${widget.id}-$name'),
              title: Text(
                tr(
                  c,
                  name == 'tags' ? 'الوسوم' : 'الوظائف الأساسية',
                  name == 'tags' ? 'Tags' : 'Key features',
                ),
              ),
              children: List.generate(
                6,
                (i) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      input(
                        '$name.$i.ar',
                        '${tr(c, name == 'tags' ? 'وسم' : 'وظيفة', name == 'tags' ? 'Tag' : 'Feature')} ${i + 1} · AR',
                        max: 600,
                      ),
                      input(
                        '$name.$i.en',
                        '${tr(c, name == 'tags' ? 'وسم' : 'وظيفة', name == 'tags' ? 'Tag' : 'Feature')} ${i + 1} · EN',
                        max: 600,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      'links' => Column(
        children: List.generate(
          6,
          (i) => ExpansionTile(
            key: PageStorageKey('editor-${widget.id}-link-$i'),
            title: Text('${tr(c, 'رابط', 'Link')} ${i + 1}'),
            children: [
              input(
                'links.$i.labelAr',
                tr(c, 'اسم الرابط بالعربية', 'Arabic link label'),
                max: 200,
              ),
              input(
                'links.$i.labelEn',
                tr(c, 'اسم الرابط بالإنجليزية', 'English link label'),
                max: 200,
              ),
              input('links.$i.url', 'HTTPS URL', max: 2048),
            ],
          ),
        ),
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          selector(fieldLabel('usage'), usage, {
            'unspecified': tr(c, 'لم يحدد', 'Not specified'),
            'real': tr(c, 'مستخدمون حقيقيون', 'Real users'),
            'demo': tr(c, 'تجريبي', 'Demo'),
            'personal': tr(c, 'شخصي', 'Personal'),
          }, (v) => usage = v),
          selector(fieldLabel('attribution'), attribution, {
            'unspecified': tr(c, 'لم يحدد', 'Not specified'),
            'company': tr(c, 'باسم YOGEN', 'YOGEN work'),
            'team_previous': tr(
              c,
              'عمل سابق لأعضاء الفريق',
              'Previous team work',
            ),
            'personal': tr(c, 'عمل شخصي', 'Personal work'),
          }, (v) => attribution = v),
          input(
            'note',
            tr(
              c,
              'ملاحظات داخلية — لا تظهر للزوار',
              'Internal notes — hidden from visitors',
            ),
            lines: 4,
            max: 10000,
          ),
          Text(
            tr(
              c,
              'اسم الرابط لا يتغير بعد أول نشر. بيانات المشاركة تعتمد على العنوان والوصف والغلاف؛ الفهرسة النهائية في مرحلة الجودة.',
              'The URL name is fixed after first publication. Sharing content uses the title, summary and cover.',
            ),
          ),
        ],
      ),
    };
  }

  Future<void> refreshMedia() async {
    final entries = await (await ref.read(
      adminMediaRepositoryProvider.future,
    )).list();
    if (mounted) setState(() => media = entries);
  }

  Future<void> chooseMedia() async {
    try {
      await refreshMedia();
      if (!mounted) return;
      final selected = bound.toSet(), search = TextEditingController();
      String kind = '';
      final result = await showDialog<List<String>>(
        context: context,
        builder: (d) => StatefulBuilder(
          builder: (d, set) => AlertDialog(
            title: Text(tr(d, 'اختيار من المكتبة', 'Choose from library')),
            content: SizedBox(
              width: 620,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    onChanged: (_) => set(() {}),
                    decoration: InputDecoration(
                      labelText: tr(d, 'ابحث عن ملف', 'Find a file'),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: ['', 'image/', 'video/', 'application/pdf']
                        .map(
                          (v) => ChoiceChip(
                            label: Text(v.isEmpty ? tr(d, 'الكل', 'All') : v),
                            selected: kind == v,
                            onSelected: (_) => set(() => kind = v),
                          ),
                        )
                        .toList(),
                  ),
                  Expanded(
                    child: ListView(
                      children: media
                          .where(
                            (m) =>
                                (kind.isEmpty || m.mime.startsWith(kind)) &&
                                '${m.name} ${m.alt.ar} ${m.alt.en}'
                                    .toLowerCase()
                                    .contains(search.text.toLowerCase()),
                          )
                          .map(
                            (m) => CheckboxListTile(
                              value: selected.contains(m.id),
                              title: Text(m.name),
                              subtitle: Text(m.mime),
                              onChanged: (v) => set(() {
                                if (v == false) {
                                  selected.remove(m.id);
                                } else if (selected.length < 6) {
                                  selected.add(m.id);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Text('${selected.length} / 6'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d),
                child: Text(tr(d, 'إلغاء', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, selected.toList()),
                child: Text(tr(d, 'استخدام المحدد', 'Use selection')),
              ),
            ],
          ),
        ),
      );
      search.dispose();
      if (result != null && mounted) {
        setState(() => bound = result);
        changed();
      }
    } catch (e) {
      if (mounted) setState(() => operationFailure = e);
    }
  }

  Future<void> upload() async {
    if (bound.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'حد المشروع 6 ملفات. أزل ارتباطًا قبل رفع ملف جديد.',
              'A project supports 6 files. Unlink one before uploading another.',
            ),
          ),
        ),
      );
      return;
    }
    final ar = TextEditingController(), en = TextEditingController();
    final key = GlobalKey<FormState>();
    final descriptions = await showDialog<LocalizedText>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          tr(d, 'وصف الملف قبل الرفع', 'Describe the file before upload'),
        ),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ar,
                maxLength: 30000,
                decoration: InputDecoration(
                  labelText: tr(d, 'الوصف بالعربية', 'Arabic description'),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? tr(d, 'مطلوب', 'Required')
                    : null,
              ),
              TextFormField(
                controller: en,
                maxLength: 30000,
                decoration: InputDecoration(
                  labelText: tr(d, 'الوصف بالإنجليزية', 'English description'),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? tr(d, 'مطلوب', 'Required')
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(tr(d, 'إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(d, LocalizedText(ar: ar.text, en: en.text));
              }
            },
            child: Text(tr(d, 'اختيار الملف', 'Select file')),
          ),
        ],
      ),
    );
    ar.dispose();
    en.dispose();
    if (descriptions == null) return;
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'mp4', 'webm', 'pdf'],
      );
      if (selection.isEmpty || !mounted) return;
      final file = selection.single;
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
      setState(() {
        externalBusy = true;
        operationFailure = null;
      });
      try {
        final repo = await ref.read(adminMediaRepositoryProvider.future);
        final operation = await repo.prepare(
          bytes: bytes,
          name: file.name,
          mime: mime,
          projectId: widget.id,
          alt: descriptions,
        );
        final source = await repo.upload(
          endpoint,
          operation,
          bytes,
          thumbnail: mime.startsWith('image/')
              ? await createThumbnail(bytes)
              : null,
        );
        await refreshMedia();
        if (bound.length < 6) {
          bound.add(source.assetId);
        }
        if (mounted) {
          setState(() => externalBusy = false);
          changed();
        }
      } catch (e) {
        if (mounted) {
          setState(() => operationFailure = e);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(mediaError(context, e))));
        }
      } finally {
        if (mounted) setState(() => externalBusy = false);
      }
    } catch (e) {
      if (mounted) setState(() => operationFailure = e);
    }
  }

  void move(int from, int to) {
    final next = List<String>.of(bound), id = next.removeAt(from);
    next.insert(to, id);
    final first = media.where((m) => m.id == next.first).firstOrNull;
    if (first?.image != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'الغلاف يجب أن يكون صورة.',
              'The cover must be an image.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => bound = next);
    changed();
  }

  Future<void> describe(MediaEntry m) async {
    final ar = TextEditingController(text: m.alt.ar),
        en = TextEditingController(text: m.alt.en);
    final next = await showDialog<LocalizedText>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr(d, 'وصف الوسيط', 'Media description')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ar,
              decoration: const InputDecoration(labelText: 'AR'),
            ),
            TextField(
              controller: en,
              decoration: const InputDecoration(labelText: 'EN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(tr(d, 'إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(d, LocalizedText(ar: ar.text, en: en.text)),
            child: Text(tr(d, 'حفظ الوصف', 'Save description')),
          ),
        ],
      ),
    );
    ar.dispose();
    en.dispose();
    if (next == null) return;
    try {
      await (await ref.read(
        adminMediaRepositoryProvider.future,
      )).updateAlt(m, next);
      await refreshMedia();
      changed();
    } catch (e) {
      if (mounted) setState(() => operationFailure = e);
    }
  }

  Widget mediaSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        tr(
          context,
          'أول ملف هو الغلاف. حتى 6 ملفات للمشروع و5 MiB للملف؛ ترتيب الصورة ووصفها يظهران بعد نشر النسخة.',
          'The first file is the cover. Up to 6 files per project, 5 MiB each. Media order and descriptions become public after publication.',
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.tonalIcon(
            onPressed: externalBusy ? null : upload,
            icon: const Icon(Icons.upload_file),
            label: Text(tr(context, 'رفع ملف', 'Upload file')),
          ),
          OutlinedButton.icon(
            onPressed: externalBusy ? null : chooseMedia,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              tr(context, 'اختيار من المكتبة', 'Choose from library'),
            ),
          ),
          TextButton(
            onPressed: externalBusy ? null : refreshMedia,
            child: Text(tr(context, 'تحديث المكتبة', 'Refresh library')),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (bound.isEmpty)
        Text(
          tr(
            context,
            'اختَر صورة غلاف قبل النشر.',
            'Choose a cover before publishing.',
          ),
        ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: bound.length,
        onReorder: (a, b) {
          if (b > a) b--;
          move(a, b);
        },
        itemBuilder: (c, i) {
          final entry = media.where((m) => m.id == bound[i]).firstOrNull;
          return Padding(
            key: ValueKey(bound[i]),
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry?.name ?? bound[i],
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                  if (i == 0) Chip(label: Text(tr(c, 'الغلاف', 'Cover'))),
                  if (entry?.image == true)
                    DriveImage(
                      cache: ref.watch(publicMediaCacheProvider),
                      endpoint: endpoint,
                      site: activeSite,
                      assetId: entry!.id,
                      alt: entry.alt.ar,
                      thumbnail: true,
                      height: 140,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Tooltip(
                          message: tr(
                            c,
                            'اسحب لترتيب الوسيط',
                            'Drag to reorder',
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_indicator),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr(c, 'لأعلى', 'Move up'),
                        onPressed: i == 0 ? null : () => move(i, i - 1),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: tr(c, 'لأسفل', 'Move down'),
                        onPressed: i == bound.length - 1
                            ? null
                            : () => move(i, i + 1),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      if (entry?.image == true && i > 0)
                        TextButton(
                          onPressed: () => move(i, 0),
                          child: Text(tr(c, 'اختيار كغلاف', 'Set as cover')),
                        ),
                      if (entry != null)
                        TextButton(
                          onPressed: () => describe(entry),
                          child: Text(tr(c, 'تعديل الوصف', 'Edit description')),
                        ),
                      TextButton(
                        onPressed: () {
                          setState(() => bound.removeAt(i));
                          changed();
                        },
                        child: Text(tr(c, 'إزالة الارتباط', 'Unlink')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
  Future<void> copyRecovery() async {
    final id = newProjectId();
    final repo = await ref.read(adminContentRepositoryProvider.future);
    final copy = ProjectContent.fromMap({...value().toMap(), 'slug': ''});
    try {
      await repo.projects.saveDraft(
        id,
        copy,
        expectedRevision: 0,
        internalNote: controller('note').text,
      );
      await session!.persist();
      leaving = true;
      if (mounted) context.go('/admin/projects/$id/edit');
      ref.invalidate(adminProjectsProvider);
    } catch (e) {
      if (mounted) setState(() => operationFailure = e);
    }
  }

  Future<void> reloadRemote() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'تحميل نسخة الخادم؟', 'Load the server version?')),
        content: Text(
          tr(
            c,
            'سيستبدل محتوى المحرر ويزيل نسخة الاستكمال المحلية. احفظ تعديلاتك كمشروع جديد أولًا إذا كنت تحتاجها.',
            'This replaces the editor and removes its local recovery copy. Save your edits as a new project first if you need them.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr(c, 'إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr(c, 'تحميل الخادم', 'Load server')),
          ),
        ],
      ),
    );
    if (yes == true) {
      session!.dirty = false;
      session!.autosave?.cancel();
      await session!.recovery.clear(widget.id);
      setState(() => loading = true);
      await load(recovery: false);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (loading) {
      return AdminPage(
        title: tr(c, 'محرر المشروع', 'Project editor'),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (loadError != null) {
      return AdminPage(
        title: tr(c, 'محرر المشروع', 'Project editor'),
        child: AdminFailure(loadError!, onRetry: () => load()),
      );
    }
    final s = session!, error = operationFailure ?? s.failure;
    final archived = remote?.status == ProjectStatus.archived;
    final state = s.busy
        ? tr(c, 'جارٍ الحفظ على الخادم…', 'Saving to the server…')
        : s.dirty
        ? tr(
            c,
            'تعديلات لم تتأكد من الخادم',
            'Changes not confirmed by the server',
          )
        : s.confirmedAt == null
        ? tr(c, 'لم تحفظ مسودة بعد', 'No draft saved yet')
        : '${tr(c, 'آخر حفظ مؤكد', 'Last confirmed save')}: ${s.confirmedAt!.toLocal()}';
    final sections = {
      'basic': tr(c, 'الأساسيات', 'Basics'),
      'details': tr(c, 'التفاصيل', 'Details'),
      'media': tr(c, 'الوسائط', 'Media'),
      'team': tr(c, 'الفريق والتقنيات', 'Team and technology'),
      'links': tr(c, 'الروابط', 'Links'),
      'publication': tr(c, 'النشر والمشاركة', 'Publication'),
    };
    Widget actions() => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.tonalIcon(
          onPressed: s.busy || externalBusy || archived
              ? null
              : () async {
                  await s.save();
                  ref.invalidate(adminProjectsProvider);
                },
          icon: const Icon(Icons.save_outlined),
          label: Text(tr(c, 'حفظ مسودة', 'Save draft')),
        ),
        OutlinedButton.icon(
          onPressed: externalBusy ? null : preview,
          icon: const Icon(Icons.visibility_outlined),
          label: Text(tr(c, 'معاينة', 'Preview')),
        ),
        FilledButton.icon(
          onPressed: s.busy || externalBusy || archived ? null : publish,
          icon: const Icon(Icons.publish_outlined),
          label: Text(tr(c, 'نشر', 'Publish')),
        ),
      ],
    );
    return AdminPage(
      title: tr(c, 'محرر المشروع', 'Project editor'),
      description: widget.id,
      actions: [
        TextButton.icon(
          onPressed: () async {
            if (await ref.read(editorLeaveGuardProvider).confirm(c) &&
                c.mounted) {
              c.go('/admin/projects');
            }
          },
          icon: const Icon(Icons.arrow_back),
          label: Text(tr(c, 'كل المشاريع', 'All projects')),
        ),
      ],
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(liveRegion: true, child: Text(state)),
                  const SizedBox(height: 12),
                  if (remote?.status == ProjectStatus.published)
                    Text(
                      tr(
                        c,
                        'النسخة المنشورة لن تتغير حتى نشر التعديل.',
                        'The published version stays unchanged until you publish your edits.',
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: ['ar', 'en'].map((code) {
                      final texts = [
                        pair('title'),
                        pair('summary'),
                        pair('body'),
                        pair('contribution'),
                      ];
                      return Chip(
                        label: Text(
                          '${code.toUpperCase()} · ${texts.where((v) => (code == 'ar' ? v.ar : v.en).trim().isNotEmpty).length} / 4 ${tr(c, 'أساسيات', 'basics')}',
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  actions(),
                ],
              ),
            ),
            if (archived) ...[
              const SizedBox(height: 16),
              AdminSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        c,
                        'المشروع مؤرشف. استعده كمسودة قبل التعديل.',
                        'The project is archived. Restore it as a draft before editing.',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await s.repository.restore(
                          widget.id,
                          expectedRevision: s.revision,
                        );
                        await load();
                      },
                      child: Text(tr(c, 'استعادة كمسودة', 'Restore as draft')),
                    ),
                  ],
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 16),
              AdminSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operationError(c, error),
                      style: TextStyle(color: Theme.of(c).colorScheme.error),
                    ),
                    if (adminError(error) == 'conflict') ...[
                      Text(
                        tr(
                          c,
                          'تعديلاتك محفوظة للاستكمال؛ لا يتم استبدال نسخة الشخص الآخر تلقائيًا.',
                          'Your edits remain recoverable; the other session is never overwritten automatically.',
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: copyRecovery,
                            child: Text(
                              tr(
                                c,
                                'حفظ تعديلاتك كمشروع جديد',
                                'Save edits as a new project',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: reloadRemote,
                            child: Text(
                              tr(c, 'تحميل نسخة الخادم', 'Load server version'),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      TextButton(
                        onPressed: s.busy ? null : () => s.save(),
                        child: Text(tr(c, 'إعادة الحفظ', 'Retry save')),
                      ),
                  ],
                ),
              ),
            ],
            if (showMissing && missing().isNotEmpty) ...[
              const SizedBox(height: 16),
              AdminSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        c,
                        'متطلبات النشر الناقصة',
                        'Missing publication requirements',
                      ),
                      style: Theme.of(c).textTheme.titleMedium,
                    ),
                    ...missing().map(
                      (name) => TextButton(
                        onPressed: () {
                          final key = name.split('.').first;
                          setState(() {
                            section = switch (key) {
                              'body' || 'problem' || 'solution' => 'details',
                              'cover' => 'media',
                              'contribution' || 'tags' || 'features' => 'team',
                              'links' => 'links',
                              'usage' || 'attribution' => 'publication',
                              _ => 'basic',
                            };
                            if (name.endsWith('.ar')) language = 'ar';
                            if (name.endsWith('.en')) language = 'en';
                          });
                        },
                        child: Text(
                          '${fieldLabel(name.split('.').first)}${name.contains('.') ? ' · ${name.split('.').last.toUpperCase()}' : ''}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sections.entries
                  .map(
                    (e) => ChoiceChip(
                      label: Text(e.value),
                      selected: section == e.key,
                      onSelected: (_) => setState(() => section = e.key),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            IgnorePointer(
              ignoring: archived || externalBusy,
              child: AdminSurface(child: sectionBody()),
            ),
            const SizedBox(height: 24),
            actions(),
            if (externalBusy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
