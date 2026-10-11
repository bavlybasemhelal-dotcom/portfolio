import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/data/admin_content_repository.dart';
import 'package:yogen_portfolio/data/company_repository.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/project_repository.dart';
import 'package:yogen_portfolio/domain/project.dart';
import 'package:yogen_portfolio/features/admin/editor_session.dart';
import 'package:yogen_portfolio/features/public/formatted_text.dart';
import 'media_repository_test.dart' show MemoryStore;

class DelayedStore extends MemoryStore {
  bool offline = false;
  Completer<void>? gate;
  @override
  Future<void> commit(List<DocumentWrite> writes) async {
    if (offline) throw const DataFailure('UNAVAILABLE');
    if (gate != null) await gate!.future;
    await super.commit(writes);
  }
}

void main() {
  late DelayedStore store;
  late ProjectRepository repository;
  late DraftRecovery recovery;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = DelayedStore();
    repository = ProjectRepository(store, actor: 'owner');
    recovery = DraftRecovery(
      await SharedPreferences.getInstance(),
      'owner',
      'yogen',
    );
  });
  const first = ProjectContent(
    title: LocalizedText(ar: 'عنوان'),
    problem: LocalizedText(ar: 'مشكلة'),
    tags: [LocalizedText(ar: 'وسم')],
    features: [LocalizedText(en: 'Feature')],
    links: [
      {'url': '', 'labelAr': 'رابط', 'labelEn': ''},
    ],
  );
  const second = ProjectContent(
    title: LocalizedText(ar: 'تعديل', en: 'Edit'),
  );
  test(
    'P07-T03 partial optional content persists and points to missing publication fields',
    () async {
      await repository.saveDraft('project', first, expectedRevision: 0);
      final draft = (await repository.getDraft('project'))!;
      expect(draft.content.toMap(), first.toMap());
      expect(
        first.validatePublication,
        throwsA(
          isA<ContentFailure>().having(
            (e) => e.fields,
            'fields',
            containsAll(['title.en', 'problem', 'tags', 'features', 'links']),
          ),
        ),
      );
    },
  );
  test(
    'P07-T04 offline save never confirms; account-scoped recovery reopens then saves',
    () async {
      final s = ProjectEditorSession('project', repository, recovery, null);
      s.changed(first, 'private');
      store.offline = true;
      expect(await s.save(), false);
      expect(s.dirty, true);
      expect(s.confirmedAt, isNull);
      expect(recovery.read('project'), isNotNull);
      expect(
        DraftRecovery(recovery.storage, 'other', 'yogen').pendingIds,
        isEmpty,
      );
      expect(
        DraftRecovery(recovery.storage, 'owner', 'phase04-test').pendingIds,
        isEmpty,
      );
      final reopened = ProjectEditorSession(
        'project',
        repository,
        recovery,
        null,
      );
      reopened.restoreRecovery(recovery.read('project')!);
      store.offline = false;
      expect(await reopened.save(), true);
      expect(reopened.dirty, false);
      expect(reopened.confirmedAt, isNotNull);
      expect(recovery.read('project'), isNull);
      s.dirty = false;
      s.dispose();
      reopened.dispose();
    },
  );
  test(
    'P07-T05 editor changes arriving during server save retain recovery and require another save',
    () async {
      final s = ProjectEditorSession('project', repository, recovery, null);
      s.changed(first, 'old');
      store.gate = Completer<void>();
      final saving = s.save();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      s.changed(second, 'new');
      store.gate!.complete();
      expect(await saving, true);
      expect(s.dirty, true);
      expect((await repository.getDraft('project'))!.content.title.ar, 'عنوان');
      expect(recovery.read('project')!['content']['title']['ar'], 'تعديل');
      expect(await s.save(), true);
      expect(s.dirty, false);
      expect((await repository.getDraft('project'))!.content.title.ar, 'تعديل');
      s.dispose();
    },
  );
  test(
    'P07-T05 recovery keeps its old revision and refuses overwriting a newer session',
    () async {
      await repository.saveDraft('project', first, expectedRevision: 0);
      final s = ProjectEditorSession(
        'project',
        repository,
        recovery,
        await repository.getDraft('project'),
      );
      s.changed(second, 'local');
      await s.persist();
      await repository.saveDraft(
        'project',
        const ProjectContent(title: LocalizedText(ar: 'شخص آخر')),
        expectedRevision: 1,
      );
      expect(await s.save(), false);
      expect((s.failure as ContentFailure).code, 'revision_conflict');
      expect(
        (await repository.getDraft('project'))!.content.title.ar,
        'شخص آخر',
      );
      expect(recovery.read('project'), isNotNull);
      s.dispose();
    },
  );
  test(
    'P07-T08 duplicate clears stable slug and reuses ordered asset IDs without any transport',
    () async {
      await repository.saveDraft(
        'source',
        const ProjectContent(
          title: LocalizedText(ar: 'عمل'),
          slug: 'source',
          mediaIds: ['image-b', 'image-a'],
        ),
        expectedRevision: 0,
      );
      final admin = AdminContentRepository(store, actor: 'owner');
      await admin.duplicate('source', 'copy');
      final copy = (await repository.getDraft('copy'))!;
      expect(copy.status, ProjectStatus.draft);
      expect(copy.content.slug, isEmpty);
      expect(copy.stableSlug, isEmpty);
      expect(copy.content.mediaIds, ['image-b', 'image-a']);
      expect(
        () => admin.duplicate('source', 'copy'),
        throwsA(isA<ContentFailure>()),
      );
    },
  );
  test(
    'P07-T13 partial profile remains hidden; four complete profiles order/show/hide without auth changes',
    () async {
      final company = CompanyRepository(store, actor: 'owner');
      await company.saveTeamDraft(
        'partial',
        name: const LocalizedText(ar: 'جزئي'),
        role: const LocalizedText(),
      );
      expect(
        () => company.publishTeam('partial'),
        throwsA(isA<ContentFailure>()),
      );
      expect(await store.get('sites/yogen/team/partial'), isNull);
      for (var i = 0; i < 4; i++) {
        await company.saveTeamDraft(
          'member$i',
          name: LocalizedText(ar: 'عضو $i', en: 'Member $i'),
          role: const LocalizedText(ar: 'مطور', en: 'Developer'),
          order: 4 - i,
        );
        await company.publishTeam('member$i');
      }
      expect((await store.list('sites/yogen/team')).length, 4);
      await company.hideTeam('member0');
      expect(await store.get('sites/yogen/teamDrafts/member0'), isNotNull);
      expect(await store.get('sites/yogen/team/member0'), isNull);
      expect(await store.list('sites/yogen/adminUsers'), isEmpty);
    },
  );
  test(
    'P07-T14 empty contacts publish; valid edits/removal require acknowledged publication',
    () async {
      final company = CompanyRepository(store, actor: 'owner');
      const text = LocalizedText(ar: 'وصف', en: 'Description');
      await company.saveCompanyDraft(about: text, service: text);
      await company.publishCompany();
      expect(
        (await store.get('sites/yogen/company/current'))!.data['contacts'],
        isEmpty,
      );
      await company.saveCompanyDraft(
        about: text,
        service: text,
        contacts: {'email': 'qa@example.com', 'whatsapp': '+201234567890'},
      );
      expect(
        (await store.get('sites/yogen/company/current'))!.data['contacts'],
        isEmpty,
      );
      await company.publishCompany();
      expect(
        (await store.get(
          'sites/yogen/company/current',
        ))!.data['contacts'].length,
        2,
      );
      await company.saveCompanyDraft(
        about: text,
        service: text,
        contacts: {'whatsapp': '+201234567890', 'email': ''},
      );
      await company.publishCompany();
      expect(
        (await store.get(
          'sites/yogen/company/current',
        ))!.data['contacts'].containsKey('email'),
        false,
      );
    },
  );
  testWidgets(
    'P07-T02 shared renderer shows headings lists bold safe links and inert markup at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: FormattedProjectText(
                '# عنوان\nفقرة **واضحة**\n- بند\n1. نقطة\n[الرابط](https://example.com)\n<script>alert(1)</script>\n[رفض](javascript:alert(1))',
              ),
            ),
          ),
        ),
      );
      expect(find.text('عنوان'), findsOneWidget);
      expect(find.text('الرابط'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.textContaining('<script>'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
