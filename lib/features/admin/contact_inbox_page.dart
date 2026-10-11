import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/yogen_app.dart' show tr;
import '../../auth/admin_session.dart';
import '../../data/contact_repository.dart';
import '../../domain/contact_request.dart';
import 'admin_providers.dart';
import 'admin_shell.dart';
import 'projects_pages.dart';

final adminContactRepositoryProvider = FutureProvider<ContactRepository>((
  ref,
) async {
  final repo = await ref.watch(adminContentRepositoryProvider.future);
  return ContactRepository(repo.store, site: repo.site);
});
final contactInboxProvider = FutureProvider<List<ContactRequest>>(
  (ref) async =>
      (await ref.watch(adminContactRepositoryProvider.future)).inbox(),
  retry: (_, _) => null,
);

String requestStatus(BuildContext c, String status) => switch (status) {
  'new' => tr(c, 'جديد', 'New'),
  'inProgress' => tr(c, 'قيد المتابعة', 'In progress'),
  _ => tr(c, 'مغلق', 'Closed'),
};

class ContactInboxPage extends ConsumerStatefulWidget {
  const ContactInboxPage({super.key});
  @override
  ConsumerState<ContactInboxPage> createState() => _ContactInboxPageState();
}

class _ContactInboxPageState extends ConsumerState<ContactInboxPage> {
  String search = '', status = 'all';
  int page = 0;
  Future<void> edit(ContactRequest request) async {
    final note = TextEditingController(text: request.note);
    var next = request.status;
    final route = DialogRoute<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(tr(c, 'متابعة الطلب', 'Manage request')),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: next,
                    decoration: InputDecoration(
                      labelText: tr(c, 'حالة الطلب', 'Request status'),
                    ),
                    items: ['new', 'inProgress', 'closed']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(requestStatus(c, v)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => next = v!),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: note,
                    maxLength: 5000,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: tr(
                        c,
                        'ملاحظة خاصة للفريق',
                        'Private team note',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(c, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(c, 'حفظ', 'Save')),
            ),
          ],
        ),
      ),
    );
    final save = await Navigator.of(context, rootNavigator: true).push(route);
    final value = note.text;
    // The popped dialog can still render during its exit animation.
    await route.completed;
    note.dispose();
    if (save != true || !mounted) return;
    try {
      final repo = await ref.read(adminContactRepositoryProvider.future);
      final uid = ref.read(adminSessionProvider).value!.uid!;
      await repo.update(request.id, uid, next, value);
      ref.invalidate(contactInboxProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(operationError(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext c) => AdminPage(
    title: tr(c, 'طلبات العملاء', 'Client requests'),
    description: tr(
      c,
      'صندوق خاص للفريق. متابعة الطلب لا ترسل رسالة للعميل تلقائيًا.',
      'A private team inbox. Updating a request does not automatically message the client.',
    ),
    actions: [
      OutlinedButton.icon(
        onPressed: () => ref.invalidate(contactInboxProvider),
        icon: const Icon(Icons.refresh),
        label: Text(tr(c, 'تحديث', 'Refresh')),
      ),
    ],
    child: ref
        .watch(contactInboxProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AdminFailure(
            e,
            onRetry: () => ref.invalidate(contactInboxProvider),
          ),
          data: (rows) {
            final filtered = rows
                .where(
                  (r) =>
                      (status == 'all' || r.status == status) &&
                      ('${r.input.name} ${r.input.contact} ${r.input.details} ${r.id} ${r.input.project.values.join(' ')}')
                          .toLowerCase()
                          .contains(search.toLowerCase()),
                )
                .toList();
            final pages = (filtered.length / 20).ceil().clamp(1, 1000000),
                current = page.clamp(0, pages - 1);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: tr(c, 'بحث الطلبات', 'Search requests'),
                  ),
                  onChanged: (v) => setState(() {
                    search = v;
                    page = 0;
                  }),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['all', 'new', 'inProgress', 'closed']
                      .map(
                        (v) => ChoiceChip(
                          label: Text(
                            v == 'all'
                                ? tr(c, 'كل الحالات', 'All statuses')
                                : requestStatus(c, v),
                          ),
                          selected: status == v,
                          onSelected: (_) => setState(() {
                            status = v;
                            page = 0;
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                Text('${tr(c, 'عدد الطلبات', 'Requests')}: ${filtered.length}'),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr(c, 'لا توجد طلبات مطابقة.', 'No matching requests.'),
                    ),
                  ),
                for (final r in filtered.skip(current * 20).take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AdminSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                r.input.name,
                                style: Theme.of(c).textTheme.titleLarge,
                              ),
                              Chip(label: Text(requestStatus(c, r.status))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            r.input.contact,
                            textDirection: TextDirection.ltr,
                          ),
                          Text(r.createdAt.toLocal().toString()),
                          Text(
                            '${tr(c, 'لغة الطلب', 'Request language')}: ${r.input.language}',
                          ),
                          const SizedBox(height: 12),
                          SelectableText(r.input.details),
                          if (r.input.project['id']!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SelectableText(
                              '${r.input.project['nameAr']} / ${r.input.project['nameEn']}\n${r.input.project['id']}',
                            ),
                          ],
                          if (r.note.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${tr(c, 'ملاحظة الفريق', 'Team note')}: ${r.note}',
                            ),
                          ],
                          const SizedBox(height: 12),
                          SelectableText(
                            '${tr(c, 'رقم الطلب', 'Request reference')}: ${r.id}',
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: OutlinedButton.icon(
                              onPressed: () => edit(r),
                              icon: const Icon(Icons.edit_note),
                              label: Text(
                                tr(c, 'متابعة الطلب', 'Manage request'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: current == 0
                          ? null
                          : () => setState(() => page = current - 1),
                      child: Text(tr(c, 'السابق', 'Previous')),
                    ),
                    Text('${current + 1} / $pages'),
                    OutlinedButton(
                      onPressed: current + 1 >= pages
                          ? null
                          : () => setState(() => page = current + 1),
                      child: Text(tr(c, 'التالي', 'Next')),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
  );
}
