import 'dart:convert';
import 'package:http/http.dart' as http;

class DataFailure implements Exception {
  final String code;
  const DataFailure(this.code);
  @override
  String toString() => code;
}

class ServerTime {
  const ServerTime();
}

const serverTime = ServerTime();
typedef TokenGetter = Future<String?> Function();

class StoredDocument {
  final String path;
  final Map<String, dynamic> data;
  final String? updateTime;
  const StoredDocument(this.path, this.data, [this.updateTime]);
}

class DocumentWrite {
  final String path;
  final Map<String, Object?>? data;
  const DocumentWrite.set(this.path, this.data);
  const DocumentWrite.delete(this.path) : data = null;
}

abstract class DocumentTransaction {
  Future<StoredDocument?> get(String path);
  void set(String path, Map<String, Object?> data);
  void delete(String path);
}

abstract class DocumentStore {
  Future<StoredDocument?> get(String path);
  Future<List<StoredDocument>> list(String collection, {int limit = 30});
  Future<T> transaction<T>(Future<T> Function(DocumentTransaction tx) body);
  Future<void> commit(List<DocumentWrite> writes);
}

/// Firebase user-token REST API: rules still apply on all six Flutter platforms.
class FirestoreRestStore implements DocumentStore {
  final String projectId;
  final TokenGetter token;
  final http.Client _client;
  final String origin;
  final Duration timeout;
  FirestoreRestStore({
    required this.projectId,
    required this.token,
    http.Client? client,
    this.origin = 'https://firestore.googleapis.com',
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client() {
    final uri = Uri.parse(origin);
    if (origin != 'https://firestore.googleapis.com' &&
        !(uri.scheme == 'http' && uri.host == '127.0.0.1')) {
      throw const DataFailure('untrusted_database_endpoint');
    }
  }
  String get base =>
      '$origin/v1/projects/$projectId/databases/(default)/documents';
  void close() => _client.close();
  String documentName(String path) {
    if (path.split('/').any((s) => s.isEmpty || s == '.' || s == '..') ||
        path.contains('?') ||
        path.contains('#')) {
      throw const DataFailure('invalid_document_path');
    }
    return 'projects/$projectId/databases/(default)/documents/$path';
  }

  Future<dynamic> request(
    String url, {
    String method = 'POST',
    Object? body,
    bool missingOk = false,
  }) async {
    final credential = await token();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (credential != null) 'Authorization': 'Bearer $credential',
    };
    final req = http.Request(method, Uri.parse(url))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(req).timeout(timeout),
    ).timeout(timeout);
    if (missingOk && response.statusCode == 404) return null;
    dynamic value;
    try {
      value = jsonDecode(response.body);
    } catch (_) {
      throw const DataFailure('invalid_database_response');
    }
    if (response.statusCode >= 400) {
      throw DataFailure(
        value is Map
            ? (value['error']?['status'] as String? ?? 'database_error')
            : 'database_error',
      );
    }
    return value;
  }

  Future<StoredDocument?> read(String path) async {
    documentName(path);
    final value = await request('$base/$path', method: 'GET', missingOk: true);
    return value == null
        ? null
        : decodeDocument(Map<String, dynamic>.from(value as Map));
  }

  @override
  Future<StoredDocument?> get(String path) => read(path);
  Future<List<StoredDocument>> listAll(String collection) async {
    documentName(collection);
    final documents = <StoredDocument>[];
    final seen = <String>{};
    String? next;
    do {
      final uri = Uri.parse(
        '$base/$collection',
      ).replace(queryParameters: {'pageSize': '100', 'pageToken': ?next});
      final page = Map<String, dynamic>.from(
        await request(uri.toString(), method: 'GET') as Map,
      );
      documents.addAll(
        (page['documents'] as List? ?? []).map(
          (v) => decodeDocument(Map<String, dynamic>.from(v as Map)),
        ),
      );
      next = page['nextPageToken'] as String?;
      if (next != null && next.isNotEmpty && !seen.add(next)) {
        throw const DataFailure('database_paging_loop');
      }
    } while (next != null && next.isNotEmpty);
    return documents;
  }

  @override
  Future<List<StoredDocument>> list(String collection, {int limit = 30}) async {
    if (limit < 1 || limit > 100) {
      throw const DataFailure('invalid_query_limit');
    }
    final parts = collection.split('/');
    final name = parts.removeLast();
    final parent = parts.isEmpty ? base : '$base/${parts.join('/')}';
    final rows =
        await request(
              '$parent:runQuery',
              body: {
                'structuredQuery': {
                  'from': [
                    {'collectionId': name},
                  ],
                  'limit': limit,
                },
              },
            )
            as List;
    return rows
        .where((v) => (v as Map).containsKey('document'))
        .map(
          (v) =>
              decodeDocument(Map<String, dynamic>.from(v['document'] as Map)),
        )
        .toList();
  }

