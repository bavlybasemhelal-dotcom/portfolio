import 'package:flutter/material.dart';
import '../../app/yogen_app.dart' show tr;
import '../../domain/project.dart';

class FormattedEditor extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final bool requiredForPublication;
  const FormattedEditor({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.requiredForPublication = false,
  });
  void insert(String before, [String after = '']) {
    final s = controller.selection;
    final start = s.isValid ? s.start : controller.text.length,
        end = s.isValid ? s.end : controller.text.length;
    final selected = controller.text.substring(start, end);
    controller.value = TextEditingValue(
      text: controller.text.replaceRange(start, end, '$before$selected$after'),
      selection: TextSelection.collapsed(
        offset: start + before.length + selected.length,
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => insert('\n## '),
            icon: const Icon(Icons.title),
            label: Text(tr(c, 'عنوان', 'Heading')),
          ),
          TextButton.icon(
            onPressed: () => insert('**', '**'),
            icon: const Icon(Icons.format_bold),
            label: Text(tr(c, 'عريض', 'Bold')),
          ),
          TextButton.icon(
            onPressed: () => insert('\n- '),
            icon: const Icon(Icons.format_list_bulleted),
            label: Text(tr(c, 'قائمة', 'List')),
          ),
          TextButton.icon(
            onPressed: () => insert('\n1. '),
            icon: const Icon(Icons.format_list_numbered),
            label: Text(tr(c, 'ترقيم', 'Numbered list')),
          ),
          TextButton.icon(
            onPressed: () async {
              final text = TextEditingController(),
                  url = TextEditingController();
              final form = GlobalKey<FormState>();
              final result = await showDialog<String>(
                context: c,
                builder: (d) => AlertDialog(
                  title: Text(tr(d, 'إضافة رابط', 'Insert link')),
                  content: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: text,
                          decoration: InputDecoration(
                            labelText: tr(d, 'نص الرابط', 'Link text'),
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? tr(d, 'مطلوب', 'Required')
                              : null,
                        ),
                        TextFormField(
                          controller: url,
                          decoration: const InputDecoration(
                            labelText: 'HTTPS URL',
                          ),
                          validator: (v) => ProjectContent.validUrl(v ?? '')
                              ? null
                              : tr(
                                  d,
                                  'استخدم رابط HTTPS صالح',
                                  'Use a valid HTTPS URL',
                                ),
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
                        if (form.currentState!.validate()) {
                          Navigator.pop(
                            d,
                            '[${text.text}](${url.text.trim()})',
                          );
                        }
                      },
                      child: Text(tr(d, 'إضافة', 'Insert')),
                    ),
                  ],
                ),
              );
              text.dispose();
              url.dispose();
              if (result != null) insert(result);
            },
            icon: const Icon(Icons.link),
            label: Text(tr(c, 'رابط', 'Link')),
          ),
        ],
      ),
      TextFormField(
        controller: controller,
        autovalidateMode: requiredForPublication
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        validator: (v) => requiredForPublication && (v ?? '').trim().isEmpty
            ? tr(c, 'مطلوب قبل النشر', 'Required before publishing')
            : null,
        minLines: 6,
        maxLines: 14,
        maxLength: 30000,
        decoration: InputDecoration(
          labelText: label,
          helperText: tr(
            c,
            'التنسيق يظهر في المعاينة وصفحة المشروع.',
            'Formatting appears in preview and on the project page.',
          ),
        ),
        onChanged: (_) => onChanged(),
      ),
    ],
  );
}
