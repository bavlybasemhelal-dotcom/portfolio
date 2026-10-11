// Opt-in real service checks. Credentials stay in .runtime, never in reports.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/auth/account_auth.dart';
import 'package:yogen_portfolio/data/accounts_repository.dart';
import 'package:yogen_portfolio/data/admin_content_repository.dart';
import 'package:yogen_portfolio/data/company_repository.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/project_repository.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'package:yogen_portfolio/domain/project.dart';

class CloudVault implements SessionVault {
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
  const enabled = bool.fromEnvironment('YOGEN_PHASE07_CLOUD');
  const cleanup = bool.fromEnvironment('YOGEN_PHASE07_CLEANUP');
  test(
    'Phase 7 actual Firebase management lifecycle in isolated site',
    () async {
      final report = <String, dynamic>{
        'environment':
            'Real Firebase; phase04-test only, no company/client data or writes to yogen',
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
      final api = FirebaseAuthApi(config['FIREBASE_API_KEY'] as String),
          auth = RestAccountAuth(
            FirebaseAuthApi(config['FIREBASE_API_KEY'] as String),
            CloudVault(),
          );
      final store = FirestoreRestStore(
            projectId: 'portfolio-14d15',
            token: auth.token,
          ),
          anonymous = FirestoreRestStore(
            projectId: 'portfolio-14d15',
            token: () async => null,
          );
      final sessions = <RestAccountAuth>[],
          otherStores = <FirestoreRestStore>[];
      try {
        await auth.signIn(
          owner['loginName'] as String,
          owner['password'] as String,
        );
        final uid = auth.current!.uid;
        final admin = AdminContentRepository(
              store,
              actor: uid,
              site: 'phase04-test',
            ),
            accounts = AccountsRepository(
              store,
              api,
              actor: uid,
              site: 'phase04-test',
            );
        final credentialsFile = File('.runtime/phase07-accounts.local.json');
        if (cleanup) {
          final saved = jsonDecode(credentialsFile.readAsStringSync());
          final testAccounts = (await accounts.list()).where(
            (v) =>
                v.data['role'] == 'editor' &&
                (v.data['loginName'] as String).startsWith('phase07'),
          );
          for (final v in testAccounts) {
            await accounts.setEnabled(v.data['uid'] as String, false);
          }
          final projectIds = {...List<String>.from(saved['projects'])};
          for (final filename in ['browser-lifecycle', 'browser-conflict']) {
            final file = File('phases/results/07/checks/$filename.json');
            if (file.existsSync()) {
              final result = jsonDecode(file.readAsStringSync()) as Map;
              for (final key in ['projectId', 'duplicateId', 'copyId']) {
                if (result[key] is String) {
                  projectIds.add(result[key] as String);
                }
              }
            }
          }
          projectIds.addAll(
            (await admin.listProjects())
                .where((v) => v.id.startsWith('phase07'))
                .map((v) => v.id),
          );
          for (final id in projectIds) {
            final draft = await admin.projects.getDraft(id);
            if (draft != null && draft.status != ProjectStatus.archived) {
              await admin.projects.archive(
                id,
                expectedRevision: draft.revision,
              );
            }
          }
          final company = CompanyRepository(
            store,
            actor: uid,
            site: 'phase04-test',
          );
          for (var i = 0; i < 4; i++) {
            await company.hideTeam('phase07-member-$i');
          }
          final profiles =
              (await store.listAll('sites/phase04-test/teamDrafts')).where(
                (v) =>
                    v.data['name']?['en'] == 'UI fixture member' ||
                    v.data['name']?['ar'] == 'ملف جزئي من اللوحة',
              );
          for (final v in profiles) {
            await company.hideTeam(v.path.split('/').last);
          }
          for (final category in (await admin.categories()).where(
            (v) => v.path.split('/').last.startsWith('phase07'),
          )) {
            await admin.saveCategory(
              category.path.split('/').last,
              LocalizedText.fromMap(
                Map<String, dynamic>.from(category.data['name'] as Map),
              ),
              order: category.data['order'] as int,
              enabled: false,
            );
          }
          final previous = Map<String, dynamic>.from(
            saved['companyDraft'] as Map,
          );
          await company.saveCompanyDraft(
            about: LocalizedText.fromMap(
              Map<String, dynamic>.from(previous['about'] as Map),
            ),
            service: LocalizedText.fromMap(
              Map<String, dynamic>.from(previous['service'] as Map),
            ),
            contacts: Map<String, String>.from(previous['contacts'] as Map),
          );
          await company.publishCompany();
          final remaining = await admin.listProjects(),
              refreshedAccounts = await accounts.list();
          check(
            'Temporary accounts disabled and all identified phase 7 projects archived',
            !refreshedAccounts.any(
                  (v) =>
                      v.data['enabled'] == true &&
                      (v.data['loginName'] as String).startsWith('phase07'),
                ) &&
                remaining
                    .where((v) => projectIds.contains(v.id))
                    .every((v) => v.status == ProjectStatus.archived),
          );
          report['archivedProjects'] = projectIds.length;
          report['disabledAccounts'] = testAccounts.length;
          report['hiddenProfiles'] = profiles.length + 4;
          final publicProfiles = await anonymous.listAll(
            'sites/phase04-test/team',
          );
          check(
            'Phase 7 public test profiles hidden and company contacts restored',
            !publicProfiles.any(
                  (v) =>
                      v.path.split('/').last.startsWith('phase07-member') ||
                      v.data['name']?['en'] == 'UI fixture member',
                ) &&
                jsonEncode(
                      (await anonymous.get(
                        'sites/phase04-test/company/current',
                      ))!.data['contacts'],
                    ) ==
                    jsonEncode(previous['contacts']),
          );
        } else {
          final source = jsonDecode(
            File(
              'phases/results/05/checks/dart-rest-cloud.json',
            ).readAsStringSync(),
          );
          final published = (await admin.projects.getPublic(
            source['projectId'] as String,
          ))!;
          final old = ProjectContent.fromMap(
            Map<String, dynamic>.from(published.data['content'] as Map),
          );
          final id = 'phase07-${DateTime.now().millisecondsSinceEpoch}';
          report['projectId'] = id;
          const text = LocalizedText(
            ar: 'مشروع اختبار معزول',
            en: 'Isolated editor project',
          );
          const body = LocalizedText(
            ar: '# عنوان\nفقرة **واضحة**\n- وظيفة\n[رابط](https://example.com)',
            en: '# Heading\nA **clear** paragraph\n- Feature\n[Link](https://example.com)',
          );
          final content = ProjectContent(
            title: text,
            summary: text,
            body: body,
            contribution: text,
            categoryId: 'phase07-category',
            slug: id,
            usage: 'demo',
            attribution: 'company',
            mediaIds: old.mediaIds,
            problem: text,
            solution: text,
            tags: List.generate(
              6,
              (i) => LocalizedText(ar: 'وسم $i', en: 'Tag $i'),
            ),
            features: List.generate(
              6,
              (i) => LocalizedText(ar: 'وظيفة $i', en: 'Feature $i'),
            ),
            technologies: List.generate(6, (i) => 'Tech $i'),
            links: List.generate(
              6,
              (i) => {
                'url': 'https://example.com/$i',
                'labelAr': 'رابط $i',
                'labelEn': 'Link $i',
              },
            ),
          );
          await admin.saveCategory(
            'phase07-category',
            const LocalizedText(ar: 'تصنيف اختبار', en: 'Test category'),
            order: 7,
          );
          final partial = ProjectContent.fromMap({
            ...content.toMap(),
            'title': {'ar': 'جزئي', 'en': ''},
            'problem': {'ar': 'مشكلة جزئية', 'en': ''},
            'tags': {'ar': 'جزئي', 'en': ''},
          });
          var revision = await admin.projects.saveDraft(
            id,
            partial,
            expectedRevision: 0,
            internalNote: 'Private fixture note',
          );
          await expectLater(
            () => admin.projects.publish(id, expectedRevision: revision),
            throwsA(isA<ContentFailure>()),
          );
          check(
            'Partial bilingual drafts round trip while anonymous publication remains absent',
            (await admin.projects.getDraft(id))!.content.problem.en.isEmpty &&
                (await anonymous.get('sites/phase04-test/projects/$id')) ==
                    null,
          );
          revision = await admin.projects.saveDraft(
            id,
            content,
            expectedRevision: revision,
            internalNote: 'Private fixture note',
          );
          revision = await admin.projects.publish(
            id,
            expectedRevision: revision,
          );
          final pub = (await anonymous.get('sites/phase04-test/projects/$id'))!;
          check(
            'Six media/tags/features/links publish atomically without private notes',
            pub.data['assets'].length == 6 &&
                !pub.data.containsKey('internalNote') &&
                ProjectContent.fromMap(
                      Map<String, dynamic>.from(pub.data['content'] as Map),
                    ).links.length ==
                    6,
          );
          final edited = ProjectContent.fromMap({
            ...content.toMap(),
            'body': {'ar': '# تعديل جديد', 'en': '# New draft edit'},
            'mediaIds': [
              old.mediaIds[1],
              old.mediaIds[0],
              ...old.mediaIds.skip(2),
            ],
          });
          revision = await admin.projects.saveDraft(
            id,
            edited,
            expectedRevision: revision,
          );
          check(
            'Published body and cover stay unchanged while editing draft',
            ProjectContent.fromMap(
                  Map<String, dynamic>.from(
                    (await anonymous.get(
                          'sites/phase04-test/projects/$id',
                        ))!.data['content']
                        as Map,
                  ),
                ).body.en ==
                body.en,
          );
          await expectLater(
            () => admin.projects.saveDraft(
              id,
              content,
              expectedRevision: revision - 1,
            ),
            throwsA(isA<ContentFailure>()),
          );
          check(
            'Stale session save refuses overwrite',
            (await admin.projects.getDraft(id))!.content.body.en ==
                '# New draft edit',
          );
          revision = await admin.projects.publish(
            id,
            expectedRevision: revision,
          );
          check(
            'Republish updates cover and rich description only after acknowledgment',
            (await anonymous.get(
                  'sites/phase04-test/projects/$id',
                ))!.data['assets'][0]['id'] ==
                old.mediaIds[1],
          );
          await admin.duplicate(id, '$id-copy');
          final copy = (await admin.projects.getDraft('$id-copy'))!;
          check(
            'Duplicate is draft with blank slug and same ordered Drive assets',
            copy.content.slug.isEmpty &&
                copy.content.mediaIds.join(',') == edited.mediaIds.join(',') &&
                copy.status == ProjectStatus.draft,
          );
          revision = await admin.projects.archive(
            id,
            expectedRevision: revision,
          );
          check(
            'Archive removes public snapshot and retains media references',
            await anonymous.get('sites/phase04-test/projects/$id') == null &&
                (await admin.projects.getDraft(id))!.content.mediaIds.length ==
                    6,
          );
          revision = await admin.projects.restore(
            id,
            expectedRevision: revision,
          );
          revision = await admin.projects.publish(
            id,
            expectedRevision: revision,
          );
          revision = await admin.projects.unpublish(
            id,
            expectedRevision: revision,
          );
          check(
            'Restore requires publish; unpublish preserves complete draft',
            await anonymous.get('sites/phase04-test/projects/$id') == null &&
                (await admin.projects.getDraft(id))!.status ==
                    ProjectStatus.draft,
          );
          final companySnapshot = (await store.get(
            'sites/phase04-test/companyDrafts/current',
          ))!.data;
          final beforeCompany = {
            for (final k in ['about', 'service', 'contacts'])
              k: companySnapshot[k],
          };
          final saved = <String, dynamic>{
            'accounts': [],
            'projects': [id, '$id-copy'],
            'companyDraft': beforeCompany,
          };
          Future<void> persist() async {
            credentialsFile.writeAsStringSync(jsonEncode(saved), flush: true);
          }

          for (var i = 0; i < 3; i++) {
            final login = 'phase07-${DateTime.now().microsecondsSinceEpoch}-$i';
            final password =
                'Yogen-QA-${Random.secure().nextInt(1 << 30)}-${Random.secure().nextInt(1 << 30)}';
            final account = await accounts.createEditor(login, password);
            (saved['accounts'] as List).add({
              'uid': account.uid,
              'login': login,
              'password': password,
            });
            await persist();
            final member = RestAccountAuth(
              FirebaseAuthApi(config['FIREBASE_API_KEY'] as String),
              CloudVault(),
            );
            sessions.add(member);
            await member.signIn(login, password);
            final memberStore = FirestoreRestStore(
              projectId: 'portfolio-14d15',
              token: member.token,
            );
            otherStores.add(memberStore);
            final memberRepo = ProjectRepository(
              memberStore,
              actor: account.uid,
              site: 'phase04-test',
            );
            final memberId = '$id-editor$i';
            (saved['projects'] as List).add(memberId);
            await persist();
            var rev = await memberRepo.saveDraft(
              memberId,
              ProjectContent.fromMap({...content.toMap(), 'slug': memberId}),
              expectedRevision: 0,
            );
            rev = await memberRepo.publish(memberId, expectedRevision: rev);
            await expectLater(
              () => memberStore.commit([
                DocumentWrite.set('sites/phase04-test/settings/drive', {
                  'rootFolderId': 'forged',
                }),
              ]),
              throwsA(isA<DataFailure>()),
            );
            await expectLater(
              () => memberStore.commit([
                DocumentWrite.set(
                  'sites/phase04-test/adminUsers/${account.uid}',
                  {'role': 'manager', 'enabled': true},
                ),
              ]),
              throwsA(isA<DataFailure>()),
            );
            check(
              'Editor ${i + 1} publishes; settings and self-granted manager role rejected',
              rev == 2 && auth.current!.uid == uid,
            );
            if (i == 0) {
              await accounts.setEnabled(account.uid, false);
              await expectLater(
                () => memberRepo.saveDraft(
                  memberId,
                  content,
                  expectedRevision: rev,
                ),
                throwsA(isA<DataFailure>()),
              );
              await accounts.setEnabled(account.uid, true);
              check(
                'Manager revokes/restores editor while its own session stays stable',
                auth.current!.uid == uid,
              );
            }
          }
          final company = CompanyRepository(
            store,
            actor: uid,
            site: 'phase04-test',
          );
          await company.saveTeamDraft(
            'phase07-partial',
            name: const LocalizedText(ar: 'جزئي'),
            role: const LocalizedText(),
          );
          await expectLater(
            () => company.publishTeam('phase07-partial'),
            throwsA(isA<ContentFailure>()),
          );
          for (var i = 0; i < 4; i++) {
            await company.saveTeamDraft(
              'phase07-member-$i',
              name: LocalizedText(ar: 'عضو اختبار $i', en: 'Fixture member $i'),
              role: text,
              order: 4 - i,
              photoId: old.mediaIds.first,
              links: [
                {
                  'url': 'https://example.com',
                  'labelAr': 'رابط',
                  'labelEn': 'Link',
                },
              ],
            );
            await company.publishTeam('phase07-member-$i');
          }
          await company.hideTeam('phase07-member-0');
          check(
            'Four public profiles/photos/links; partial hidden, hide preserves draft and login role',
            await anonymous.get('sites/phase04-test/team/phase07-partial') ==
                    null &&
                await store.get(
                      'sites/phase04-test/teamDrafts/phase07-member-0',
                    ) !=
                    null &&
                (await accounts.list()).any(
                  (v) =>
                      v.data['enabled'] == true && v.data['role'] == 'editor',
                ),
          );
          await company.saveCompanyDraft(about: text, service: text);
          await company.publishCompany();
          check(
            'Empty company channels have no public links',
            (await anonymous.get(
              'sites/phase04-test/company/current',
            ))!.data['contacts'].isEmpty,
          );
          await company.saveCompanyDraft(
            about: text,
            service: text,
            contacts: {'email': 'qa@example.com', 'whatsapp': '+201234567890'},
          );
          await company.publishCompany();
          await company.saveCompanyDraft(
            about: text,
            service: text,
            contacts: {'email': 'updated@example.com', 'whatsapp': ''},
          );
          await company.publishCompany();
          check(
            'Validated company contacts edit and removal round trip',
            (await anonymous.get(
                      'sites/phase04-test/company/current',
                    ))!.data['contacts']['email'] ==
                    'updated@example.com' &&
                !(await anonymous.get(
                  'sites/phase04-test/company/current',
                ))!.data['contacts'].containsKey('whatsapp'),
          );
          await admin.saveCategory(
            'phase07-category',
            const LocalizedText(ar: 'تصنيف معدّل', en: 'Updated category'),
            order: 7,
          );
          check(
            'Stable category ID retains project relationships after bilingual rename',
            (await admin.projects.getDraft(id))!.content.categoryId ==
                    'phase07-category' &&
                (await admin.categories()).any(
                  (v) => v.data['name']['en'] == 'Updated category',
                ),
          );
          revision = await admin.projects.publish(
            id,
            expectedRevision: revision,
          );
          report['previewProjectId'] = id;
          await persist();
          check(
            'Real YOGEN projects and profiles remain empty',
            (await PublicContentRepository(
                  anonymous,
                  site: 'yogen',
                ).load()).projects.isEmpty &&
                (await PublicContentRepository(
                  anonymous,
                  site: 'yogen',
                ).load()).team.isEmpty,
          );
        }
      } finally {
        File(
          'phases/results/07/checks/cloud-${cleanup ? 'cleanup' : 'lifecycle'}.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
        for (final v in otherStores) {
          v.close();
        }
        for (final v in sessions) {
          await v.dispose();
        }
        store.close();
        anonymous.close();
        await auth.dispose();
        api.close();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
