import '../domain/project.dart';
import 'document_store.dart';
import 'read_collection.dart';

class FeaturedProjectsRepository {
  final DocumentStore store;
  final String actor, site;
  FeaturedProjectsRepository(
    this.store, {
    required this.actor,
    this.site = 'yogen',
  });

  String get collection => 'sites/$site/featuredProjects';

  Future<Set<String>> selectedIds() async => {
    for (final doc in await readCollection(store, collection))
      if (doc.data['projectId'] == doc.path.split('/').last)
        doc.path.split('/').last,
  };

  Future<void> select(
    String projectId,
    bool selected, {
    required bool expectedSelected,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,70}$').hasMatch(projectId)) {
      throw const ContentFailure('invalid_project_id');
    }
    await store.transaction((tx) async {
      final path = '$collection/$projectId';
      final current = await tx.get(path);
      if ((current != null) != expectedSelected) {
        throw const ContentFailure('revision_conflict');
      }
      if (selected == expectedSelected) return;
      if (!selected) {
        tx.delete(path);
        return;
      }
      if (await tx.get('sites/$site/projects/$projectId') == null) {
        throw const ContentFailure('project_not_published');
      }
      tx.set(path, {
        'projectId': projectId,
        'updatedAt': serverTime,
        'updatedBy': actor,
      });
    });
  }
}
