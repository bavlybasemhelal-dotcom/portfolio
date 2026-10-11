import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../domain/media.dart';
import '../domain/project.dart';
import '../features/media/drive_bridge.dart';
import '../features/media/media_transport.dart';
import 'document_store.dart';
import 'project_repository.dart';
import 'read_collection.dart';

class MediaRepository {
  final DocumentStore store;
  final MediaTransport transport;
  final TokenGetter token;
  final String actor, site;
  MediaRepository(
    this.store,
    this.transport,
    this.token, {
    required this.actor,
    this.site = 'yogen',
  });
  String path(String collection, String id) => 'sites/$site/$collection/$id';
  Future<String> credential() async {
    final role = await store.get(path('adminUsers', actor));
    if (role?.data['enabled'] != true ||
        !['manager', 'editor'].contains(role?.data['role'])) {
      throw const DriveFailure('upload_not_allowed');
    }
    final result = await token();
    if (result == null) throw const DriveFailure('authentication_required');
    return result;
  }

  Future<List<MediaEntry>> list({String search = '', String kind = ''}) async {
    final docs = await readCollection(store, 'sites/$site/media');
    final needle = search.trim().toLowerCase();
    return docs
        .where((v) => v.data['verified'] == true)
        .map((v) => MediaEntry.fromMap(v.path.split('/').last, v.data))
        .where(
          (v) =>
              (kind.isEmpty || v.mime.startsWith(kind)) &&
              (needle.isEmpty ||
                  '${v.name} ${v.alt.ar} ${v.alt.en}'.toLowerCase().contains(
                    needle,
                  )),
        )
        .toList();
  }

