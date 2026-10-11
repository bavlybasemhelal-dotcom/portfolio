import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/project.dart';

/// Bounded text formatting: paragraphs, headings, lists, bold and safe HTTPS
/// links. No HTML, scripts or image embeds are interpreted.
class FormattedProjectText extends StatelessWidget {
  final String value;
  const FormattedProjectText(this.value, {super.key});
  List<InlineSpan> inline(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    final tokens = RegExp(
      r'\*\*([^*\n]+)\*\*|\[([^\]\n]+)\]\((https://[^\s)]+)\)',
    );
    var offset = 0;
    for (final m in tokens.allMatches(text)) {
      if (m.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (ProjectContent.validUrl(m.group(3)!)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: TextButton(
              onPressed: () => launchUrl(
                Uri.parse(m.group(3)!),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(m.group(2)!),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: m.group(0)));
      }
      offset = m.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return spans;
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: value.split('\n').map((line) {
        final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
        final list = RegExp(r'^\s*(-|\d+\.)\s+(.+)$').firstMatch(line);
        final text = heading?.group(2) ?? list?.group(2) ?? line;
        final style = heading != null
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.bodyMedium;
        return Padding(
          padding: EdgeInsets.only(bottom: line.trim().isEmpty ? 12 : 8),
          child: Semantics(
            header: heading != null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (list != null) ...[
                  Text(
                    list.group(1) == '-' ? '•' : list.group(1)!,
                    style: style,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text.rich(
                    TextSpan(children: inline(context, text)),
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );
}
