import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/auth/account_auth.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/project_repository.dart';
import 'package:yogen_portfolio/data/accounts_repository.dart';
import 'package:yogen_portfolio/domain/project.dart';

class IntegrationVault implements SessionVault {
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

class InjectedFailureStore implements DocumentStore {
  final DocumentStore delegate;
  InjectedFailureStore(this.delegate);
  @override
  Future<StoredDocument?> get(String path) => delegate.get(path);
  @override
  Future<List<StoredDocument>> list(String collection, {int limit = 30}) =>
      delegate.list(collection, limit: limit);
  @override
  Future<void> commit(List<DocumentWrite> writes) => delegate.commit(writes);
  @override
  Future<T> transaction<T>(Future<T> Function(DocumentTransaction tx) body) =>
      delegate.transaction((tx) async {
        final value = await body(tx);
        tx.set('sites/phase04-test/settings/injected-forbidden', {
          'fail': true,
        });
        return value;
      });
}

class TraceStore extends FirestoreRestStore {
  TraceStore({
    required super.projectId,
    required super.token,
    required super.origin,
  });
  @override
  Future<dynamic> request(
    String url, {
    String method = 'POST',
    Object? body,
    bool missingOk = false,
  }) async {
    try {
      return await super.request(
        url,
        method: method,
        body: body,
        missingOk: missingOk,
      );
    } catch (e) {
      stdout.writeln(
        'REST failure: $method ${Uri.parse(url).path} ${e is DataFailure ? e.code : e.runtimeType}',
      );
      rethrow;
    }
  }
}

void main() {
  final cloud = Platform.environment['YOGEN_INTEGRATION'] == 'cloud';
  final integration = cloud || Platform.environment['YOGEN_INTEGRATION'] == '1';
  final run = DateTime.now().millisecondsSinceEpoch.toString();
  final report = <String, Object?>{
    'transport': cloud
        ? 'Actual Dart Auth/Firestore REST against portfolio-14d15, isolated phase04-test'
        : 'Actual Dart Auth/Firestore REST against real rules/Auth emulators',
    'checks': <Map<String, Object?>>[],
  };
  late Map<String, dynamic> fixtures;
  late RestAccountAuth manager, editor;
  late FirestoreRestStore managerStore, editorStore, visitorStore;
  FirebaseAuthApi api() => FirebaseAuthApi(
    fixtures['apiKey'] as String? ?? 'emulator-key',
    origin: cloud
        ? 'https://identitytoolkit.googleapis.com'
        : 'http://127.0.0.1:9094/identitytoolkit.googleapis.com',
    refreshOrigin: cloud
        ? 'https://securetoken.googleapis.com'
        : 'http://127.0.0.1:9094/securetoken.googleapis.com',
  );
  Future<RestAccountAuth> sign(String name) async {
    final value =
        (fixtures['users'] as List).firstWhere((v) => v['name'] == name) as Map;
    final auth = RestAccountAuth(api(), IntegrationVault());
    await auth.signIn(
      value['login'] as String? ?? name,
      value['password'] as String,
    );
    return auth;
  }

  FirestoreRestStore store(RestAccountAuth? auth) => TraceStore(
    projectId: fixtures['projectId'] as String,
    token: () => auth?.token() ?? Future.value(null),
    origin: cloud
        ? 'https://firestore.googleapis.com'
        : 'http://127.0.0.1:8084',
  );
  const localized = LocalizedText(
    ar: 'بيانات تجربة معلّمة',
    en: 'Clearly marked test fixture',
  );
  ProjectContent content(
    String slug, {
    String summary = 'Version one',
    bool missingEnglish = false,
  }) => ProjectContent(
    title: localized,
    summary: LocalizedText(ar: 'وصف تجربة', en: summary),
    body: LocalizedText(
      ar: 'الاحتياج والحل والوظائف',
      en: missingEnglish ? '' : 'Problem, solution and features',
    ),
    contribution: localized,
    categoryId: 'systems',
    slug: slug,
    usage: 'demo',
    attribution: 'company',
    mediaIds: const ['cover'],
  );
  void evidence(String name) =>
      (report['checks'] as List).add({'name': name, 'ok': true});
  setUpAll(() async {
    if (!integration) return;
    fixtures =
        jsonDecode(
              File(
                cloud
                    ? '.runtime/phase04-cloud-fixtures.local.json'
                    : '.runtime/phase04-emulator-fixtures.local.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    manager = await sign('rest-manager');
    editor = await sign('rest-editor');
    managerStore = store(manager);
    editorStore = store(editor);
    visitorStore = store(null);
  });
  tearDownAll(() async {
    if (!integration) return;
    managerStore.close();
    editorStore.close();
    visitorStore.close();
    await manager.dispose();
    await editor.dispose();
    File(
      'phases/results/04/checks/dart-rest-${cloud ? 'cloud' : 'emulator'}.json',
    ).writeAsStringSync(jsonEncode(report));
  });
  test(
    'Dart REST preserves old publication, rejects conflict, atomically handles failure and restore',
    () async {
      final repo = ProjectRepository(
            editorStore,
            actor: editor.current!.uid,
            site: 'phase04-test',
          ),
          visitor = ProjectRepository(
            visitorStore,
            actor: '',
            site: 'phase04-test',
          );
      final id = 'dart-rest-cycle-$run';
      var revision = await repo.saveDraft(
        id,
        content(id, missingEnglish: true),
        expectedRevision: 0,
        internalNote: 'PRIVATE-ONLY',
      );
      await expectLater(
        repo.publish(id, expectedRevision: revision),
        throwsA(isA<ContentFailure>()),
      );
      revision = await repo.saveDraft(
        id,
        content(id),
        expectedRevision: revision,
        internalNote: 'PRIVATE-ONLY',
      );
      revision = await repo.publish(id, expectedRevision: revision);
      final first = await visitor.getPublic(id);
      expect(first!.data.containsKey('internalNote'), false);
      expect(first.data['content']['links'], isEmpty);
      revision = await repo.saveDraft(
        id,
        content(id, summary: 'Version two'),
        expectedRevision: revision,
        internalNote: 'PRIVATE-ONLY',
      );
      expect(
        (await visitor.getPublic(id))!.data['revision'],
        first.data['revision'],
      );
      await expectLater(
        repo.saveDraft(
          id,
          content(id, summary: 'STALE'),
          expectedRevision: revision - 1,
        ),
        throwsA(
          isA<ContentFailure>().having(
            (v) => v.code,
            'code',
            'revision_conflict',
          ),
        ),
      );
      final failing = ProjectRepository(
        InjectedFailureStore(editorStore),
        actor: editor.current!.uid,
        site: 'phase04-test',
      );
      await expectLater(
        failing.publish(id, expectedRevision: revision),
        throwsA(
          isA<DataFailure>().having((v) => v.code, 'code', 'PERMISSION_DENIED'),
        ),
      );
      expect(
        (await visitor.getPublic(id))!.data['content']['summary']['en'],
        'Version one',
      );
      expect((await repo.getDraft(id))!.revision, revision);
      // Another device changes the draft after this transaction's read. Commit
      // must reject its captured updateTime even if the callback passed earlier.
      await expectLater(
        editorStore.transaction((tx) async {
          final path = 'sites/phase04-test/projectDrafts/$id';
          final snapshot = await tx.get(path);
          revision = await repo.saveDraft(
            id,
            content(id, summary: 'Version two'),
            expectedRevision: revision,
            internalNote: 'PRIVATE-ONLY',
          );
          tx.set(path, {
            ...snapshot!.data,
            'revision': snapshot.data['revision'] + 1,
            'updatedAt': serverTime,
            'updatedBy': editor.current!.uid,
          });
        }),
        throwsA(isA<DataFailure>()),
      );
      expect((await repo.getDraft(id))!.revision, revision);
      revision = await repo.publish(id, expectedRevision: revision);
      expect(
        (await visitor.resolveSlug(id))!.data['content']['summary']['en'],
        'Version two',
      );
      revision = await repo.archive(id, expectedRevision: revision);
      expect(await visitor.getPublic(id), null);
      revision = await repo.restore(id, expectedRevision: revision);
      expect((await repo.getDraft(id))!.content.mediaIds, ['cover']);
      expect(await visitor.getPublic(id), null);
      revision = await repo.publish(id, expectedRevision: revision);
      await repo.unpublish(id, expectedRevision: revision);
      expect(await visitor.resolveSlug(id), null);
      evidence(
        'Dart publication cycle, private/public separation, atomic rejection and optimistic conflict',
      );
    },
    skip: !integration,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'All three cloud editors publish; visitors and roleless users cannot access private data or promote themselves',
    () async {
      final outsider = await sign('rest-outsider'), outsiderStore = store(null);
      final noRoleStore = store(outsider);
      try {
        await expectLater(
          visitorStore.get('sites/phase04-test/settings/media'),
          throwsA(isA<DataFailure>()),
        );
        for (final name in ['rest-editor', 'rest-editor2', 'rest-editor3']) {
          final staff = await sign(name), db = store(staff);
          final repo = ProjectRepository(
            db,
            actor: staff.current!.uid,
            site: 'phase04-test',
          );
          final id = '$name-$run';
          final rev = await repo.saveDraft(
            id,
            content(id),
            expectedRevision: 0,
          );
          final pub = await repo.publish(id, expectedRevision: rev);
          expect(
            await visitorStore.get('sites/phase04-test/projects/$id'),
            isNotNull,
          );
          for (final denied in [visitorStore, noRoleStore]) {
            await expectLater(
              denied.get('sites/phase04-test/projectDrafts/$id'),
              throwsA(isA<DataFailure>()),
            );
            await expectLater(
              denied.commit([
                DocumentWrite.set('sites/phase04-test/settings/attack', {
                  'value': true,
                }),
              ]),
              throwsA(isA<DataFailure>()),
            );
          }
          final rolePath =
              'sites/phase04-test/adminUsers/${staff.current!.uid}';
          final role = await db.get(rolePath);
          await expectLater(
            db.commit([
              DocumentWrite.set(rolePath, {
                ...role!.data,
                'role': 'manager',
                'updatedAt': serverTime,
                'updatedBy': staff.current!.uid,
              }),
            ]),
            throwsA(isA<DataFailure>()),
          );
          await repo.unpublish(id, expectedRevision: pub);
          db.close();
          await staff.dispose();
        }
        evidence(
          'Three real cloud editor identities publish; visitor/roleless privacy, direct writes and self-promotion rejected',
        );
      } finally {
        outsiderStore.close();
        noRoleStore.close();
        await outsider.dispose();
      }
    },
    skip: !cloud,
    timeout: const Timeout(Duration(minutes: 5)),
  );
  test(
    'Real Auth REST signup does not change manager session; restart and role revocation work',
    () async {
      final accounts = AccountsRepository(
        managerStore,
        manager.api,
        actor: manager.current!.uid,
        site: 'phase04-test',
      );
      final before = manager.current!.uid;
      final name = 'created-by-dart-$run';
      final password =
          (fixtures['generatedPassword'] as String?) ??
          'Emulator-local-password-123';
      final created = await accounts.createEditor(name, password);
      expect(manager.current!.uid, before);
      expect(
        (await accounts.list()).any((v) => v.data['uid'] == created.uid),
        true,
      );
      final member = RestAccountAuth(api(), IntegrationVault());
      await member.signIn(name, password);
      final vault = member.vault;
      await member.dispose();
      final restored = RestAccountAuth(api(), vault);
      await restored.restore();
      expect(restored.current!.uid, created.uid);
      final db = store(restored),
          repo = ProjectRepository(
            db,
            actor: created.uid,
            site: 'phase04-test',
          );
      final project = 'new-member-$run';
      await repo.saveDraft(project, content(project), expectedRevision: 0);
      await accounts.setEnabled(created.uid, false);
      await expectLater(
        repo.getDraft(project),
        throwsA(
          isA<DataFailure>().having((v) => v.code, 'code', 'PERMISSION_DENIED'),
        ),
      );
      if (cloud) {
        await restored.api.call('delete', {'idToken': await restored.token()});
      }
      await restored.signOut();
      expect(await vault.read(), null);
      db.close();
      await restored.dispose();
      evidence(
        'Dart Auth create editor, unchanged manager, refreshed restored session and immediate rule revocation',
      );
    },
    skip: !integration,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
