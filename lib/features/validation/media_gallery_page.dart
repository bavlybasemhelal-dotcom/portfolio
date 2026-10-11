import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart';
import '../../core/firebase_config.dart';
import '../../data/document_store.dart';
import '../../data/media_settings_repository.dart';
import '../media/drive_bridge.dart';
import '../media/media_transport.dart';
import '../media/media_preview.dart';

class MediaGalleryPage extends StatefulWidget {
  const MediaGalleryPage({super.key});
  @override
  State<MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends State<MediaGalleryPage> {
  final bridge = DriveBridge();
  late final cache = MediaByteCache(AppsScriptMediaTransport(bridge));
  late final store = FirestoreRestStore(
    projectId: FirebaseConfig.projectId,
    token: () async => null,
  );
  Future<StoredDocument?>? project;
  String site = 'yogen', endpoint = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (project != null) return;
    final query = GoRouterState.of(context).uri.queryParameters;
    site = query['site'] == 'phase04-test' ? 'phase04-test' : 'yogen';
    final id = query['project'] ?? '';
    project = () async {
      if (!RegExp(r'^[A-Za-z0-9_-]{1,70}$').hasMatch(id)) return null;
      endpoint = await MediaSettingsRepository.endpoint(store, site);
      return store.get('sites/$site/projects/$id');
    }();
  }

  @override
  void dispose() {
    cache.clear();
    bridge.close();
    store.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        tr(c, 'معاينة وسائط منشورة', 'Published media preview'),
        style: Theme.of(c).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      FutureBuilder<StoredDocument?>(
        future: project,
        builder: (c, data) {
          if (data.hasError) {
            return Text(
              tr(c, 'تعذر قراءة المشروع.', 'Project could not be loaded.'),
            );
          }
          if (data.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data.data == null) {
            return Text(
              tr(
                c,
                'لا يوجد مشروع منشور بهذا المعرف.',
                'No published project with this ID.',
              ),
            );
          }
          final value = data.data!.data,
              assets = (value['assets'] as List)
                  .map((v) => Map<String, dynamic>.from(v as Map))
                  .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                value['content']['title'][Localizations.localeOf(
                      c,
                    ).languageCode]
                    as String,
                style: Theme.of(c).textTheme.titleLarge,
              ),
              for (final asset in assets)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          asset['alt'][Localizations.localeOf(c).languageCode]
                              as String,
                        ),
                        MediaViewer(
                          cache: cache,
                          endpoint: endpoint,
                          site: site,
                          asset: asset,
                          cover: assets.firstOrNull,
                        ),
                        if ((asset['mime'] as String).startsWith('image/'))
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: c,
                              builder: (dialog) => AlertDialog(
                                title: Text(
                                  tr(dialog, 'تكبير الصورة', 'Enlarge image'),
                                ),
                                content: SizedBox(
                                  width: 900,
                                  child: InteractiveViewer(
                                    child: DriveImage(
                                      cache: cache,
                                      endpoint: endpoint,
                                      site: site,
                                      assetId: asset['id'] as String,
                                      alt:
                                          asset['alt'][Localizations.localeOf(
                                                dialog,
                                              ).languageCode]
                                              as String,
                                      height: 500,
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialog),
                                    child: Text(tr(dialog, 'إغلاق', 'Close')),
                                  ),
                                ],
                              ),
                            ),
                            child: Text(tr(c, 'تكبير الصورة', 'Enlarge image')),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
