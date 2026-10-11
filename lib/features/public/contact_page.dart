import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/yogen_app.dart' show tr;
import '../../data/public_content_repository.dart';
import '../../domain/contact_request.dart';
import 'contact_session.dart';
import 'project_widgets.dart';
import 'public_shell.dart';
import 'public_pages.dart' show PublicList;

class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});
  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final focus = <String, FocusNode>{};
  final summaryFocus = FocusNode();
  bool invalid = false;
  String? validationLanguage;
  @override
  void initState() {
    super.initState();
    final session = ref.read(contactSessionProvider);
    for (final name in ['name', 'contact', 'details']) {
      fields[name] = TextEditingController(text: session.fields[name] ?? '');
      focus[name] = FocusNode();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (invalid && language != validationLanguage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && invalid) form.currentState?.validate();
      });
    }
    validationLanguage = language;
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    for (final node in focus.values) {
      node.dispose();
    }
    summaryFocus.dispose();
    super.dispose();
  }

  String? validate(BuildContext c, String key, String? raw) {
    final value = raw?.trim() ?? '';
    return switch (key) {
      'name' when value.isEmpty || value.length > 120 => tr(
        c,
        'اكتب اسمك (حتى 120 حرفًا).',
        'Enter your name (up to 120 characters).',
      ),
      'contact' when value.length > 254 || !validContactAddress(value) => tr(
        c,
        'اكتب بريدًا صالحًا أو رقم هاتف دوليًا يبدأ بـ +.',
        'Enter a valid email or an international phone number starting with +.',
      ),
      'details' when value.length < 10 || value.length > 5000 => tr(
        c,
        'اكتب تفاصيل بين 10 و5000 حرف.',
        'Enter between 10 and 5000 characters.',
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext c) {
    final session = ref.watch(contactSessionProvider);
    final query = GoRouterState.of(c).uri.queryParameters;
    final code = Localizations.localeOf(c).languageCode;
    final content = ref.watch(publicContentProvider).value;
    final requested = query['project'];
    final project = content?.projects
        .where((v) => v.id == requested || v.content.slug == requested)
        .firstOrNull;
    final contextMissing =
        requested != null && project == null && session.pending == null;
    final projectData =
        session.pending?.project ??
        (project == null
            ? const {'id': '', 'nameAr': '', 'nameEn': ''}
            : {
                'id': project.id,
                'nameAr': project.content.title.ar,
                'nameEn': project.content.title.en,
              });
    return AnimatedBuilder(
      animation: session,
      builder: (c, _) {
        final locked =
            session.busy ||
            session.pending != null ||
            session.confirmedId != null;
        return PublicList(
          children: [
            PublicIntro(
              eyebrow: tr(c, 'YOGEN / خلّينا نتكلم', 'YOGEN / LET’S TALK'),
              title: tr(
                c,
                'كل مشروع بيبدأ بفكرة.',
                'Every project starts with an idea.',
              ),
              description: tr(
                c,
                'احكيلنا عن اللي محتاج تبنيه، والهدف اللي عايز توصله.',
                'Tell us what you want to build and the goal you want to achieve.',
              ),
            ),
            if (content?.contacts.isNotEmpty == true)
              PublicFrame(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: content!.contacts.entries
                      .map(
                        (e) => OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await launchUrl(
                              Uri.parse(switch (e.key) {
                                'email' => 'mailto:${e.value}',
                                'whatsapp' =>
                                  'https://wa.me/${e.value.substring(1)}',
                                _ => e.value,
                              }),
                              mode: LaunchMode.externalApplication,
                            );
                            if (!ok && c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr(
                                      c,
                                      'تعذر فتح الوسيلة؛ تقدر تنسخها.',
                                      'Could not open this channel; you can copy it.',
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            e.key == 'email'
                                ? Icons.mail_outline
                                : Icons.open_in_new,
                          ),
                          label: Text(
                            e.value,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            PublicFrame(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (projectData['id']!.isNotEmpty) ...[
                        PublicMessage(
                          icon: Icons.link,
                          title: tr(c, 'طلب حل مشابه', 'A similar solution'),
                          description:
                              '${projectData[code == 'ar' ? 'nameAr' : 'nameEn']}\n${tr(c, 'مرجع المشروع', 'Project reference')}: ${projectData['id']}',
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (contextMissing) ...[
                        Text(
                          tr(
                            c,
                            'المشروع المرتبط غير متاح. افتح مشروعًا منشورًا أو ابدأ طلبًا عامًا.',
                            'The linked project is unavailable. Open a published project or start a general request.',
                          ),
                        ),
                        TextButton(
                          onPressed: () => publicGo(c, '/contact'),
                          child: Text(tr(c, 'طلب عام', 'General request')),
                        ),
                      ],
                      if (invalid)
                        Focus(
                          focusNode: summaryFocus,
                          child: Semantics(
                            liveRegion: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(
                                    c,
                                    'راجع الحقول التالية؛ بياناتك محفوظة.',
                                    'Review these fields; your input has been kept.',
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(c).colorScheme.error,
                                  ),
                                ),
                                for (final key in fields.keys)
                                  if (validate(c, key, fields[key]!.text) !=
                                      null)
                                    TextButton(
                                      onPressed: () {
                                        focus[key]!.requestFocus();
                                        Scrollable.ensureVisible(
                                          focus[key]!.context!,
                                        );
                                      },
                                      child: Text(
                                        validate(c, key, fields[key]!.text)!,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      for (final key in fields.keys) ...[
                        TextFormField(
                          controller: fields[key],
                          focusNode: focus[key],
                          enabled: !locked,
                          validator: (v) => validate(c, key, v),
                          maxLength: key == 'name'
                              ? 120
                              : key == 'contact'
                              ? 254
                              : 5000,
                          keyboardType: key == 'contact'
                              ? TextInputType.emailAddress
                              : key == 'details'
                              ? TextInputType.multiline
                              : TextInputType.name,
                          minLines: key == 'details' ? 5 : 1,
                          maxLines: key == 'details' ? 10 : 1,
                          autofillHints: key == 'name'
                              ? const [AutofillHints.name]
                              : key == 'contact'
                              ? const [AutofillHints.email]
                              : null,
                          onChanged: (v) => session.field(key, v),
                          decoration: InputDecoration(
                            labelText: switch (key) {
                              'name' => tr(c, 'اسمك', 'Your name'),
                              'contact' => tr(
                                c,
                                'وسيلة تواصل',
                                'Contact information',
                              ),
                              _ => tr(
                                c,
                                'فكرة المشروع واحتياجاتك',
                                'Project idea and requirements',
                              ),
                            },
                            helperText: key == 'contact'
                                ? tr(
                                    c,
                                    'بريد إلكتروني أو هاتف بالصيغة الدولية.',
                                    'An email address or a phone number in international format.',
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        tr(
                          c,
                          'بياناتك تُرسل لفريق YOGEN فقط للرد على طلبك. تُحفظ المسودة على هذا الجهاز حتى الإرسال أو مسحها.',
                          'Your information is sent to the YOGEN team to respond to your request. A draft stays on this device until submission or clearing.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (session.confirmedId != null)
                        Semantics(
                          liveRegion: true,
                          child: SelectableText(
                            '${tr(c, 'تم استلام طلبك وحفظه للفريق.', 'Your request has been received and saved for the team.')}\n${tr(c, 'رقم الطلب', 'Request reference')}: ${session.confirmedId}',
                          ),
                        ),
                      if (session.pending != null && !session.busy)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            tr(
                              c,
                              'لم يتأكد الاستلام بعد. احتفظنا بالطلب؛ أعد التحقق والإرسال بنفس الرقم دون تكراره.',
                              'Receipt is not confirmed yet. Your request is kept; check and retry with the same reference without duplicating it.',
                            ),
                          ),
                        ),
                      if (session.error != null && session.pending == null)
                        Text(
                          tr(
                            c,
                            'تعذر إرسال الطلب. بياناتك محفوظة؛ راجع الحقول أو أعد المحاولة.',
                            'Could not send your request. Your input is kept; review the fields or retry.',
                          ),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (session.confirmedId == null)
                            FilledButton.icon(
                              onPressed: session.busy || contextMissing
                                  ? null
                                  : () async {
                                      if (session.pending == null &&
                                          !form.currentState!.validate()) {
                                        setState(() => invalid = true);
                                        summaryFocus.requestFocus();
                                        return;
                                      }
                                      setState(() => invalid = false);
                                      await session.send(
                                        ContactInput(
                                          name: fields['name']!.text.trim(),
                                          contact: fields['contact']!.text
                                              .trim(),
                                          details: fields['details']!.text
                                              .trim(),
                                          language: code,
                                          project: projectData,
                                        ),
                                      );
                                    },
                              icon: session.busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined),
                              label: Text(
                                session.busy
                                    ? tr(
                                        c,
                                        'جارٍ التحقق والإرسال…',
                                        'Checking and sending…',
                                      )
                                    : session.pending != null
                                    ? tr(
                                        c,
                                        'التحقق وإعادة المحاولة',
                                        'Check and retry',
                                      )
                                    : tr(c, 'إرسال الطلب', 'Send request'),
                              ),
                            ),
                          if (!session.busy && session.pending == null)
                            OutlinedButton(
                              onPressed: () async {
                                form.currentState?.reset();
                                for (final control in fields.values) {
                                  control.clear();
                                }
                                await session.clear();
                                if (mounted) setState(() => invalid = false);
                              },
                              child: Text(
                                session.confirmedId != null
                                    ? tr(c, 'طلب جديد', 'New request')
                                    : tr(c, 'مسح المسودة', 'Clear draft'),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => Clipboard.setData(
                              ClipboardData(
                                text: [
                                  if (projectData['id']!.isNotEmpty)
                                    '${projectData['nameAr']} / ${projectData['nameEn']} (${projectData['id']})',
                                  ...fields.values.map((v) => v.text),
                                ].join('\n'),
                              ),
                            ),
                            icon: const Icon(Icons.copy),
                            label: Text(tr(c, 'نسخ التفاصيل', 'Copy brief')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
