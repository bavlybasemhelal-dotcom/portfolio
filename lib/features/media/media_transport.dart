import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../domain/media.dart';
import 'drive_bridge.dart';

abstract class MediaTransport {
  Future<Map<String, dynamic>> ping(String url, String token, String site);
  Future<MediaSource> upload(
    String url,
    String token,
    String site,
    UploadOperation operation,
    Uint8List bytes, {
    Uint8List? thumbnail,
  });
  Future<MediaSource?> status(
    String url,
    String token,
    String site,
    UploadOperation operation,
  );
  Future<Uint8List> read(
    String url,
    String site,
    String assetId, {
    bool thumbnail = false,
    Future<void>? abortTrigger,
  });
}

class AppsScriptMediaTransport implements MediaTransport {
  final DriveBridge bridge;
  AppsScriptMediaTransport(this.bridge);
  @override
  Future<Map<String, dynamic>> ping(String url, String token, String site) =>
      bridge.request(url, {'action': 'ping', 'site': site, 'idToken': token});
  @override
  Future<MediaSource> upload(
    String url,
    String token,
    String site,
    UploadOperation operation,
    Uint8List bytes, {
    Uint8List? thumbnail,
  }) async => MediaSource.fromMap(
    await bridge.request(url, {
      'action': 'upload',
      'idToken': token,
      ...operation.target(site),
      'fileName': operation.fileName,
      'mimeType': operation.mimeType,
      'fileData': base64Encode(bytes),
      if (thumbnail != null) 'thumbnailData': base64Encode(thumbnail),
    }),
  );
  @override
  Future<MediaSource?> status(
    String url,
    String token,
    String site,
    UploadOperation operation,
  ) async {
    final result = await bridge.request(url, {
      'action': 'upload_status',
      'idToken': token,
      ...operation.target(site),
    });
    return result['found'] == true ? MediaSource.fromMap(result) : null;
  }

  @override
  Future<Uint8List> read(
    String url,
    String site,
    String assetId, {
    bool thumbnail = false,
    Future<void>? abortTrigger,
  }) async {
    final value = await bridge.request(url, {
      'action': 'read',
      'site': site,
      'assetId': assetId,
      'thumbnail': thumbnail,
    }, abortTrigger: abortTrigger);
    final bytes = base64Decode(value['fileData'] as String);
    if (bytes.length != value['fileSize']) {
      throw const DriveFailure('invalid_media_response');
    }
    MediaPolicy.validate(bytes, value['mimeType'] as String);
    return bytes;
  }
}

/// Byte-bounded LRU cache. Failed requests are not cached; in-flight reads coalesce.
class MediaByteCache {
  final MediaTransport transport;
  final int maxBytes;
  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List>> _pending = {};
  final Map<String, Completer<void>> _abort = {};
  int bytesHeld = 0;
  int _generation = 0;
  MediaByteCache(this.transport, {this.maxBytes = 12 * 1024 * 1024});
  Future<Uint8List> read(
    String url,
    String site,
    String id, {
    bool thumbnail = false,
    bool retry = false,
  }) {
    final key = '$url|$site|$id|$thumbnail';
    if (retry) {
      final old = _cache.remove(key);
      if (old != null) bytesHeld -= old.length;
    }
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return Future.value(cached);
    }
    if (_pending.containsKey(key)) return _pending[key]!;
    final epoch = _generation;
    final abort = Completer<void>();
    _abort[key] = abort;
    final future = transport
        .read(url, site, id, thumbnail: thumbnail, abortTrigger: abort.future)
        .then((bytes) {
          if (epoch == _generation && bytes.length <= maxBytes) {
            while (_cache.isNotEmpty && bytesHeld + bytes.length > maxBytes) {
              bytesHeld -= _cache.remove(_cache.keys.first)!.length;
            }
            _cache[key] = bytes;
            bytesHeld += bytes.length;
          }
          return bytes;
        })
        .whenComplete(() {
          if (epoch == _generation) {
            _pending.remove(key);
            _abort.remove(key);
          }
        });
    _pending[key] = future;
    return future;
  }

  void clear() {
    _generation++;
    for (final abort in _abort.values) {
      if (!abort.isCompleted) abort.complete();
    }
    _abort.clear();
    _cache.clear();
    _pending.clear();
    bytesHeld = 0;
  }
}
