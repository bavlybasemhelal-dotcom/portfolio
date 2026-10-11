import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/yogen_app.dart' show tr;
import '../../data/document_store.dart';
import '../../data/read_collection.dart';
import '../../data/company_repository.dart';
import '../../data/public_content_repository.dart';
import '../../domain/project.dart';
import '../public/public_pages.dart' show aboutText, serviceText;
import 'admin_shell.dart';
import 'admin_providers.dart';
import 'projects_pages.dart';
import 'access_pages.dart';

Widget managerField(
  BuildContext c,
  TextEditingController control,
  String ar,
  String en, {
  int lines = 1,
  int max = 30000,
  bool number = false,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: TextFormField(
    controller: control,
    minLines: lines,
    maxLines: lines == 1 ? 1 : lines + 2,
    maxLength: max,
    keyboardType: number ? TextInputType.number : null,
    inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
    decoration: InputDecoration(labelText: tr(c, ar, en)),
  ),
);
LocalizedText managerPair(
  Map<String, TextEditingController> controls,
  String key,
) =>
    LocalizedText(ar: controls['$key.ar']!.text, en: controls['$key.en']!.text);
String managementError(BuildContext c, Object e) {
  if (e is ContentFailure) {
    if (e.code.startsWith('profile_') || e.code == 'company_incomplete') {
      return tr(
        c,
        'أكمل الاسم والدور أو النصوص الأساسية باللغتين قبل الإظهار.',
        'Complete the name, role or required company text in both languages before publishing.',
      );
    }
    if (e.code == 'invalid_contact') {
      return '${tr(c, 'تحقق من بيانات التواصل', 'Check contact details')}: ${e.fields.join(', ')}';
    }
    if (e.code == 'invalid_link') {
      return tr(
        c,
        'كل رابط ظاهر يحتاج عنوانًا باللغتين ورابط HTTPS صالحًا.',
        'Each visible link needs labels in both languages and a valid HTTPS URL.',
      );
    }
  }
  return operationError(c, e);
}

class AdminCategoriesPage extends ConsumerWidget {
  const AdminCategoriesPage({super.key});
  Future<void> edit(BuildContext c, WidgetRef ref, StoredDocument? old) async {
    final controls = {
      for (final key in ['id', 'ar', 'en', 'order'])
        key: TextEditingController(
          text: switch (key) {
            'id' => old?.path.split('/').last ?? '',
            'order' => '${old?.data['order'] ?? 0}',
            _ => old?.data['name'][key] as String? ?? '',
          },
        ),
    };
    bool enabled = old?.data['enabled'] == true, busy = false;
    String? error;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: c,
      barrierDismissible: false,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(tr(d, 'بيانات التصنيف', 'Category details')),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: controls['id'],
                        readOnly: old != null,
                        maxLength: 70,
                        decoration: InputDecoration(
                          labelText: tr(d, 'معرف ثابت', 'Stable identifier'),
                        ),
                        validator: (v) =>
                            RegExp(r'^[A-Za-z0-9_-]{1,70}$').hasMatch(v ?? '')
                            ? null
                            : tr(
                                d,
                                'حروف صغيرة وأرقام وشرطة',
                                'Lowercase letters, digits and hyphens',
                              ),
                      ),
                      const SizedBox(height: 16),
                      managerField(
                        d,
                        controls['ar']!,
                        'الاسم بالعربية',
                        'Arabic name',
                      ),
                      managerField(
                        d,
                        controls['en']!,
                        'الاسم بالإنجليزية',
                        'English name',
                      ),
                      managerField(
                        d,
                        controls['order']!,
                        'الترتيب',
                        'Order',
                        number: true,
                        max: 7,
                      ),
                      SwitchListTile(
                        value: enabled,
                        onChanged: busy ? null : (v) => set(() => enabled = v),
                        title: Text(
                          tr(d, 'متاح للنشر', 'Available for publishing'),
                        ),
                      ),
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(d).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(d),
                child: Text(tr(d, 'إلغاء', 'Cancel')),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        set(() => busy = true);
                        try {
                          await (await ref.read(
                            adminContentRepositoryProvider.future,
                          )).saveCategory(
                            controls['id']!.text,
                            LocalizedText(
                              ar: controls['ar']!.text,
                              en: controls['en']!.text,
                            ),
                            order: int.tryParse(controls['order']!.text) ?? 0,
                            enabled: enabled,
                          );
                          ref.invalidate(adminCategoriesProvider);
                          if (d.mounted) Navigator.pop(d);
                        } catch (e) {
                          if (d.mounted) {
                            set(() => error = managementError(d, e));
                          }
                        } finally {
                          if (d.mounted) set(() => busy = false);
                        }
                      },
                child: Text(tr(d, 'حفظ التصنيف', 'Save category')),
              ),
            ],
          ),
        ),
      ),
    );
    for (final v in controls.values) {
      v.dispose();
    }
  }

  @override
  Widget build(BuildContext c, WidgetRef ref) => AdminPage(
    title: tr(c, 'التصنيفات', 'Categories'),
    description: tr(
      c,
      'المعرف يربط التصنيف بالمشاريع. تعطيله يمنع نشر تعديلات جديدة به، ويحافظ على النسخ المنشورة.',
      'The identifier connects projects to a category. Disabling blocks new publication, while existing published snapshots remain intact.',
    ),
    actions: [
      FilledButton.icon(
        onPressed: () => edit(c, ref, null),
        icon: const Icon(Icons.add),
        label: Text(tr(c, 'إضافة تصنيف', 'Add category')),
      ),
      OutlinedButton(
        onPressed: () => ref.invalidate(adminCategoriesProvider),
        child: Text(tr(c, 'تحديث', 'Refresh')),
      ),
    ],
    child: ref
        .watch(adminCategoriesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => AdminFailure(
            e,
            onRetry: () => ref.invalidate(adminCategoriesProvider),
          ),
          data: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isEmpty)
                AdminSurface(
                  child: Text(
                    tr(
                      c,
                      'أضف تصنيفًا قبل نشر أول مشروع.',
                      'Add a category before publishing your first project.',
                    ),
                  ),
                ),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AdminSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.data['name'][Localizations.localeOf(
                                c,
                              ).languageCode]
                              as String,
                          style: Theme.of(c).textTheme.titleLarge,
                        ),
                        Text(
                          '${row.path.split('/').last} · ${row.data['order']} · ${row.data['enabled'] == true ? tr(c, 'متاح', 'Enabled') : tr(c, 'غير متاح', 'Disabled')}',
                        ),
                        TextButton(
                          onPressed: () => edit(c, ref, row),
                          child: Text(tr(c, 'تعديل التصنيف', 'Edit category')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
  );
}