  @override
  Future<void> commit(List<DocumentWrite> writes) async {
    if (writes.isEmpty) return;
    await request(
      '$base:commit',
      body: {'writes': writes.map(encodeWrite).toList()},
    );
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(DocumentTransaction tx) body,
  ) async {
    // Firebase client transactions use optimistic version preconditions. Server
    // beginTransaction requires IAM and cannot be used with client ID tokens.
    final tx = _RestTransaction(this);
    final result = await body(tx);
    if (tx.writes.isNotEmpty) {
      final written = tx.writes.map((v) => v.path).toSet();
      final writes = tx.writes.map((write) {
        final encoded = encodeWrite(write);
        if (tx.reads.containsKey(write.path)) {
          encoded['currentDocument'] = tx.precondition(write.path);
        }
        return encoded;
      }).toList();
      for (final path in tx.reads.keys.where(
        (path) => !written.contains(path),
      )) {
        writes.add({
          'verify': documentName(path),
          'currentDocument': tx.precondition(path),
        });
      }
      await request('$base:commit', body: {'writes': writes});
    }
    return result; // Never silently replay an unknown commit outcome.
  }

  Map<String, Object?> encodeWrite(DocumentWrite write) {
    final name = documentName(write.path);
    if (write.data == null) return {'delete': name};
    final fields = <String, Object?>{};
    final transforms = <Map<String, Object?>>[];
    for (final entry in write.data!.entries) {
      if (entry.value is ServerTime) {
        transforms.add({
          'fieldPath': entry.key,
          'setToServerValue': 'REQUEST_TIME',
        });
      } else {
        fields[entry.key] = encodeValue(entry.value);
      }
    }
    return {
      'update': {'name': name, 'fields': fields},
      if (transforms.isNotEmpty) 'updateTransforms': transforms,
    };
  }

  static Map<String, Object?> encodeValue(Object? value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is num) return {'doubleValue': value};
    if (value is String) return {'stringValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is List) {
      return {
        'arrayValue': {'values': value.map(encodeValue).toList()},
      };
    }
    if (value is Map) {
      return {
        'mapValue': {
          'fields': value.map((k, v) => MapEntry(k.toString(), encodeValue(v))),
        },
      };
    }
    throw const DataFailure('unsupported_database_value');
  }

  static dynamic decodeValue(Map<String, dynamic> v) {
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('integerValue')) {
      return int.parse(v['integerValue'] as String);
    }
    if (v.containsKey('doubleValue')) return v['doubleValue'];
    if (v.containsKey('booleanValue')) return v['booleanValue'];
    if (v.containsKey('timestampValue')) {
      return DateTime.parse(v['timestampValue'] as String);
    }
    if (v.containsKey('arrayValue')) {
      return (v['arrayValue']['values'] as List? ?? [])
          .map((x) => decodeValue(Map<String, dynamic>.from(x as Map)))
          .toList();
    }
    if (v.containsKey('mapValue')) {
      return (v['mapValue']['fields'] as Map? ?? {}).map(
        (k, x) => MapEntry(
          k.toString(),
          decodeValue(Map<String, dynamic>.from(x as Map)),
        ),
      );
    }
    throw const DataFailure('unsupported_database_value');
  }

  StoredDocument decodeDocument(Map<String, dynamic> v) => StoredDocument(
    (v['name'] as String).split('/documents/').last,
    (v['fields'] as Map? ?? {}).map(
      (k, x) => MapEntry(
        k.toString(),
        decodeValue(Map<String, dynamic>.from(x as Map)),
      ),
    ),
    v['updateTime'] as String?,
  );
}

class _RestTransaction implements DocumentTransaction {
  final FirestoreRestStore store;
  final reads = <String, StoredDocument?>{};
  final writes = <DocumentWrite>[];
  _RestTransaction(this.store);
  Map<String, Object?> precondition(String path) => reads[path] == null
      ? {'exists': false}
      : {'updateTime': reads[path]!.updateTime};
  @override
  Future<StoredDocument?> get(String path) async {
    if (writes.isNotEmpty) {
      throw const DataFailure('read_after_transaction_write');
    }
    if (reads.containsKey(path)) return reads[path];
    final value = await store.get(path);
    reads[path] = value;
    return value;
  }

  @override
  void set(String path, Map<String, Object?> data) =>
      writes.add(DocumentWrite.set(path, data));
  @override
  void delete(String path) => writes.add(DocumentWrite.delete(path));
}
