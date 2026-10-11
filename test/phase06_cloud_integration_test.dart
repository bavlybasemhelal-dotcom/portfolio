// Opt-in, isolated test site. Owner credentials never appear in output.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/auth/account_auth.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/company_repository.dart';
import 'package:yogen_portfolio/data/project_repository.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'package:yogen_portfolio/domain/project.dart';

class _Vault implements SessionVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  const enabled = bool.fromEnvironment('YOGEN_PHASE06_CLOUD');
  const mode = String.fromEnvironment(
    'YOGEN_PHASE06_COMPANY',
    defaultValue: 'initial',
  );
  test(
    'Actual published catalogue, cursor growth, private isolation and live company change',
    () async {
      final report = <String, dynamic>{
        'mode': mode,
        'environment':
            'Real Firebase, anonymous published-only REST, isolated phase04-test; no writes to yogen',
        'checks': [],
      };
      void check(String name, bool ok) {
        expect(ok, true, reason: name);
        (report['checks'] as List).add({'name': name, 'ok': ok});
      }

      final config = jsonDecode(
        File('config/firebase.web.json').readAsStringSync(),
      );
      final owner = jsonDecode(
        File('.runtime/yogen-owner.local.json').readAsStringSync(),
      );
      final auth = RestAccountAuth(
        FirebaseAuthApi(config['FIREBASE_API_KEY'] as String),
        _Vault(),
      );
      final anonymous = FirestoreRestStore(
        projectId: 'portfolio-14d15',
        token: () async => null,
      );
      final authenticated = FirestoreRestStore(
        projectId: 'portfolio-14d15',
        token: auth.token,
      );
      try {
        await auth.signIn(
          owner['loginName'] as String,
          owner['password'] as String,
        );
        final company = CompanyRepository(
          authenticated,
          actor: auth.current!.uid,
          site: 'phase04-test',
        );
        const about = LocalizedText(
          ar: 'بيانات اختبار تقنية معزولة، ليست بيانات فريق YOGEN أو عملائه.',
          en: 'Isolated technical fixtures, not YOGEN team or client data.',
        );
        const service = LocalizedText(
          ar: 'خدمة اختبار لتطوير تطبيقات حسب الطلب.',
          en: 'Technical fixture for custom application development.',
        );
        if (mode == 'on') {
          await company.saveTeamDraft(
            'phase06-fixture',
            name: const LocalizedText(
              ar: 'ملف اختبار — ليس عضو YOGEN',
              en: 'Test profile — not a YOGEN member',
            ),
            role: const LocalizedText(ar: 'دور اختبار', en: 'Test role'),
          );
          await company.publishTeam('phase06-fixture');
          await company.saveCompanyDraft(
            about: about,
            service: service,
            contacts: {'email': 'qa@example.com'},
          );
          await company.publishCompany();
          final data = await PublicContentRepository(
            anonymous,
            site: 'phase04-test',
          ).load();
          check(
            'Published profile/contact visible to anonymous client without rebuild',
            data.team.any(
                  (t) => t['name']['en'] == 'Test profile — not a YOGEN member',
                ) &&
                data.contacts['email'] == 'qa@example.com',
          );
        } else {
          await company.hideTeam('phase06-fixture');
          await company.saveCompanyDraft(about: about, service: service);
          await company.publishCompany();
          if (mode == 'initial') {
            final old = jsonDecode(
              File(
                'phases/results/05/checks/dart-rest-cloud.json',
              ).readAsStringSync(),
            );
            final source = await authenticated.get(
              'sites/phase04-test/projects/${old['projectId']}',
            );
            if (source == null) throw StateError('phase05_fixture_missing');
            final sourceContent = ProjectContent.fromMap(
              Map<String, dynamic>.from(source.data['content'] as Map),
            );
            final repo = ProjectRepository(
              authenticated,
              actor: auth.current!.uid,
              site: 'phase04-test',
            );
            for (var i = 1; i <= 28; i++) {
              final id = 'phase06-${i.toString().padLeft(2, '0')}';
              final existing = await repo.getDraft(id);
              final content = ProjectContent(
                title: LocalizedText(
                  ar: 'مشروع اختبار ${i.toString().padLeft(2, '0')}',
                  en: 'Technical project ${i.toString().padLeft(2, '0')}',
                ),
                summary: const LocalizedText(
                  ar: 'عينة معزولة للتحقق من المعرض والوسائط، وليست عملًا حقيقيًا للشركة.',
                  en: 'An isolated showcase and media fixture, not actual company work.',
                ),
                body: about,
                contribution: const LocalizedText(
                  ar: 'مساهمة تقنية لاختبار العرض فقط.',
                  en: 'Technical contribution for display verification only.',
                ),
                categoryId: sourceContent.categoryId,
                slug: 'phase06-showcase-${i.toString().padLeft(2, '0')}',
                usage: 'demo',
                attribution: 'company',
                order: i * 10,
                mediaIds: i == 1
                    ? sourceContent.mediaIds
                    : [sourceContent.mediaIds[i % 3]],
                tags: [
                  const LocalizedText(ar: 'ويب', en: 'Web'),
                  i.isEven
                      ? const LocalizedText(ar: 'أنظمة', en: 'Systems')
                      : const LocalizedText(ar: 'حجز', en: 'Booking'),
                ],
                problem: const LocalizedText(
                  ar: 'التحقق من تصفح المشاريع المتعددة وعرض الوسائط.',
                  en: 'Verify navigation across projects and media rendering.',
                ),
                solution: const LocalizedText(
                  ar: 'واجهة قابلة للتصفح مع معرض داخلي للصور.',
                  en: 'A navigable interface with an integrated image gallery.',
                ),
                features: const [
                  LocalizedText(ar: 'بحث وفلترة', en: 'Search and filtering'),
                  LocalizedText(ar: 'عرض الوسائط', en: 'Media display'),
                ],
                technologies: const ['Flutter', 'Firebase'],
              );
              final revision = await repo.saveDraft(
                id,
                content,
                expectedRevision: existing?.revision ?? 0,
                internalNote: 'PRIVATE PHASE06 FIXTURE NOTE',
              );
              await repo.publish(id, expectedRevision: revision);
            }
            await repo.saveDraft(
              'phase06-private',
              const ProjectContent(
                title: LocalizedText(
                  ar: 'مسودة اختبار خاصة',
                  en: 'PRIVATE PHASE06 DRAFT',
                ),
              ),
              expectedRevision:
                  (await repo.getDraft('phase06-private'))?.revision ?? 0,
              internalNote: 'DO NOT EXPOSE THIS',
            );
            final data = await PublicContentRepository(
              anonymous,
              site: 'phase04-test',
            ).load();
            check(
              'Server cursor covers more than 24 publications without duplicate IDs',
              data.projects.length >= 28 &&
                  data.projects.map((p) => p.id).toSet().length ==
                      data.projects.length,
            );
            check(
              'Stable sort by order/document ID across cursor boundary',
              data.projects.every((p) => p.id != 'phase06-private') &&
                  data.projects
                          .where((p) => p.id.startsWith('phase06-'))
                          .map((p) => p.content.order)
                          .toList()
                          .join(',') ==
                      List.generate(28, (i) => (i + 1) * 10).join(','),
            );
            check(
              'Multi-tag first project has six ready assets and optional case study',
              data.projects
                          .firstWhere((p) => p.id == 'phase06-01')
                          .content
                          .tags
                          .length ==
                      2 &&
                  data.projects
                          .firstWhere((p) => p.id == 'phase06-01')
                          .assets
                          .length ==
                      6,
            );
            await expectLater(
              anonymous.get('sites/phase04-test/projectDrafts/phase06-private'),
              throwsA(isA<DataFailure>()),
            );
            check('Anonymous private draft access rejected', true);
            final live = await PublicContentRepository(anonymous).load();
            check(
              'Real YOGEN space retains no technical projects/profile/contact',
              live.projects.isEmpty &&
                  live.team.isEmpty &&
                  live.contacts.isEmpty,
            );
            report['projectId'] = 'phase06-01';
            report['count'] = data.projects.length;
            report['fixtureIds'] = List.generate(
              28,
              (i) => 'phase06-${(i + 1).toString().padLeft(2, '0')}',
            );
          }
          final data = await PublicContentRepository(
            anonymous,
            site: 'phase04-test',
          ).load();
          check(
            'Missing team/contact remain hidden in published data',
            data.team.isEmpty && data.contacts.isEmpty,
          );
        }
        report['complete'] = true;
      } finally {
        File(
          'phases/results/06/checks/cloud-$mode.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
        anonymous.close();
        authenticated.close();
        await auth.dispose();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