class AdminTeamPage extends ConsumerStatefulWidget {
  const AdminTeamPage({super.key});
  @override
  ConsumerState<AdminTeamPage> createState() => _AdminTeamPageState();
}

class _AdminTeamPageState extends ConsumerState<AdminTeamPage> {
  List<StoredDocument>? rows;
  Set<String> visible = {};
  Object? failure;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    try {
      final repo = await ref.read(adminContentRepositoryProvider.future);
      final values = await Future.wait([
        readCollection(
          repo.store,
          repo.path('teamDrafts', '').replaceFirst(RegExp(r'/$'), ''),
        ),
        readCollection(
          repo.store,
          repo.path('team', '').replaceFirst(RegExp(r'/$'), ''),
        ),
      ]);
      if (mounted) {
        setState(() {
          rows = values[0]
            ..sort(
              (a, b) => (a.data['order'] as num? ?? 0).compareTo(
                b.data['order'] as num? ?? 0,
              ),
            );
          visible = values[1].map((v) => v.path.split('/').last).toSet();
          failure = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => failure = e);
    }
  }

  Future<void> edit(StoredDocument? old) async {
    final id =
        old?.path.split('/').last ??
        'team${DateTime.now().microsecondsSinceEpoch}';
    final controls = {
      for (final key in [
        'name.ar',
        'name.en',
        'role.ar',
        'role.en',
        'bio.ar',
        'bio.en',
        'order',
      ])
        key: TextEditingController(
          text: key == 'order'
              ? '${old?.data['order'] ?? 0}'
              : old?.data[key.split('.').first]?[key.split('.').last]
                        as String? ??
                    '',
        ),
      for (var i = 0; i < 6; i++)
        for (final key in ['labelAr', 'labelEn', 'url'])
          'links.$i.$key': TextEditingController(
            text:
                ((old?.data['links'] as List? ?? []).length > i
                        ? old!.data['links'][i][key]
                        : null)
                    as String? ??
                '',
          ),
    };
    String photo = old?.data['photoId'] as String? ?? '';
    bool busy = false;
    String? error, confirmation;
    String lang = Localizations.localeOf(context).languageCode;
    final media = await (await ref.read(
      adminMediaRepositoryProvider.future,
    )).list();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(tr(d, 'ملف عضو عام', 'Public team profile')),
            content: SizedBox(
              width: 680,
              height: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tr(
                        d,
                        'ملف العرض منفصل عن حساب الدخول. حفظ المسودة لا يظهرها للزوار.',
                        'This profile is separate from the login account. Saving a draft does not make it visible.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ar', label: Text('العربية')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {lang},
                      onSelectionChanged: busy
                          ? null
                          : (v) => set(() => lang = v.first),
                    ),
                    const SizedBox(height: 18),
                    managerField(
                      d,
                      controls['name.$lang']!,
                      lang == 'ar' ? 'الاسم · AR' : 'الاسم · EN',
                      lang == 'ar' ? 'Name · AR' : 'Name · EN',
                    ),
                    managerField(
                      d,
                      controls['role.$lang']!,
                      lang == 'ar' ? 'الدور · AR' : 'الدور · EN',
                      lang == 'ar' ? 'Role · AR' : 'Role · EN',
                    ),
                    managerField(
                      d,
                      controls['bio.$lang']!,
                      lang == 'ar' ? 'نبذة · AR' : 'نبذة · EN',
                      lang == 'ar' ? 'Bio · AR' : 'Bio · EN',
                      lines: 3,
                    ),
                    managerField(
                      d,
                      controls['order']!,
                      'ترتيب العرض',
                      'Display order',
                      number: true,
                      max: 7,
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(photo),
                      initialValue: media.any((v) => v.id == photo && v.image)
                          ? photo
                          : '',
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr(
                          d,
                          'صورة من مكتبة الوسائط',
                          'Photo from media library',
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(tr(d, 'بدون صورة', 'No photo')),
                        ),
                        ...media
                            .where((v) => v.image)
                            .map(
                              (v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(v.name),
                              ),
                            ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => set(() => photo = v ?? ''),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      tr(
                        d,
                        'لرفع صورة جديدة، افتح التخزين والوسائط أولًا.',
                        'Upload a new photo in Storage and media first.',
                      ),
                    ),
                    ...List.generate(
                      6,
                      (i) => ExpansionTile(
                        key: PageStorageKey('team-$id-link-$i'),
                        title: Text('${tr(d, 'رابط', 'Link')} ${i + 1}'),
                        children: [
                          managerField(
                            d,
                            controls['links.$i.labelAr']!,
                            'اسم الرابط · AR',
                            'Link label · AR',
                            max: 200,
                          ),
                          managerField(
                            d,
                            controls['links.$i.labelEn']!,
                            'اسم الرابط · EN',
                            'Link label · EN',
                            max: 200,
                          ),
                          managerField(
                            d,
                            controls['links.$i.url']!,
                            'رابط HTTPS',
                            'HTTPS URL',
                            max: 2048,
                          ),
                        ],
                      ),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(color: Theme.of(d).colorScheme.error),
                      ),
                    if (confirmation != null)
                      Semantics(liveRegion: true, child: Text(confirmation!)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(d),
                child: Text(tr(d, 'إغلاق', 'Close')),
              ),
              ...[false, true].map(
                (publish) => FilledButton.tonal(
                  onPressed: busy
                      ? null
                      : () async {
                          set(() {
                            busy = true;
                            error = null;
                            confirmation = null;
                          });
                          try {
                            final repo = await ref.read(
                              adminCompanyRepositoryProvider.future,
                            );
                            final links =
                                List.generate(
                                      6,
                                      (i) => {
                                        for (final key in [
                                          'labelAr',
                                          'labelEn',
                                          'url',
                                        ])
                                          key: controls['links.$i.$key']!.text,
                                      },
                                    )
                                    .where(
                                      (v) => v.values.any(
                                        (s) => s.trim().isNotEmpty,
                                      ),
                                    )
                                    .toList();
                            await repo.saveTeamDraft(
                              id,
                              name: managerPair(controls, 'name'),
                              role: managerPair(controls, 'role'),
                              bio: managerPair(controls, 'bio'),
                              order: int.tryParse(controls['order']!.text) ?? 0,
                              photoId: photo,
                              links: links,
                            );
                            if (publish) await repo.publishTeam(id);
                            await load();
                            ref.invalidate(publicContentProvider);
                            if (d.mounted) {
                              set(
                                () => confirmation = tr(
                                  d,
                                  publish
                                      ? 'تم إظهار الملف من الخادم.'
                                      : 'تم حفظ المسودة من الخادم.',
                                  publish
                                      ? 'The server confirmed the visible profile.'
                                      : 'The server confirmed the draft.',
                                ),
                              );
                            }
                          } catch (e) {
                            if (d.mounted) {
                              set(() => error = managementError(d, e));
                            }
                          } finally {
                            if (d.mounted) set(() => busy = false);
                          }
                        },
                  child: Text(
                    tr(
                      d,
                      publish ? 'حفظ وإظهار' : 'حفظ مسودة',
                      publish ? 'Save and show' : 'Save draft',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    for (final v in controls.values) {
      v.dispose();
    }
  }

  Future<void> hide(String id) async {
    try {
      await (await ref.read(
        adminCompanyRepositoryProvider.future,
      )).hideTeam(id);
      await load();
      ref.invalidate(publicContentProvider);
    } catch (e) {
      if (mounted) setState(() => failure = e);
    }
  }

  @override
  Widget build(BuildContext c) => AdminPage(
    title: tr(c, 'ملفات الفريق العامة', 'Public team profiles'),
    description: tr(
      c,
      'أضف البيانات عند جاهزيتها؛ عدد الملفات قابل للنمو، والظهور مستقل عن صلاحيات الدخول.',
      'Add profiles when ready. The list can grow, and visibility is independent of login access.',
    ),
    actions: [
      FilledButton.icon(
        onPressed: () => edit(null),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(tr(c, 'إضافة ملف عضو', 'Add team profile')),
      ),
      OutlinedButton(onPressed: load, child: Text(tr(c, 'تحديث', 'Refresh'))),
    ],
    child: failure != null
        ? AdminFailure(failure!, onRetry: load)
        : rows == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows!.isEmpty)
                AdminSurface(
                  child: Text(
                    tr(
                      c,
                      'ملفات الفريق لم تضاف بعد.',
                      'No team profiles have been added.',
                    ),
                  ),
                ),
              ...rows!.map((v) {
                final id = v.path.split('/').last;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AdminSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.data['name'][Localizations.localeOf(c).languageCode]
                                  .toString()
                                  .isEmpty
                              ? id
                              : v
                                    .data['name'][Localizations.localeOf(
                                      c,
                                    ).languageCode]
                                    .toString(),
                          style: Theme.of(c).textTheme.titleLarge,
                        ),
                        Text(
                          '${visible.contains(id) ? tr(c, 'ظاهر', 'Visible') : tr(c, 'مسودة مخفية', 'Hidden draft')} · ${v.data['order']}',
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: () => edit(v),
                              child: Text(tr(c, 'تعديل الملف', 'Edit profile')),
                            ),
                            if (visible.contains(id))
                              TextButton(
                                onPressed: () => hide(id),
                                child: Text(tr(c, 'إخفاء', 'Hide')),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
  );
}

class AdminCompanyPage extends ConsumerStatefulWidget {
  const AdminCompanyPage({super.key});
  @override
  ConsumerState<AdminCompanyPage> createState() => _AdminCompanyPageState();
}

class _AdminCompanyPageState extends ConsumerState<AdminCompanyPage> {
  final controls = {
    for (final key in [
      'about.ar',
      'about.en',
      'service.ar',
      'service.en',
      'email',
      'whatsapp',
      'website',
    ])
      key: TextEditingController(),
  };
  final form = GlobalKey<FormState>();
  bool loading = true, busy = false;
  String lang = 'ar';
  String? confirmation;
  Object? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    for (final v in controls.values) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final repo = await ref.read(adminContentRepositoryProvider.future);
      final draft = await repo.store.get(repo.path('companyDrafts', 'current'));
      for (final key in ['about', 'service']) {
        for (final code in ['ar', 'en']) {
          controls['$key.$code']!.text =
              draft?.data[key]?[code] as String? ??
              localized(key == 'about' ? aboutText : serviceText, code);
        }
      }
      for (final key in ['email', 'whatsapp', 'website']) {
        controls[key]!.text = draft?.data['contacts']?[key] as String? ?? '';
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e;
        });
      }
    }
  }

  Future<void> save(bool publish) async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      confirmation = null;
      error = null;
    });
    try {
      final repo = await ref.read(adminCompanyRepositoryProvider.future);
      await repo.saveCompanyDraft(
        about: managerPair(controls, 'about'),
        service: managerPair(controls, 'service'),
        contacts: {
          for (final k in ['email', 'whatsapp', 'website'])
            k: controls[k]!.text,
        },
      );
      if (publish) await repo.publishCompany();
      ref.invalidate(publicContentProvider);
      if (mounted) {
        setState(
          () => confirmation = tr(
            context,
            publish
                ? 'تم تحديث بيانات الموقع من الخادم.'
                : 'تم حفظ المسودة من الخادم.',
            publish
                ? 'The server confirmed the website update.'
                : 'The server confirmed the draft.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => AdminPage(
    title: tr(c, 'الشركة والتواصل', 'Company and contact'),
    description: tr(
      c,
      'القنوات الفارغة لا تظهر للزوار. حفظ المسودة مستقل عن تحديث الموقع.',
      'Empty channels stay hidden. Saving a draft is separate from updating the website.',
    ),
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : AdminSurface(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ar', label: Text('العربية')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {lang},
                    onSelectionChanged: busy
                        ? null
                        : (v) => setState(() => lang = v.first),
                  ),
                  const SizedBox(height: 24),
                  managerField(
                    c,
                    controls['about.$lang']!,
                    'عن YOGEN · ${lang.toUpperCase()}',
                    'About YOGEN · ${lang.toUpperCase()}',
                    lines: 4,
                  ),
                  managerField(
                    c,
                    controls['service.$lang']!,
                    'الخدمة · ${lang.toUpperCase()}',
                    'Service · ${lang.toUpperCase()}',
                    lines: 3,
                  ),
                  ...['email', 'whatsapp', 'website'].map(
                    (key) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                        controller: controls[key],
                        enabled: !busy,
                        maxLength: key == 'website' ? 2048 : 254,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: switch (key) {
                            'email' => tr(
                              c,
                              'البريد التجاري (اختياري)',
                              'Business email (optional)',
                            ),
                            'whatsapp' => tr(
                              c,
                              'واتساب دولي، مثال +201234567890',
                              'International WhatsApp, e.g. +201234567890',
                            ),
                            _ => tr(
                              c,
                              'رابط الشركة HTTPS (اختياري)',
                              'Company HTTPS URL (optional)',
                            ),
                          },
                        ),
                        validator: (v) {
                          try {
                            CompanyRepository.validContacts({key: v ?? ''});
                            return null;
                          } catch (_) {
                            return tr(
                              c,
                              'أدخل قيمة صالحة أو اتركه فارغًا.',
                              'Enter a valid value or leave it empty.',
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  if (error != null)
                    Text(
                      managementError(c, error!),
                      style: TextStyle(color: Theme.of(c).colorScheme.error),
                    ),
                  if (confirmation != null)
                    Semantics(liveRegion: true, child: Text(confirmation!)),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonal(
                        onPressed: busy ? null : () => save(false),
                        child: Text(tr(c, 'حفظ مسودة', 'Save draft')),
                      ),
                      FilledButton(
                        onPressed: busy ? null : () => save(true),
                        child: Text(
                          tr(c, 'حفظ وتحديث الموقع', 'Save and update website'),
                        ),
                      ),
                    ],
                  ),
                  if (busy) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
  );
}

class AdminAccountsPage extends StatelessWidget {
  const AdminAccountsPage({super.key});
  @override
  Widget build(BuildContext c) => AdminPage(
    title: tr(c, 'حسابات الوصول', 'Access accounts'),
    description: tr(
      c,
      'كل محرر فعّال يستطيع النشر. إدارة الحسابات وربط التخزين للمدير؛ ملفات الفريق العامة تُدار منفصلة.',
      'Every active editor can publish. The manager controls accounts and storage settings. Public team profiles are managed separately.',
    ),
    child: const AdminAccessPage(),
  );
}
