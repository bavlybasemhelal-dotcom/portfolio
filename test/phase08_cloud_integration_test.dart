// Opt-in real cloud operations. Owner credentials never leave .runtime.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/auth/account_auth.dart';
import 'package:yogen_portfolio/data/contact_repository.dart';
import 'package:yogen_portfolio/data/company_repository.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/project_repository.dart';
import 'package:yogen_portfolio/domain/contact_request.dart';
import 'package:yogen_portfolio/domain/project.dart';
import 'package:yogen_portfolio/features/public/public_pages.dart'
    show aboutText, serviceText;
import 'phase07_cloud_integration_test.dart' show CloudVault;

void main() {
  const cloud = bool.fromEnvironment('YOGEN_PHASE08_CLOUD');
  const content = bool.fromEnvironment('YOGEN_PHASE08_CONTENT');
  test(
    'Phase 8 actual private request receipt, retry and manager inbox',
    () async {
      final config = jsonDecode(
        File('config/firebase.web.json').readAsStringSync(),
      );
      final owner = jsonDecode(
        File('.runtime/yogen-owner.local.json').readAsStringSync(),
      );
      final auth = RestAccountAuth(
        FirebaseAuthApi(config['FIREBASE_API_KEY']),
        CloudVault(),
      );
      final staff = FirestoreRestStore(
            projectId: 'portfolio-14d15',
            token: auth.token,
          ),
          anonymous = FirestoreRestStore(
            projectId: 'portfolio-14d15',
            token: () async => null,
          );
      final checks = <Map<String, Object>>[];
      void check(String name, bool ok) {
        expect(ok, true, reason: name);
        checks.add({'name': name, 'ok': ok});
      }

      try {
        await auth.signIn(owner['loginName'], owner['password']);
        final repo = ContactRepository(anonymous, site: 'phase04-test'),
            admin = ContactRepository(staff, site: 'phase04-test');
        final projects = await anonymous.list('sites/phase04-test/projects');
        expect(projects, isNotEmpty);
        final p = projects.first,
            title = Map<String, dynamic>.from(p.data['content']['title']);
        final id = newContactId(),
            input = ContactInput(
              name: 'PHASE08 QA visitor',
              contact: 'phase08@example.invalid',
              details: 'Labelled Phase 8 technical request; no client details.',
              language: 'ar',
              project: {
                'id': p.path.split('/').last,
                'nameAr': title['ar'],
                'nameEn': title['en'],
              },
            );
        await repo.submit(id, input);
        check(
          'P08-T04 actual anonymous submission acknowledged by immutable receipt',
          await repo.confirmed(id),
        );
        final stored = (await staff.get(admin.requestPath(id)))!;
        check(
          'P08-T06 both project names, ID and original language saved',
          stored.data['project']['id'] == input.project['id'] &&
              stored.data['project']['nameEn'] == input.project['nameEn'] &&
              stored.data['language'] == 'ar',
        );
        await repo.submit(id, input);
        final after = (await staff.get(admin.requestPath(id)))!;
        check(
          'P08-T05 retry preserves exact original update time',
          after.updateTime == stored.updateTime,
        );
        await expectLater(
          anonymous.get(admin.requestPath(id)),
          throwsA(
            isA<DataFailure>().having(
              (e) => e.code,
              'code',
              'PERMISSION_DENIED',
            ),
          ),
        );
        check('P08-T07 actual anonymous private document read denied', true);
        await expectLater(
          anonymous.list('sites/phase04-test/contactRequests'),
          throwsA(isA<DataFailure>()),
        );
        await expectLater(
          anonymous.list('sites/phase04-test/contactReceipts'),
          throwsA(isA<DataFailure>()),
        );
        check(
          'P08-T07 both private requests and receipt listings denied',
          true,
        );
        await admin.update(
          id,
          auth.current!.uid,
          'closed',
          'Phase 8 QA check complete; test request only.',
        );
        final row = (await admin.inbox()).firstWhere((v) => v.id == id);
        check(
          'P08-T07 manager can follow up without changing submitted input',
          row.status == 'closed' && row.input.name == input.name,
        );
        final report = {
          'environment':
              'Real portfolio-14d15; isolated phase04-test; no messages sent',
          'requestId': id,
          'checks': checks,
          'complete': true,
        };
        File(
          'phases/results/08/checks/cloud-contact.json',
        ).writeAsStringSync(jsonEncode(report));
      } finally {
        staff.close();
        anonymous.close();
        await auth.dispose();
      }
    },
    skip: !cloud,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'Phase 8 prepare 15 user-supplied titles as private YOGEN drafts',
    () async {
      final config = jsonDecode(
        File('config/firebase.web.json').readAsStringSync(),
      );
      final owner = jsonDecode(
        File('.runtime/yogen-owner.local.json').readAsStringSync(),
      );
      final auth = RestAccountAuth(
        FirebaseAuthApi(config['FIREBASE_API_KEY']),
        CloudVault(),
      );
      final store = FirestoreRestStore(
        projectId: 'portfolio-14d15',
        token: auth.token,
      );
      final anonymous = FirestoreRestStore(
        projectId: 'portfolio-14d15',
        token: () async => null,
      );
      final results = <Map<String, Object?>>[];
      try {
        await auth.signIn(owner['loginName'], owner['password']);
        final repository = ProjectRepository(store, actor: auth.current!.uid);
        final before = await anonymous.listAll('sites/yogen/projects');
        final catalog = jsonDecode(
          File('phases/results/08/CONTENT-REGISTER.json').readAsStringSync(),
        );
        var order = 0;
        for (final row in catalog['projects'] as List) {
          final id = row['documentId'] as String,
              old = await repository.getDraft(id);
          if (old == null) {
            await repository.saveDraft(
              id,
              ProjectContent(
                title: LocalizedText(ar: row['titleAr'], en: row['titleEn']),
                order: order,
              ),
              expectedRevision: 0,
              internalNote:
                  '${row['sourceId']} — عنوان من صورة الأعمال التي قدمها الفريق.\nمرجع الرابط: ${row['sourceReference']}\nيلزم تأكيد الوصف والمساهمة ونسبة العمل وحالة الاستخدام والتصنيف وحق العرض والغلاف قبل النشر.',
            );
          }
          final draft = (await repository.getDraft(id))!;
          results.add({
            'sourceId': row['sourceId'],
            'documentId': id,
            'created': old == null,
            'status': draft.status.name,
            'revision': draft.revision,
          });
          order++;
        }
        final company = CompanyRepository(store, actor: auth.current!.uid);
        final publicCompany = await store.get('sites/yogen/company/current'),
            draftCompany = await store.get('sites/yogen/companyDrafts/current');
        var companyPrepared = false;
        if (publicCompany == null && draftCompany == null) {
          await company.saveCompanyDraft(
            about: aboutText,
            service: serviceText,
            contacts: {},
          );
          await company.publishCompany();
          companyPrepared = true;
        }
        final after = await anonymous.listAll('sites/yogen/projects');
        expect(after.map((d) => d.path), before.map((d) => d.path));
        expect(results.length, 15);
        File(
          'phases/results/08/checks/content-preparation.json',
        ).writeAsStringSync(
          jsonEncode({
            'site': 'yogen',
            'projects': results,
            'count': results.length,
            'publicationsBefore': before.length,
            'publicationsAfter': after.length,
            'companyInitializedWithConfirmedService': companyPrepared,
            'existingDraftsNeverOverwritten': true,
            'complete': true,
          }),
        );
      } finally {
        store.close();
        anonymous.close();
        await auth.dispose();
      }
    },
    skip: !content,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
