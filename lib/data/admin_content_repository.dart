import '../domain/project.dart';
import 'document_store.dart';
import 'project_repository.dart';
import 'read_collection.dart';

class AdminContentRepository {
  final DocumentStore store;
  final String actor, site;
  AdminContentRepository(
    this.store, {
    required this.actor,
    this.site = 'yogen',
  });
  ProjectRepository get projects =>
      ProjectRepository(store, actor: actor, site: site);
  String path(String collection, String id) => 'sites/$site/$collection/$id';
  Future<List<ProjectDraft>> listProjects() async =>
      (await readCollection(store, 'sites/$site/projectDrafts'))
          .map((d) => ProjectDraft.fromMap(d.path.split('/').last, d.data))
          .toList()
        ..sort(
          (a, b) => a.content.order == b.content.order
              ? a.id.compareTo(b.id)
              : a.content.order.compareTo(b.content.order),
        );
  Future<List<StoredDocument>> categories() async =>
      (await readCollection(store, 'sites/$site/categories'))..sort(
        (a, b) => (a.data['order'] as num).compareTo(b.data['order'] as num),
      );
  Future<void> saveCategory(
    String id,
    LocalizedText name, {
    bool enabled = true,
    int order = 0,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,70}$').hasMatch(id) ||
        (enabled && !name.complete) ||
        name.ar.length > 30000 ||
        name.en.length > 30000 ||
        order < 0) {
      throw const ContentFailure('category_not_ready');
    }
    await store.commit([
      DocumentWrite.set(path('categories', id), {
        'name': name.toMap(),
        'enabled': enabled,
        'order': order,
        'updatedAt': serverTime,
        'updatedBy': actor,
      }),
    ]);
  }

  Future<int> duplicate(String sourceId, String destination) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,70}$').hasMatch(destination)) {
      throw const ContentFailure('invalid_project_id');
    }
    return store.transaction((tx) async {
      final source = await tx.get(path('projectDrafts', sourceId));
      final target = await tx.get(path('projectDrafts', destination));
      if (source == null) throw const ContentFailure('draft_missing');
      if (target != null) throw const ContentFailure('project_exists');
      final old = ProjectDraft.fromMap(sourceId, source.data);
      final copy = ProjectContent.fromMap({...old.content.toMap(), 'slug': ''});
      tx.set(
        path('projectDrafts', destination),
        projects.draftMap(
          null,
          copy,
          status: ProjectStatus.draft,
          publishedRevision: 0,
          internalNote: old.internalNote,
        ),
      );
      return 1;
    });
  }

  Future<int> reorder(ProjectDraft draft, int order) => projects.saveDraft(
    draft.id,
    ProjectContent.fromMap({...draft.content.toMap(), 'order': order}),
    expectedRevision: draft.revision,
    internalNote: draft.internalNote,
  );
}
