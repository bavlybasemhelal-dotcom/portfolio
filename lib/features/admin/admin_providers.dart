import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/admin_session.dart';
import '../../data/admin_content_repository.dart';
import '../../data/company_repository.dart';
import '../../data/document_store.dart';
import '../../data/media_repository.dart';
import '../../domain/project.dart';
import '../../domain/media.dart';
import '../../data/media_settings_repository.dart';
import '../../data/featured_projects_repository.dart';
import '../media/drive_bridge.dart';
import '../media/media_transport.dart';

final adminContentRepositoryProvider = FutureProvider<AdminContentRepository>((
  ref,
) async {
  final identity = ref.watch(
    adminSessionProvider.select((v) => (v.value?.uid, v.value?.allowed)),
  );
  if (identity.$2 != true) throw const DataFailure('PERMISSION_DENIED');
  return AdminContentRepository(
    await ref.watch(documentStoreProvider.future),
    actor: identity.$1!,
    site: activeSite,
  );
});
final adminProjectsProvider = FutureProvider<List<ProjectDraft>>(
  (ref) async =>
      (await ref.watch(adminContentRepositoryProvider.future)).listProjects(),
  retry: (_, _) => null,
);
final featuredProjectsRepositoryProvider =
    FutureProvider<FeaturedProjectsRepository>((ref) async {
      final repo = await ref.watch(adminContentRepositoryProvider.future);
      return FeaturedProjectsRepository(
        repo.store,
        actor: repo.actor,
        site: repo.site,
      );
    });
final adminFeaturedIdsProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) async => (await ref.watch(
    featuredProjectsRepositoryProvider.future,
  )).selectedIds(),
  retry: (_, _) => null,
);
final adminCategoriesProvider = FutureProvider<List<StoredDocument>>(
  (ref) async =>
      (await ref.watch(adminContentRepositoryProvider.future)).categories(),
  retry: (_, _) => null,
);
final adminCompanyRepositoryProvider = FutureProvider<CompanyRepository>((
  ref,
) async {
  final repo = await ref.watch(adminContentRepositoryProvider.future);
  return CompanyRepository(repo.store, actor: repo.actor, site: repo.site);
});
final adminMediaRepositoryProvider = FutureProvider<MediaRepository>((
  ref,
) async {
  final repo = await ref.watch(adminContentRepositoryProvider.future);
  final bridge = DriveBridge();
  ref.onDispose(bridge.close);
  return MediaRepository(
    repo.store,
    AppsScriptMediaTransport(bridge),
    (await ref.watch(accountAuthProvider.future)).token,
    actor: repo.actor,
    site: repo.site,
  );
});

final adminMediaEntriesProvider = FutureProvider<List<MediaEntry>>(
  (ref) async => (await ref.watch(adminMediaRepositoryProvider.future)).list(),
  retry: (_, _) => null,
);
final adminEndpointProvider = FutureProvider<String>((ref) async {
  final repo = await ref.watch(adminContentRepositoryProvider.future);
  return MediaSettingsRepository.endpoint(repo.store, repo.site);
}, retry: (_, _) => null);

String adminError(Object e) {
  final code = e is ContentFailure
      ? e.code
      : e is DataFailure
      ? e.code
      : e.toString();
  return switch (code) {
    'revision_conflict' || 'FAILED_PRECONDITION' || 'ABORTED' => 'conflict',
    'publication_incomplete' => 'incomplete',
    'stable_slug' => 'slug',
    'slug_conflict' => 'slug-conflict',
    'category_not_ready' => 'category',
    'cover_must_be_image' || 'media_not_ready' => 'media',
    'PERMISSION_DENIED' || 'UNAUTHENTICATED' => 'access',
    _ => 'save',
  };
}
