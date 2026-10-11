import '../domain/project.dart';
import 'document_store.dart';

class ProjectRepository {
  final DocumentStore store;
  final String site, actor;
  ProjectRepository(this.store, {required this.actor, this.site = 'yogen'}) {
    if (!['yogen', 'phase04-test'].contains(site)) {
      throw const DataFailure('invalid_site');
    }
  }
  String path(String collection, String id) => 'sites/$site/$collection/$id';
  Future<ProjectDraft?> getDraft(String id) async {
    final doc = await store.get(path('projectDrafts', id));
    return doc == null ? null : ProjectDraft.fromMap(id, doc.data);
  }

  Future<List<StoredDocument>> listPublic({int limit = 30}) =>
      store.list('sites/$site/projects', limit: limit);
  Future<StoredDocument?> getPublic(String id) =>
      store.get(path('projects', id));
  Future<StoredDocument?> resolveSlug(String slug) async {
    final index = await store.get(path('projectSlugs', slug));
    return index == null ? null : getPublic(index.data['projectId'] as String);
  }

  void checkRevision(ProjectDraft? draft, int expected) {
    if ((draft?.revision ?? 0) != expected) {
      throw const ContentFailure('revision_conflict');
    }
  }

  Map<String, Object?> draftMap(
    ProjectDraft? old,
    ProjectContent content, {
    required ProjectStatus status,
    required int publishedRevision,
    String? stableSlug,
    String? internalNote,
  }) => {
    'content': content.toMap(),
    'status': status.name,
    'revision': (old?.revision ?? 0) + 1,
    'publishedRevision': publishedRevision,
    'stableSlug': stableSlug ?? old?.stableSlug ?? '',
    'internalNote': internalNote ?? old?.internalNote ?? '',
    'createdAt': old?.createdAt ?? serverTime,
    'createdBy': old?.createdBy ?? actor,
    'updatedAt': serverTime,
    'updatedBy': actor,
  };
  Future<int> saveDraft(
    String id,
    ProjectContent content, {
    required int expectedRevision,
    String internalNote = '',
  }) async {
    content.validateDraft();
    return store.transaction((tx) async {
      final snapshot = await tx.get(path('projectDrafts', id));
      final old = snapshot == null
          ? null
          : ProjectDraft.fromMap(id, snapshot.data);
      checkRevision(old, expectedRevision);
      if (old?.status == ProjectStatus.archived) {
        throw const ContentFailure('restore_before_editing');
      }
      if (old != null &&
          old.stableSlug.isNotEmpty &&
          content.slug != old.stableSlug) {
        throw const ContentFailure('stable_slug');
      }
      tx.set(
        path('projectDrafts', id),
        draftMap(
          old,
          content,
          status: old?.status ?? ProjectStatus.draft,
          publishedRevision: old?.publishedRevision ?? 0,
          internalNote: internalNote,
        ),
      );
      return (old?.revision ?? 0) + 1;
    });
  }

  Future<int> publish(String id, {required int expectedRevision}) =>
      store.transaction((tx) async {
        final snapshot = await tx.get(path('projectDrafts', id));
        if (snapshot == null) throw const ContentFailure('draft_missing');
        final draft = ProjectDraft.fromMap(id, snapshot.data);
        checkRevision(draft, expectedRevision);
        if (draft.status == ProjectStatus.archived) {
          throw const ContentFailure('restore_before_publishing');
        }
        draft.content.validatePublication();
        final category = await tx.get(
          path('categories', draft.content.categoryId),
        );
        if (category == null ||
            category.data['enabled'] != true ||
            !LocalizedText.fromMap(
              Map<String, dynamic>.from(category.data['name'] as Map),
            ).complete) {
          throw const ContentFailure('category_not_ready');
        }
        final slug = await tx.get(path('projectSlugs', draft.content.slug));
        if (slug != null && slug.data['projectId'] != id) {
          throw const ContentFailure('slug_conflict');
        }
        final assets = <Map<String, dynamic>>[];
        for (final mediaId in draft.content.mediaIds) {
          final media = await tx.get(path('media', mediaId));
          if (media == null || media.data['ready'] != true) {
            throw ContentFailure('media_not_ready', [mediaId]);
          }
          final public = Map<String, dynamic>.from(media.data['public'] as Map);
          if (!LocalizedText.fromMap(
            Map<String, dynamic>.from(public['alt'] as Map),
          ).complete) {
            throw ContentFailure('media_alt_incomplete', [mediaId]);
          }
          assets.add(public);
        }
        if (![
          'image/png',
          'image/jpeg',
          'image/webp',
        ].contains(assets.first['mime'])) {
          throw const ContentFailure('cover_must_be_image');
        }
        final revision = draft.revision + 1;
        tx.set(
          path('projectDrafts', id),
          draftMap(
            draft,
            draft.content,
            status: ProjectStatus.published,
            publishedRevision: revision,
            stableSlug: draft.content.slug,
          ),
        );
        tx.set(path('projects', id), {
          'projectId': id,
          'content': draft.content.toMap(),
          'category': category.data['name'],
          'assets': assets,
          'revision': revision,
          'publishedAt': serverTime,
        });
        tx.set(path('projectSlugs', draft.content.slug), {
          'projectId': id,
          'revision': revision,
        });
        return revision;
      });
  Future<int> unpublish(String id, {required int expectedRevision}) =>
      _removePublication(id, expectedRevision, ProjectStatus.draft);
  Future<int> archive(String id, {required int expectedRevision}) =>
      _removePublication(id, expectedRevision, ProjectStatus.archived);
  Future<int> _removePublication(String id, int expected, ProjectStatus next) =>
      store.transaction((tx) async {
        final snapshot = await tx.get(path('projectDrafts', id));
        if (snapshot == null) throw const ContentFailure('draft_missing');
        final draft = ProjectDraft.fromMap(id, snapshot.data);
        checkRevision(draft, expected);
        final publication = await tx.get(path('projects', id));
        tx.set(
          path('projectDrafts', id),
          draftMap(draft, draft.content, status: next, publishedRevision: 0),
        );
        if (publication != null) {
          tx.delete(path('projects', id));
          tx.delete(
            path('projectSlugs', publication.data['content']['slug'] as String),
          );
        }
        return draft.revision + 1;
      });
  Future<int> restore(String id, {required int expectedRevision}) =>
      store.transaction((tx) async {
        final snapshot = await tx.get(path('projectDrafts', id));
        if (snapshot == null) throw const ContentFailure('draft_missing');
        final draft = ProjectDraft.fromMap(id, snapshot.data);
        checkRevision(draft, expectedRevision);
        if (draft.status != ProjectStatus.archived) {
          throw const ContentFailure('not_archived');
        }
        tx.set(
          path('projectDrafts', id),
          draftMap(
            draft,
            draft.content,
            status: ProjectStatus.draft,
            publishedRevision: 0,
          ),
        );
        return draft.revision + 1;
      });
}
