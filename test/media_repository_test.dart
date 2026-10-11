import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/media_repository.dart';
import 'package:yogen_portfolio/data/media_settings_repository.dart';
import 'package:yogen_portfolio/data/project_repository.dart';
import 'package:yogen_portfolio/domain/media.dart';
import 'package:yogen_portfolio/domain/project.dart';
import 'package:yogen_portfolio/features/media/drive_bridge.dart';
import 'package:yogen_portfolio/features/media/media_transport.dart';

class MemoryStore implements DocumentStore {
  final Map<String, Map<String, dynamic>> docs = {};
  int registrationFailures = 0;
  @override
  Future<StoredDocument?> get(String path) async =>
      docs[path] == null ? null : StoredDocument(path, Map.from(docs[path]!));
  @override
  Future<List<StoredDocument>> list(
    String collection, {
    int limit = 30,
  }) async => docs.entries
      .where(
        (v) =>
            v.key.startsWith('$collection/') &&
            v.key.split('/').length == collection.split('/').length + 1,
      )
      .take(limit)
      .map((v) => StoredDocument(v.key, Map.from(v.value)))
      .toList();
  @override
  Future<void> commit(List<DocumentWrite> writes) async {
    if (writes.any((v) => v.path.contains('/media/')) &&
        registrationFailures-- > 0) {
      throw const DataFailure('UNAVAILABLE');
    }
    for (final write in writes) {
      if (write.data == null) {
        docs.remove(write.path);
        continue;
      }
      docs[write.path] = write.data!.map(
        (k, v) => MapEntry(k, v is ServerTime ? DateTime.now().toUtc() : v),
      );
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DocumentTransaction) body) async {
    final tx = MemoryTransaction(this);
    final value = await body(tx);
    await commit(tx.writes);
    return value;
  }
}

class MemoryTransaction implements DocumentTransaction {
  final MemoryStore store;
  final List<DocumentWrite> writes = [];
  MemoryTransaction(this.store);
  @override
  Future<StoredDocument?> get(String path) => store.get(path);
  @override
  void set(String path, Map<String, Object?> data) =>
      writes.add(DocumentWrite.set(path, data));
  @override
  void delete(String path) => writes.add(DocumentWrite.delete(path));
}

class FixtureTransport implements MediaTransport {
  final MemoryStore store;
  final Map<String, MediaSource> drive = {};
  int uploads = 0, statuses = 0, pings = 0, reads = 0;
  bool loseResponse = false;
  Completer<Uint8List>? pendingRead;
  FixtureTransport(this.store);
  @override
  Future<Map<String, dynamic>> ping(
    String url,
    String token,
    String site,
  ) async {
    pings++;
    return {
      'success': true,
      'version': 5,
      'projectId': 'portfolio-14d15',
      'maxBytes': 5242880,
      'rootFolderId': 'fixture-root-1234',
      'rootFolderName': 'YOGEN',
    };
  }

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
    final source = drive.putIfAbsent(
      operation.id,
      () => MediaSource(
        assetId: operation.id,
        fileId: 'drive-fixture-12345',
        fileName: operation.fileName,
        mimeType: operation.mimeType,
        folderId: 'folder-fixture-12345',
        projectId: operation.projectId,
        scope: operation.scope,
        kind: operation.kind,
        requestId: operation.requestId,
        uploadedBy: operation.actor,
        hash: operation.hash,
        bytes: operation.bytes,
        viewUrl: 'https://drive.google.com/file/d/drive-fixture-12345/view',
        downloadUrl:
            'https://drive.google.com/uc?export=download&id=drive-fixture-12345',
      ),
    );
    store.docs['sites/$site/mediaReceipts/${operation.id}'] = {
      'fileId': source.fileId,
      'sha256': source.hash,
      'public': true,
    };
    if (loseResponse) throw TimeoutException('Injected after server commit');
    return source;
  }

  @override
  Future<MediaSource?> status(
    String url,
    String token,
    String site,
    UploadOperation operation,
  ) async {
    statuses++;
    return drive[operation.id];
  }

  @override
  Future<Uint8List> read(
    String url,
    String site,
    String id, {
    bool thumbnail = false,
    Future<void>? abortTrigger,
  }) async {
    reads++;
    return pendingRead?.future ??
        Uint8List.fromList(List.generate(4, (_) => id.codeUnitAt(0)));
  }
}

