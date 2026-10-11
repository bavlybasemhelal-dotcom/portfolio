import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class DriveFailure implements Exception {
  final String code;
  const DriveFailure(this.code);
  @override
  String toString() => code;
}

/// Transfer bounds are guardrails for the experiment, not proven cloud limits.
class MediaPolicy {
  static const maxTestBytes = 5 * 1024 * 1024;
  static void validateSize(int? size) {
    if (size == null || size > maxTestBytes) {
      throw const DriveFailure('unverified_size');
    }
    if (size <= 0) throw const DriveFailure('empty_file');
  }

  static const types = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'video/mp4',
    'video/webm',
    'application/pdf',
  };
  static void validate(
    Uint8List bytes,
    String mime, {
    int limit = maxTestBytes,
  }) {
    if (bytes.isEmpty) throw const DriveFailure('empty_file');
    if (!types.contains(mime)) throw const DriveFailure('unsupported_type');
    if (bytes.length > limit) throw const DriveFailure('unverified_size');
  }

  static String mime(String name) =>
      switch (name.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'mp4' => 'video/mp4',
        'webm' => 'video/webm',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream',
      };
}

class DriveFile {
  final String id, name, mime, directUrl, viewUrl, downloadUrl;
  final int bytes;
  const DriveFile({
    required this.id,
    required this.name,
    required this.mime,
    required this.bytes,
    required this.directUrl,
    required this.viewUrl,
    required this.downloadUrl,
  });
  factory DriveFile.fromMap(Map<String, dynamic> map) {
    if (map['success'] != true) {
      throw DriveFailure(map['error']?.toString() ?? 'upload_failed');
    }
    final id = map['fileId']?.toString() ?? '';
    final size = map['fileSize'];
    if (!RegExp(r'^[\w-]{10,}$').hasMatch(id) || size is! num || size <= 0) {
      throw const DriveFailure('invalid_upload_response');
    }
    return DriveFile(
      id: id,
      name: map['fileName']?.toString() ?? '',
      mime: map['mimeType']?.toString() ?? '',
      bytes: size.toInt(),
      directUrl: map['directUrl']?.toString() ?? '',
      viewUrl: map['viewUrl']?.toString() ?? '',
      downloadUrl: map['downloadUrl']?.toString() ?? '',
    );
  }
  Map<String, Object?> toMap() => {
    'fileId': id,
    'fileName': name,
    'mimeType': mime,
    'fileSize': bytes,
    'directUrl': directUrl,
    'viewUrl': viewUrl,
    'downloadUrl': downloadUrl,
  };
}

class DriveBridge {
  final http.Client client;
  final Duration timeout;
  DriveBridge({http.Client? client, this.timeout = const Duration(seconds: 60)})
    : client = client ?? http.Client();

  static Uri endpoint(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'script.google.com' ||
        !RegExp(r'^/macros/s/[\w-]+/exec$').hasMatch(uri.path) ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const DriveFailure('invalid_web_app_url');
    }
    return uri;
  }

  Future<Map<String, dynamic>> request(
    String url,
    Map<String, Object?> body, {
    Future<void>? abortTrigger,
  }) async {
    final request =
        http.AbortableRequest('POST', endpoint(url), abortTrigger: abortTrigger)
          ..headers['Content-Type'] = 'text/plain;charset=utf-8'
          ..body = jsonEncode(body);
    var response = await http.Response.fromStream(
      await client.send(request).timeout(timeout),
    ).timeout(timeout);
    // Apps Script ContentService redirects to a one-use Google URL. Browser
    // clients follow it; native clients can expose the POST redirect instead.
    if ([302, 303].contains(response.statusCode)) {
      final target = Uri.tryParse(response.headers['location'] ?? '');
      if (target == null ||
          target.scheme != 'https' ||
          target.host != 'script.googleusercontent.com' ||
          target.userInfo.isNotEmpty) {
        throw const DriveFailure('untrusted_content_redirect');
      }
      response = await http.Response.fromStream(
        await client
            .send(
              http.AbortableRequest('GET', target, abortTrigger: abortTrigger),
            )
            .timeout(timeout),
      ).timeout(timeout);
    }
    if (response.statusCode != 200) {
      throw DriveFailure('http_${response.statusCode}');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (decoded['success'] != true) {
        throw DriveFailure(decoded['error']?.toString() ?? 'bridge_failure');
      }
      return decoded;
    } on FormatException {
      throw const DriveFailure('invalid_json_response');
    }
  }

  Future<Map<String, dynamic>> ping(String url, String token) =>
      request(url, {'action': 'ping', 'idToken': token});

  Future<DriveFile> upload({
    required String url,
    required String token,
    required Uint8List bytes,
    required String name,
    required String mime,
    required String requestId,
  }) async {
    MediaPolicy.validate(bytes, mime);
    return DriveFile.fromMap(
      await request(url, {
        'action': 'upload',
        'idToken': token,
        'fileData': base64Encode(bytes),
        'fileName': name,
        'mimeType': mime,
        'category': 'phase03',
        'requestId': requestId,
      }),
    );
  }

  Future<Uint8List> image(String url, String fileId) async {
    final result = await request(url, {'action': 'image', 'fileId': fileId});
    if (!(result['mimeType']?.toString().startsWith('image/') ?? false)) {
      throw const DriveFailure('not_an_image');
    }
    return base64Decode(result['fileData'] as String);
  }

  void close() => client.close();

  Future<Uint8List> video(String url, String fileId) async {
    final result = await request(url, {'action': 'video', 'fileId': fileId});
    if (result['mimeType'] != 'video/mp4') {
      throw const DriveFailure('not_an_mp4');
    }
    final bytes = base64Decode(result['fileData'] as String);
    MediaPolicy.validate(bytes, 'video/mp4');
    return bytes;
  }
}
