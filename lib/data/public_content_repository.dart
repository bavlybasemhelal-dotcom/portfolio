import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/admin_session.dart' show activeSite;
import '../core/firebase_config.dart';
import '../domain/project.dart';
import '../features/media/drive_bridge.dart';
import '../features/media/media_transport.dart';
import 'document_store.dart';
import 'media_settings_repository.dart';
import 'company_repository.dart';

String localized(LocalizedText text, String code) =>
    code == 'ar' ? text.ar : text.en;

class PublicProject {
  final String id;
  final ProjectContent content;
  final LocalizedText category;
  final List<Map<String, dynamic>> assets;
  const PublicProject(this.id, this.content, this.category, this.assets);
  factory PublicProject.fromDocument(StoredDocument doc) {
    final v = doc.data;
    final content = ProjectContent.fromMap(
      Map<String, dynamic>.from(v['content'] as Map),
    );
    content.validatePublication();
    if (v['projectId'] != doc.path.split('/').last) {
      throw const DataFailure('invalid_publication');
    }
    final assets = (v['assets'] as List)
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
    if (assets.isEmpty ||
        !assets.first['mime'].toString().startsWith('image/')) {
      throw const DataFailure('invalid_publication');
    }
    return PublicProject(
      v['projectId'] as String,
      content,
      LocalizedText.fromMap(Map<String, dynamic>.from(v['category'] as Map)),
      assets,
    );
  }
  Map<String, LocalizedText> get filters => {
    'category:${content.categoryId}': category,
    for (final tag in content.tags) 'tag:${tag.en.trim().toLowerCase()}': tag,
  };
}

class PublicContent {
  final List<PublicProject> projects;
  final List<Map<String, dynamic>> team;
  final Map<String, dynamic>? company;
  final String endpoint;
  const PublicContent({
    this.projects = const [],
    this.team = const [],
    this.company,
    this.endpoint = '',
  });
  Map<String, String> get contacts {
    final result = <String, String>{};
    for (final e in Map<String, dynamic>.from(
      company?['contacts'] as Map? ?? {},
    ).entries) {
      if (e.value is! String) continue;
      try {
        result.addAll(
          CompanyRepository.validContacts({e.key: e.value as String}),
        );
      } catch (_) {
        /* Hide malformed optional channels. */
      }
    }
    return result;
  }

  LocalizedText companyText(String key) => LocalizedText.fromMap(
    Map<String, dynamic>.from(company?[key] as Map? ?? {}),
  );
}

/// Anonymous reader: it never receives the administrator's token and has no
/// draft/settings/media collection access. Server cursors bound each response.
class PublicContentRepository {
  final FirestoreRestStore store;
  final String site;
  PublicContentRepository(this.store, {this.site = 'yogen'});
  Future<PublicContent> load() async {
    final all = <PublicProject>[];
    int? cursorOrder;
    String? cursorName;
    do {
      final rows =
          await store.request(
                '${store.base}/sites/$site:runQuery',
                body: {
                  'structuredQuery': {
                    'from': [
                      {'collectionId': 'projects'},
                    ],
                    'orderBy': [
                      {
                        'field': {'fieldPath': 'content.order'},
                        'direction': 'ASCENDING',
                      },
                      {
                        'field': {'fieldPath': '__name__'},
                        'direction': 'ASCENDING',
                      },
                    ],
                    'limit': 24,
                    if (cursorName != null)
                      'startAt': {
                        'before': false,
                        'values': [
                          {'integerValue': cursorOrder.toString()},
                          {'referenceValue': cursorName},
                        ],
                      },
                  },
                },
              )
              as List;
      final documents = rows
          .where((r) => (r as Map).containsKey('document'))
          .map(
            (r) => store.decodeDocument(
              Map<String, dynamic>.from(r['document'] as Map),
            ),
          )
          .toList();
      all.addAll(documents.map(PublicProject.fromDocument));
      if (documents.length < 24) break;
      final last = documents.last;
      final next = store.documentName(last.path);
      if (cursorName == next) throw const DataFailure('database_paging_loop');
      cursorName = next;
      cursorOrder = (last.data['content']['order'] as num).toInt();
    } while (true);
    final values = await Future.wait([
      store.get('sites/$site/company/current'),
      store.listAll('sites/$site/team'),
      MediaSettingsRepository.endpoint(store, site),
    ]);
    final team =
        (values[1] as List<StoredDocument>).map((d) => d.data).where((d) {
          return LocalizedText.fromMap(
                Map<String, dynamic>.from(d['name'] as Map? ?? {}),
              ).complete &&
              LocalizedText.fromMap(
                Map<String, dynamic>.from(d['role'] as Map? ?? {}),
              ).complete;
        }).toList()..sort(
          (a, b) =>
              (a['order'] as num? ?? 0).compareTo(b['order'] as num? ?? 0),
        );
    return PublicContent(
      projects: all,
      team: team,
      company: (values[0] as StoredDocument?)?.data,
      endpoint: values[2] as String,
    );
  }
}

final publicRepositoryProvider = Provider<PublicContentRepository>((ref) {
  final store = FirestoreRestStore(
    projectId: FirebaseConfig.projectId,
    token: () async => null,
  );
  ref.onDispose(store.close);
  return PublicContentRepository(store, site: activeSite);
});
final publicContentProvider =
    AsyncNotifierProvider<PublicContentNotifier, PublicContent>(
      PublicContentNotifier.new,
      // Surface the first failed read. Retry is explicit; periodic refresh
      // still recovers after connectivity returns without a long spinner.
      retry: (_, _) => null,
    );

class PublicContentNotifier extends AsyncNotifier<PublicContent> {
  bool busy = false;
  @override
  Future<PublicContent> build() async {
    final timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    ref.onDispose(timer.cancel);
    return ref.watch(publicRepositoryProvider).load();
  }

  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    final next = await AsyncValue.guard(
      () => ref.read(publicRepositoryProvider).load(),
    );
    if (ref.mounted) state = next;
    busy = false;
  }
}

final publicMediaCacheProvider = Provider<MediaByteCache>((ref) {
  final bridge = DriveBridge();
  final cache = MediaByteCache(AppsScriptMediaTransport(bridge));
  ref.onDispose(cache.clear);
  ref.onDispose(bridge.close);
  return cache;
});