void main() {
  const site = 'phase04-test',
      actor = 'editor',
      url = 'https://script.google.com/macros/s/test/exec';
  final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]);
  const description = LocalizedText(
    ar: 'صورة للاختبار',
    en: 'Image for testing',
  );
  late MemoryStore store;
  late FixtureTransport transport;
  late MediaRepository repo;
  setUp(() {
    store = MemoryStore();
    store.docs['sites/$site/adminUsers/$actor'] = {
      'role': 'editor',
      'enabled': true,
    };
    store.docs['sites/$site/adminUsers/manager'] = {
      'role': 'manager',
      'enabled': true,
    };
    transport = FixtureTransport(store);
    repo = MediaRepository(
      store,
      transport,
      () async => 'test-token',
      actor: actor,
      site: site,
    );
  });
  Future<UploadOperation> prepare() => repo.prepare(
    bytes: png,
    name: 'صورة عربية.png',
    mime: 'image/png',
    projectId: 'stable-project',
    alt: description,
  );
  test(
    'Manager tests and atomically saves private settings and public route; editor refuses before ping',
    () async {
      await expectLater(
        MediaSettingsRepository(
          store,
          transport,
          () async => 'token',
          actor: actor,
          site: site,
        ).testAndSave(url),
        throwsA(isA<DriveFailure>()),
      );
      expect(transport.pings, 0);
      final settings = MediaSettingsRepository(
        store,
        transport,
        () async => 'token',
        actor: 'manager',
        site: site,
      );
      await settings.testAndSave(url);
      expect((await settings.get())!.data['administrativeEmail'], '');
      expect(await MediaSettingsRepository.endpoint(store, site), url);
    },
  );
  test(
    'P05-T03 guards file size, signature, type and bilingual alt before any operation',
    () async {
      for (final data in [
        Uint8List(0),
        Uint8List(MediaPolicy.maxTestBytes + 1),
      ]) {
        await expectLater(
          repo.prepare(
            bytes: data,
            name: 'a.png',
            mime: 'image/png',
            projectId: 'p',
            alt: description,
          ),
          throwsA(isA<DriveFailure>()),
        );
      }
      await expectLater(
        repo.prepare(
          bytes: png,
          name: 'a.svg',
          mime: 'image/svg+xml',
          projectId: 'p',
          alt: description,
        ),
        throwsA(isA<DriveFailure>()),
      );
      await expectLater(
        repo.prepare(
          bytes: png,
          name: 'a.pdf',
          mime: 'application/pdf',
          projectId: 'p',
          alt: description,
        ),
        throwsA(isA<DriveFailure>()),
      );
      await expectLater(
        repo.prepare(
          bytes: png,
          name: 'a.png',
          mime: 'image/png',
          projectId: 'p',
          alt: const LocalizedText(ar: 'فقط'),
        ),
        throwsA(isA<DriveFailure>()),
      );
      final atLimit = Uint8List(MediaPolicy.maxTestBytes)
        ..setRange(0, png.length, png);
      final operation = await repo.prepare(
        bytes: atLimit,
        name: 'at-limit.png',
        mime: 'image/png',
        projectId: 'p',
        alt: description,
      );
      expect(operation.bytes, 5242880);
      expect(transport.uploads, 0);
    },
  );
  test(
    'P05-T05 registration failure preserves request and recovers same Drive file without resend',
    () async {
      final operation = await prepare();
      store.registrationFailures = 1;
      await expectLater(
        repo.upload(url, operation, png),
        throwsA(isA<DataFailure>()),
      );
      expect(transport.drive.length, 1);
      expect(transport.uploads, 1);
      final restored = (await repo.pending()).single;
      final source = await repo.recover(url, restored);
      expect(source!.assetId, operation.id);
      expect(transport.uploads, 1);
      expect(transport.statuses, 1);
      expect((await repo.pending()), isEmpty);
      expect((await repo.list()).single.name, 'صورة عربية.png');
      expect(
        jsonEncode(store.docs, toEncodable: (v) => v.toString()),
        isNot(contains('fileData')),
      );
    },
  );
  test(
    'P05-T06 timeout after server commit is reconciled before retry; changed file cannot send',
    () async {
      final operation = await prepare();
      transport.loseResponse = true;
      await expectLater(
        repo.upload(url, operation, png),
        throwsA(isA<TimeoutException>()),
      );
      expect((await repo.pending()).single.stage, UploadStage.uncertain);
      await repo.recover(url, operation);
      expect(transport.uploads, 1);
      expect(transport.drive.length, 1);
      await expectLater(
        repo.upload(url, operation, Uint8List.fromList([...png, 1])),
        throwsA(isA<DriveFailure>()),
      );
      expect(transport.uploads, 1);
    },
  );
  test(
    'Roleless or revoked member cannot prepare or query upload status',
    () async {
      final operation = await prepare();
      store.docs['sites/$site/adminUsers/$actor']!['enabled'] = false;
      await expectLater(
        repo.recover(url, operation),
        throwsA(isA<DriveFailure>()),
      );
      expect(transport.statuses, 0);
      await expectLater(prepare(), throwsA(isA<DriveFailure>()));
    },
  );
  test(
    'P05-T07/T10/T11 shared file survives unlink, ordering, archive and restore; revision conflicts fail',
    () async {
      final operation = await prepare();
      await repo.upload(url, operation, png);
      final projects = ProjectRepository(store, actor: actor, site: site);
      for (final id in ['project-a', 'project-b']) {
        await projects.saveDraft(
          id,
          const ProjectContent(),
          expectedRevision: 0,
        );
        await repo.link(id, [operation.id], expectedRevision: 1);
      }
      expect(
        await repo.usages(operation.id),
        containsAll(['project-a', 'project-b']),
      );
      await repo.link('project-a', [], expectedRevision: 2);
      expect(await repo.usages(operation.id), ['project-b']);
      await projects.archive('project-b', expectedRevision: 2);
      await projects.restore('project-b', expectedRevision: 3);
      expect((await projects.getDraft('project-b'))!.content.mediaIds, [
        operation.id,
      ]);
      expect(transport.drive.length, 1);
      await expectLater(
        repo.link('project-a', [operation.id], expectedRevision: 2),
        throwsA(isA<ContentFailure>()),
      );
      expect((await repo.list()).single.id, operation.id);
    },
  );
  test(
    'Cache coalesces, evicts by bytes, retries failures and ignores late completion after clear',
    () async {
      final cache = MediaByteCache(transport, maxBytes: 8);
      transport.pendingRead = Completer();
      final first = cache.read(url, site, 'a'),
          second = cache.read(url, site, 'a');
      expect(transport.reads, 1);
      transport.pendingRead!.complete(Uint8List(4));
      await Future.wait([first, second]);
      expect(cache.bytesHeld, 4);
      transport.pendingRead = null;
      await cache.read(url, site, 'b');
      await cache.read(url, site, 'c');
      expect(cache.bytesHeld, 8);
      transport.pendingRead = Completer();
      final late = cache.read(url, site, 'd');
      cache.clear();
      transport.pendingRead!.complete(Uint8List(4));
      await late;
      expect(cache.bytesHeld, 0);
      transport.pendingRead = Completer();
      final fail = cache.read(url, site, 'e');
      transport.pendingRead!.completeError(StateError('network'));
      await expectLater(fail, throwsStateError);
      transport.pendingRead = null;
      await cache.read(url, site, 'e', retry: true);
      expect(cache.bytesHeld, 4);
    },
  );
}
