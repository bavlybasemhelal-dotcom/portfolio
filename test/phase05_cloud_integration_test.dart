// Opt-in: isolated test site, real Firebase/Drive. No passwords in reports.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/auth/account_auth.dart';
import 'package:yogen_portfolio/data/accounts_repository.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/media_repository.dart';
import 'package:yogen_portfolio/data/media_settings_repository.dart';
import 'package:yogen_portfolio/data/project_repository.dart';
import 'package:yogen_portfolio/domain/media.dart';
import 'package:yogen_portfolio/domain/project.dart';
import 'package:yogen_portfolio/features/media/drive_bridge.dart';
import 'package:yogen_portfolio/features/media/media_transport.dart';

class TestVault implements SessionVault {
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

class TrackedTransaction implements DocumentTransaction {
  final DocumentTransaction delegate;
  bool mediaWrite = false;
  TrackedTransaction(this.delegate);
  @override
  Future<StoredDocument?> get(String path) => delegate.get(path);
  @override
  void set(String path, Map<String, Object?> value) {
    if (path.contains('/media/')) mediaWrite = true;
    delegate.set(path, value);
  }

  @override
  void delete(String path) => delegate.delete(path);
}

class FailRegistrationOnce implements DocumentStore {
  final DocumentStore delegate;
  bool fail = true;
  FailRegistrationOnce(this.delegate);
  @override
  Future<StoredDocument?> get(String path) => delegate.get(path);
  @override
  Future<List<StoredDocument>> list(String path, {int limit = 30}) =>
      delegate.list(path, limit: limit);
  @override
  Future<void> commit(List<DocumentWrite> writes) => delegate.commit(writes);
  @override
  Future<T> transaction<T>(Future<T> Function(DocumentTransaction) body) =>
      delegate.transaction((tx) async {
        final tracked = TrackedTransaction(tx);
        final value = await body(tracked);
        if (tracked.mediaWrite && fail) {
          fail = false;
          throw const DataFailure('injected_before_reference_commit');
        }
        return value;
      });
}

class LoseResponseOnce implements MediaTransport {
  final MediaTransport delegate;
  bool lose = false;
  int uploads = 0, statuses = 0;
  LoseResponseOnce(this.delegate);
  @override
  Future<Map<String, dynamic>> ping(String url, String token, String site) =>
      delegate.ping(url, token, site);
  @override
  Future<MediaSource> upload(
    String url,
    String token,
    String site,
    UploadOperation operation,
    Uint8List bytes, {
    Uint8List? thumbnail,
  }) async {
    uploads++;
    final value = await delegate.upload(
      url,
      token,
      site,
      operation,
      bytes,
      thumbnail: thumbnail,
    );
    if (lose) {
      lose = false;
      throw TimeoutException('Injected after actual server commit');
    }
    return value;
  }

  @override
  Future<MediaSource?> status(
    String url,
    String token,
    String site,
    UploadOperation operation,
  ) {
    statuses++;
    return delegate.status(url, token, site, operation);
  }

