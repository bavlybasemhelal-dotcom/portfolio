import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../features/media/drive_bridge.dart';
import 'project.dart';

enum UploadStage { prepared, uploading, uncertain, uploaded, registered }

class MediaSource {
  final String assetId,
      fileId,
      fileName,
      mimeType,
      folderId,
      projectId,
      scope,
      kind,
      requestId,
      uploadedBy,
      hash,
      thumbnailFileId,
      viewUrl,
      downloadUrl;
  final int bytes;
  const MediaSource({
    required this.assetId,
    required this.fileId,
    required this.fileName,
    required this.mimeType,
    required this.folderId,
    required this.projectId,
    required this.scope,
    required this.kind,
    required this.requestId,
    required this.uploadedBy,
    required this.hash,
    required this.bytes,
    this.thumbnailFileId = '',
    required this.viewUrl,
    required this.downloadUrl,
  });
  factory MediaSource.fromMap(Map<String, dynamic> v) {
    final source = MediaSource(
      assetId: v['assetId'] as String? ?? '',
      fileId: v['fileId'] as String? ?? '',
      fileName: v['fileName'] as String? ?? '',
      mimeType: v['mimeType'] as String? ?? '',
      folderId: v['folderId'] as String? ?? '',
      projectId: v['projectId'] as String? ?? '',
      scope: v['scope'] as String? ?? '',
      kind: v['kind'] as String? ?? '',
      requestId: v['requestId'] as String? ?? '',
      uploadedBy: v['uploadedBy'] as String? ?? '',
      hash: v['sha256'] as String? ?? '',
      bytes: (v['fileSize'] as num? ?? 0).toInt(),
      thumbnailFileId: v['thumbnailFileId'] as String? ?? '',
      viewUrl: v['viewUrl'] as String? ?? '',
      downloadUrl: v['downloadUrl'] as String? ?? '',
    );
    if (!RegExp(r'^m_[a-f0-9]{64}$').hasMatch(source.assetId) ||
        !RegExp(r'^[\w-]{10,200}$').hasMatch(source.fileId) ||
        !RegExp(r'^[\w-]{10,200}$').hasMatch(source.folderId) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(source.hash) ||
        source.fileName.trim().isEmpty ||
        !MediaPolicy.types.contains(source.mimeType) ||
        source.bytes <= 0 ||
        source.bytes > MediaPolicy.maxTestBytes ||
        (source.thumbnailFileId.isNotEmpty &&
            !RegExp(r'^[\w-]{10,200}$').hasMatch(source.thumbnailFileId))) {
      throw const DriveFailure('invalid_upload_response');
    }
    return source;
  }
  Map<String, Object?> sourceMap() => {
    'folderId': folderId,
    'originProjectId': projectId,
    'scope': scope,
    'requestId': requestId,
    'sha256': hash,
    'uploadedBy': uploadedBy,
    'viewUrl': viewUrl,
    'downloadUrl': downloadUrl,
  };
  Map<String, Object?> publicMap(LocalizedText alt) => {
    'id': assetId,
    'driveFileId': fileId,
    'name': fileName,
    'mime': mimeType,
    'bytes': bytes,
    'alt': alt.toMap(),
    'thumbnailDriveFileId': thumbnailFileId,
  };
}

class UploadOperation {
  final String id,
      requestId,
      actor,
      projectId,
      scope,
      kind,
      fileName,
      mimeType,
      hash;
  final int bytes;
  final LocalizedText alt;
  final UploadStage stage;
  final DateTime? createdAt;
  const UploadOperation({
    required this.id,
    required this.requestId,
    required this.actor,
    required this.projectId,
    required this.scope,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.hash,
    required this.bytes,
    required this.alt,
    this.stage = UploadStage.prepared,
    this.createdAt,
  });
  factory UploadOperation.fromMap(String id, Map<String, dynamic> v) =>
      UploadOperation(
        id: id,
        requestId: v['requestId'] as String,
        actor: v['createdBy'] as String,
        projectId: v['projectId'] as String,
        scope: v['scope'] as String,
        kind: v['kind'] as String,
        fileName: v['fileName'] as String,
        mimeType: v['mimeType'] as String,
        hash: v['sha256'] as String,
        bytes: (v['fileSize'] as num).toInt(),
        alt: LocalizedText.fromMap(Map<String, dynamic>.from(v['alt'] as Map)),
        stage: UploadStage.values.byName(v['state'] as String),
        createdAt: v['createdAt'] as DateTime?,
      );
  UploadOperation at(UploadStage value) => UploadOperation(
    id: id,
    requestId: requestId,
    actor: actor,
    projectId: projectId,
    scope: scope,
    kind: kind,
    fileName: fileName,
    mimeType: mimeType,
    hash: hash,
    bytes: bytes,
    alt: alt,
    stage: value,
    createdAt: createdAt,
  );
  Map<String, Object?> target(String site) => {
    'site': site,
    'projectId': projectId,
    'scope': scope,
    'kind': kind,
    'requestId': requestId,
  };
  static String assetId(String site, String actor, String requestId) =>
      'm_${sha256.convert(utf8.encode('$site:$actor:$requestId'))}';
  void matches(Uint8List data) {
    if (data.length != bytes || sha256.convert(data).toString() != hash) {
      throw const DriveFailure('selected_file_differs');
    }
  }
}

class MediaEntry {
  final String id;
  final Map<String, dynamic> public, source;
  const MediaEntry(this.id, this.public, this.source);
  factory MediaEntry.fromMap(String id, Map<String, dynamic> v) => MediaEntry(
    id,
    Map<String, dynamic>.from(v['public'] as Map),
    Map<String, dynamic>.from(v['source'] as Map),
  );
  String get name => public['name'] as String;
  String get mime => public['mime'] as String;
  bool get image => mime.startsWith('image/');
  bool get video => mime.startsWith('video/');
  int get bytes => (public['bytes'] as num).toInt();
  LocalizedText get alt =>
      LocalizedText.fromMap(Map<String, dynamic>.from(public['alt'] as Map));
}