  Future<List<UploadOperation>> pending() async =>
      (await readCollection(store, 'sites/$site/mediaOperations'))
          .where(
            (v) =>
                v.data['createdBy'] == actor && v.data['state'] != 'registered',
          )
          .map((v) => UploadOperation.fromMap(v.path.split('/').last, v.data))
          .toList();
  Future<UploadOperation> prepare({
    required Uint8List bytes,
    required String name,
    required String mime,
    required String projectId,
    required LocalizedText alt,
    String scope = 'project',
  }) async {
    MediaPolicy.validate(bytes, mime);
    validateSignature(bytes, mime);
    if (!alt.complete || alt.ar.length > 30000 || alt.en.length > 30000) {
      throw const DriveFailure('media_alt_incomplete');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,70}$').hasMatch(projectId)) {
      throw const DriveFailure('invalid_project_id');
    }
    if (!['project', 'brand', 'team'].contains(scope)) {
      throw const DriveFailure('invalid_scope');
    }
    if (name.trim().isEmpty ||
        name.length > 180 ||
        RegExp(r'[\x00-\x1f/\\]').hasMatch(name)) {
      throw const DriveFailure('invalid_filename');
    }
    await credential();
    final random = Random.secure();
    final requestId = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final operation = UploadOperation(
      id: UploadOperation.assetId(site, actor, requestId),
      requestId: requestId,
      actor: actor,
      projectId: projectId,
      scope: scope,
      kind: mime.startsWith('image/')
          ? 'Images'
          : mime.startsWith('video/')
          ? 'Videos'
          : 'Attachments',
      fileName: name,
      mimeType: mime,
      hash: sha256.convert(bytes).toString(),
      bytes: bytes.length,
      alt: alt,
    );
    await saveOperation(operation);
    return operation;
  }

  Future<void> saveOperation(UploadOperation operation) =>
      store.transaction((tx) async {
        final old = await tx.get(path('mediaOperations', operation.id));
        if (old != null && old.data['createdBy'] != actor) {
          throw const DriveFailure('upload_not_allowed');
        }
        tx.set(path('mediaOperations', operation.id), {
          'requestId': operation.requestId,
          'projectId': operation.projectId,
          'scope': operation.scope,
          'kind': operation.kind,
          'fileName': operation.fileName,
          'mimeType': operation.mimeType,
          'fileSize': operation.bytes,
          'sha256': operation.hash,
          'alt': operation.alt.toMap(),
          'state': operation.stage.name,
          'createdAt': old?.data['createdAt'] ?? serverTime,
          'createdBy': actor,
          'updatedAt': serverTime,
          'updatedBy': actor,
        });
      });
  Future<MediaSource> upload(
    String url,
    UploadOperation operation,
    Uint8List bytes, {
    Uint8List? thumbnail,
    void Function(UploadStage)? onStage,
  }) async {
    operation.matches(bytes);
    MediaPolicy.validate(bytes, operation.mimeType);
    final credentialValue = await credential();
    await saveOperation(operation.at(UploadStage.uploading));
    onStage?.call(UploadStage.uploading);
    MediaSource source;
    try {
      source = await transport.upload(
        url,
        credentialValue,
        site,
        operation,
        bytes,
        thumbnail: thumbnail,
      );
    } on TimeoutException {
      try {
        await saveOperation(operation.at(UploadStage.uncertain));
      } catch (_) {
        /* prior operation survives */
      }
      onStage?.call(UploadStage.uncertain);
      rethrow;
    } catch (_) {
      try {
        await saveOperation(operation.at(UploadStage.uncertain));
      } catch (_) {
        /* query status before retry */
      }
      onStage?.call(UploadStage.uncertain);
      rethrow;
    }
    onStage?.call(UploadStage.uploaded);
    await register(operation, source);
    onStage?.call(UploadStage.registered);
    return source;
  }

  Future<MediaSource?> recover(String url, UploadOperation operation) async {
    if (operation.actor != actor) {
      throw const DriveFailure('upload_not_allowed');
    }
    final source = await transport.status(
      url,
      await credential(),
      site,
      operation,
    );
    if (source != null) await register(operation, source);
    return source; // No blind upload: the caller can reselect the SAME file if absent.
  }

  Future<void> register(UploadOperation operation, MediaSource source) async {
    if (source.assetId != operation.id ||
        source.requestId != operation.requestId ||
        source.hash != operation.hash ||
        source.bytes != operation.bytes ||
        source.uploadedBy != actor ||
        source.projectId != operation.projectId ||
        source.scope != operation.scope ||
        source.fileName != operation.fileName ||
        source.mimeType != operation.mimeType) {
      throw const DriveFailure('request_conflict');
    }
    await store.transaction((tx) async {
      final receipt = await tx.get(path('mediaReceipts', source.assetId));
      if (receipt == null ||
          receipt.data['fileId'] != source.fileId ||
          receipt.data['sha256'] != source.hash ||
          receipt.data['public'] != true) {
        throw const DriveFailure('receipt_unavailable');
      }
      final previous = await tx.get(path('media', source.assetId));
      final pending = await tx.get(path('mediaOperations', operation.id));
      if (previous != null &&
          (previous.data['verified'] != true ||
              previous.data['public']['driveFileId'] != source.fileId ||
              previous.data['source']['sha256'] != source.hash)) {
        throw const DriveFailure('request_conflict');
      }
      if (previous == null) {
        tx.set(path('media', source.assetId), {
          'public': source.publicMap(operation.alt),
          'source': source.sourceMap(),
          'ready': true,
          'verified': true,
          'createdAt': serverTime,
          'createdBy': actor,
          'updatedAt': serverTime,
          'updatedBy': actor,
        });
      }
      if (pending != null) {
        tx.set(path('mediaOperations', operation.id), {
          ...pending.data,
          'state': UploadStage.registered.name,
          'updatedAt': serverTime,
          'updatedBy': actor,
        });
      }
    });
  }

  Future<List<String>> usages(String id) async {
    final drafts = await readCollection(store, 'sites/$site/projectDrafts');
    final published = await readCollection(store, 'sites/$site/projects');
    final ids = <String>{};
    for (final doc in [...drafts, ...published]) {
      if ((doc.data['content']['mediaIds'] as List).contains(id)) {
        ids.add(doc.path.split('/').last);
      }
    }
    return ids.toList()..sort();
  }

  Future<int> link(
    String projectId,
    List<String> mediaIds, {
    required int expectedRevision,
  }) async {
    final projects = ProjectRepository(store, actor: actor, site: site);
    final draft = await projects.getDraft(projectId);
    if (draft == null) throw const ContentFailure('draft_missing');
    projects.checkRevision(draft, expectedRevision);
    for (final id in mediaIds) {
      final media = await store.get(path('media', id));
      if (media?.data['verified'] != true || media?.data['ready'] != true) {
        throw const ContentFailure('media_not_ready');
      }
    }
    if (mediaIds.isNotEmpty) {
      final first = await store.get(path('media', mediaIds.first));
      if (!(first?.data['public']['mime'] as String? ?? '').startsWith(
        'image/',
      )) {
        throw const ContentFailure('cover_must_be_image');
      }
    }
    final content = ProjectContent.fromMap({
      ...draft.content.toMap(),
      'mediaIds': mediaIds,
    });
    return projects.saveDraft(
      projectId,
      content,
      expectedRevision: expectedRevision,
      internalNote: draft.internalNote,
    );
  }

  Future<void> updateAlt(MediaEntry entry, LocalizedText alt) async {
    if (!alt.complete) throw const DriveFailure('media_alt_incomplete');
    await store.transaction((tx) async {
      final old = await tx.get(path('media', entry.id));
      if (old == null) throw const DriveFailure('receipt_unavailable');
      tx.set(path('media', entry.id), {
        ...old.data,
        'public': {
          ...Map<String, dynamic>.from(old.data['public']),
          'alt': alt.toMap(),
        },
        'updatedAt': serverTime,
        'updatedBy': actor,
      });
    });
  }

  static void validateSignature(Uint8List bytes, String mime) {
    final b = bytes.take(16).toList();
    bool starts(List<int> signature) =>
        b.length >= signature.length &&
        List.generate(
          signature.length,
          (i) => b[i] == signature[i],
        ).every((v) => v);
    String slice(int start, int end) =>
        b.length < end ? '' : String.fromCharCodes(b.sublist(start, end));
    final valid = switch (mime) {
      'image/png' => starts([137, 80, 78, 71, 13, 10, 26, 10]),
      'image/jpeg' => starts([255, 216, 255]),
      'image/webp' => slice(0, 4) == 'RIFF' && slice(8, 12) == 'WEBP',
      'video/mp4' => slice(4, 8) == 'ftyp',
      'video/webm' => starts([26, 69, 223, 163]),
      'application/pdf' => starts([37, 80, 68, 70, 45]),
      _ => false,
    };
    if (!valid) throw const DriveFailure('signature_mismatch');
  }
}