  @override
  Future<Uint8List> read(
    String url,
    String site,
    String id, {
    bool thumbnail = false,
    Future<void>? abortTrigger,
  }) => delegate.read(
    url,
    site,
    id,
    thumbnail: thumbnail,
    abortTrigger: abortTrigger,
  );
}

void main() {
  final enabled = Platform.environment['YOGEN_PHASE05_CLOUD'] == '1';
  test(
    'Actual isolated Firebase/Drive upload, recovery, reuse and publication',
    () async {
      final report = <String, dynamic>{
        'environment':
            'Actual Dart REST/Auth/Apps Script/Drive, isolated phase04-test; fault injection only at client boundary',
        'checks': [],
        'assets': [],
      };
      final key =
          jsonDecode(
                File('config/firebase.web.json').readAsStringSync(),
              )['FIREBASE_API_KEY']
              as String;
      final owner = jsonDecode(
        File('.runtime/yogen-owner.local.json').readAsStringSync(),
      );
      final url =
          jsonDecode(
                File('config/drive.phase05.json').readAsStringSync(),
              )['webAppUrl']
              as String;
      const site = 'phase04-test';
      final run = DateTime.now().millisecondsSinceEpoch.toString();
      final projectId = 'phase05-$run', sharedId = 'phase05-shared-$run';
      final api = FirebaseAuthApi(key),
          manager = RestAccountAuth(FirebaseAuthApi(key), TestVault());
      final editor = RestAccountAuth(FirebaseAuthApi(key), TestVault()),
          outsider = RestAccountAuth(FirebaseAuthApi(key), TestVault());
      final bridge = DriveBridge(), raw = AppsScriptMediaTransport(bridge);
      final tracked = LoseResponseOnce(raw);
      FirestoreRestStore store(RestAccountAuth? auth) => FirestoreRestStore(
        projectId: 'portfolio-14d15',
        token: auth?.token ?? () async => null,
      );
      await manager.signIn(
        owner['loginName'] as String,
        owner['password'] as String,
      );
      final managerStore = store(manager),
          editorStore = store(editor),
          visitor = store(null);
      void evidence(String name) {
        report['checks'].add({'name': name, 'ok': true});
        stdout.writeln('Verified: $name');
      }

      const alt = LocalizedText(
        ar: 'وسيط اختبار تقني — ليس من أعمال الشركة',
        en: 'Technical media fixture — not company work',
      );
      ProjectContent content(
        List<String> ids,
        String slug, {
        String title = 'Technical media test',
      }) => ProjectContent(
        title: LocalizedText(ar: 'اختبار وسائط تقني', en: title),
        summary: alt,
        body: alt,
        contribution: alt,
        categoryId: 'phase05-media-tests',
        slug: slug,
        usage: 'demo',
        attribution: 'company',
        mediaIds: ids,
      );
      try {
        final passwordSeed = List.generate(
          28,
          (_) => Random.secure().nextInt(26) + 65,
        ).map(String.fromCharCode).join();
        final password = '${passwordSeed}9!';
        final login = 'phase05-editor-$run',
            outsiderLogin = 'phase05-outsider-$run';
        final accounts = AccountsRepository(
          managerStore,
          api,
          actor: manager.current!.uid,
          site: site,
        );
        await accounts.createEditor(login, password);
        await api.register(outsiderLogin, password);
        await editor.signIn(login, password);
        await outsider.signIn(outsiderLogin, password);
        File('.runtime/phase05-browser.local.json').writeAsStringSync(
          jsonEncode({
            'site': site,
            'projectId': projectId,
            'sharedId': sharedId,
            'editorLogin': login,
            'password': password,
            'editorUid': editor.current!.uid,
            'outsiderLogin': outsiderLogin,
            'outsiderUid': outsider.current!.uid,
          }),
        );
        final settings = MediaSettingsRepository(
          managerStore,
          raw,
          manager.token,
          actor: manager.current!.uid,
          site: site,
        );
        await settings.testAndSave(
          url,
          administrativeEmail: 'phase05-test@example.invalid',
        );
        expect(
          (await settings.get())!.data['administrativeEmail'],
          'phase05-test@example.invalid',
        );
        await expectLater(
          MediaSettingsRepository(
            editorStore,
            raw,
            editor.token,
            actor: editor.current!.uid,
            site: site,
          ).testAndSave(url),
          throwsA(isA<DriveFailure>()),
        );
        await expectLater(
          editorStore.commit([
            DocumentWrite.set('sites/$site/settings/drive', {'fake': true}),
          ]),
          throwsA(isA<DataFailure>()),
        );
        evidence(
          'P05-T01 actual manager connection/settings restore, editor denied at service and rules',
        );
        for (final token in ['', (await outsider.token())!]) {
          await expectLater(
            bridge.request(url, {
              'action': 'ping',
              'site': site,
              'idToken': token,
            }),
            throwsA(isA<DriveFailure>()),
          );
        }
        await accounts.setEnabled(editor.current!.uid, false);
        await expectLater(
          raw.ping(url, (await editor.token())!, site),
          throwsA(isA<DriveFailure>()),
        );
        await accounts.setEnabled(editor.current!.uid, true);
        evidence(
          'P05-T04 actual server rejects anonymous, roleless and revoked existing session',
        );
        await managerStore.commit([
          DocumentWrite.set('sites/$site/categories/phase05-media-tests', {
            'name': alt.toMap(),
            'enabled': true,
            'order': 0,
            'updatedAt': serverTime,
            'updatedBy': manager.current!.uid,
          }),
        ]);
        final repo = MediaRepository(
          editorStore,
          tracked,
          editor.token,
          actor: editor.current!.uid,
          site: site,
        );
        final files = [
          'صورة-أفقية.png',
          'صورة-رأسية.jpg',
          'صورة-ويب.webp',
          'فيديو-اختبار.mp4',
          'فيديو-اختبار.webm',
          'مرفق-اختبار.pdf',
        ];
        final sources = <MediaSource>[];
        for (var i = 0; i < files.length; i++) {
          final name = files[i],
              bytes = File(
                i == 3
                    ? '.runtime/video-5MiB.mp4'
                    : 'assets/fixtures/phase05/$name',
              ).readAsBytesSync();
          final mime = MediaPolicy.mime(name);
          final op = await repo.prepare(
            bytes: bytes,
            name: name,
            mime: mime,
            projectId: projectId,
            alt: alt,
          );
          final thumbnail = mime.startsWith('image/')
              ? File(
                  'assets/fixtures/phase05/$name.thumbnail.png',
                ).readAsBytesSync()
              : null;
          MediaSource source;
          final watch = Stopwatch()..start();
          if (i == 0) {
            final failing = MediaRepository(
              FailRegistrationOnce(editorStore),
              tracked,
              editor.token,
              actor: editor.current!.uid,
              site: site,
            );
            await expectLater(
              failing.upload(url, op, bytes, thumbnail: thumbnail),
              throwsA(isA<DataFailure>()),
            );
            expect(
              (await editorStore.get('sites/$site/media/${op.id}')),
              isNull,
            );
            final sent = tracked.uploads;
            source = (await repo.recover(url, op))!;
            expect(tracked.uploads, sent);
            evidence(
              'P05-T05 actual Drive commit then injected reference failure; recover same receipt without another upload',
            );
          } else if (i == 1) {
            tracked.lose = true;
            await expectLater(
              repo.upload(url, op, bytes, thumbnail: thumbnail),
              throwsA(isA<TimeoutException>()),
            );
            expect(
              (await repo.pending()).any(
                (v) => v.id == op.id && v.stage == UploadStage.uncertain,
              ),
              true,
            );
            final sent = tracked.uploads;
            source = (await repo.recover(url, op))!;
            expect(tracked.uploads, sent);
            evidence(
              'P05-T06 actual committed upload, injected lost response; persistent status query recovers without resend',
            );
          } else {
            source = await repo.upload(url, op, bytes, thumbnail: thumbnail);
          }
          final again = await raw.upload(
            url,
            (await editor.token())!,
            site,
            op,
            bytes,
            thumbnail: thumbnail,
          );
          expect(again.fileId, source.fileId);
          final read = await raw.read(url, site, source.assetId);
          expect(
            sha256.convert(read).toString(),
            sha256.convert(bytes).toString(),
          );
          if (thumbnail != null) {
            expect(
              await raw.read(url, site, source.assetId, thumbnail: true),
              thumbnail,
            );
          }
          sources.add(source);
          report['assets'].add({
            'id': source.assetId,
            'fileId': source.fileId,
            'thumbnailFileId': source.thumbnailFileId,
            'folderId': source.folderId,
            'name': source.fileName,
            'mime': source.mimeType,
            'bytes': source.bytes,
            'elapsedMs': watch.elapsedMilliseconds,
            'sha256': source.hash,
          });
          evidence(
            'Actual $mime upload, same-request deduplication and anonymous byte-identical read',
          );
        }
        final before = tracked.uploads;
        await expectLater(
          repo.prepare(
            bytes: Uint8List(5242881),
            name: 'large.mp4',
            mime: 'video/mp4',
            projectId: projectId,
            alt: alt,
          ),
          throwsA(isA<DriveFailure>()),
        );
        await expectLater(
          repo.prepare(
            bytes: Uint8List.fromList([60, 104, 116, 109, 108, 62]),
            name: 'نوع-مرفوض.html',
            mime: 'text/html',
            projectId: projectId,
            alt: alt,
          ),
          throwsA(isA<DriveFailure>()),
        );
        expect(tracked.uploads, before);
        expect(sources[3].bytes, 5242880);
        evidence(
          'P05-T03 actual valid MP4 at exactly 5 MiB; oversized and unsupported inputs rejected before upload',
        );
        final projects = ProjectRepository(
              editorStore,
              actor: editor.current!.uid,
              site: site,
            ),
            ids = sources.map((v) => v.assetId).toList();
        await projects.saveDraft(
          projectId,
          content(ids, projectId),
          expectedRevision: 0,
        );
        await projects.publish(projectId, expectedRevision: 1);
        expect(
          (await visitor.get(
            'sites/$site/projects/$projectId',
          ))!.data['assets'].length,
          6,
        );
        await projects.saveDraft(
          sharedId,
          content([ids.first], sharedId),
          expectedRevision: 0,
        );
        await projects.publish(sharedId, expectedRevision: 1);
        await repo.link(sharedId, [], expectedRevision: 2);
        expect(
          await repo.usages(ids.first),
          containsAll([projectId, sharedId]),
        ); // Old publication still uses it.
        await projects.unpublish(sharedId, expectedRevision: 3);
        expect(await repo.usages(ids.first), [projectId]);
        expect(await raw.read(url, site, ids.first), isNotEmpty);
        evidence(
          'P05-T07 one actual file in two projects; draft unlink preserves published usage; unpublish keeps other reference',
        );
        final reordered = [ids[1], ids[0], ...ids.skip(2)];
        await repo.link(projectId, reordered, expectedRevision: 2);
        await projects.saveDraft(
          projectId,
          content(reordered, projectId, title: 'Renamed technical media test'),
          expectedRevision: 3,
        );
        await projects.publish(projectId, expectedRevision: 4);
        final published = (await visitor.get(
          'sites/$site/projects/$projectId',
        ))!.data;
        expect(published['assets'][0]['id'], ids[1]);
        expect(
          (await repo.recover(
            url,
            (await editorStore.get(
              'sites/$site/mediaOperations/${ids[0]}',
            ))!.letOperation(ids[0]),
          ))!.folderId,
          sources[0].folderId,
        );
        evidence(
          'P05-T02/T11 Arabic landscape/portrait names, stable folder after title change, order and portrait cover persisted',
        );
        await projects.archive(projectId, expectedRevision: 5);
        expect(await visitor.get('sites/$site/projects/$projectId'), isNull);
        await projects.restore(projectId, expectedRevision: 6);
        await projects.publish(projectId, expectedRevision: 7);
        final secondSession = RestAccountAuth(
          FirebaseAuthApi(key),
          TestVault(),
        );
        await secondSession.signIn(login, password);
        final secondStore = store(secondSession);
        expect(
          (await ProjectRepository(
            secondStore,
            actor: secondSession.current!.uid,
            site: site,
          ).getDraft(projectId))!.content.mediaIds,
          reordered,
        );
        expect(
          (await MediaRepository(
            secondStore,
            raw,
            secondSession.token,
            actor: secondSession.current!.uid,
            site: site,
          ).list()).any((v) => v.id == ids.first),
          true,
        );
        expect(await raw.read(url, site, ids.first), isNotEmpty);
        secondStore.close();
        await secondSession.dispose();
        evidence(
          'P05-T10 actual archive/restore/republication and independent REST login retain data/file references',
        );
        report['projectId'] = projectId;
        report['sharedId'] = sharedId;
        report['publicGalleryPath'] =
            '/#/validation/media-gallery?site=$site&project=$projectId';
        report['complete'] = true;
      } finally {
        File(
          'phases/results/05/checks/dart-rest-cloud.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
        managerStore.close();
        editorStore.close();
        visitor.close();
        bridge.close();
        api.close();
        await manager.dispose();
        await editor.dispose();
        await outsider.dispose();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

extension OperationDocument on StoredDocument {
  UploadOperation letOperation(String id) => UploadOperation.fromMap(id, data);
}
