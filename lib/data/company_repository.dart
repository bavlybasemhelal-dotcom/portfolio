import '../domain/project.dart';
import 'document_store.dart';

class CompanyRepository {
  final DocumentStore store;
  final String actor, site;
  CompanyRepository(this.store, {required this.actor, this.site = 'yogen'});
  String path(String collection, String id) => 'sites/$site/$collection/$id';
  Future<void> saveTeamDraft(
    String id, {
    required LocalizedText name,
    required LocalizedText role,
    LocalizedText bio = const LocalizedText(),
    int order = 0,
    String photoId = '',
    List<Map<String, String>> links = const [],
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,70}$').hasMatch(id) ||
        order < 0 ||
        order > 1000000 ||
        [
          name,
          role,
          bio,
        ].any((t) => t.ar.length > 30000 || t.en.length > 30000)) {
      throw const ContentFailure('profile_invalid');
    }
    ProjectContent(links: links).validateDraft();
    await store.commit([
      DocumentWrite.set(path('teamDrafts', id), {
        'name': name.toMap(),
        'role': role.toMap(),
        'bio': bio.toMap(),
        'order': order,
        'photoId': photoId,
        'links': links,
        'updatedAt': serverTime,
        'updatedBy': actor,
      }),
    ]);
  }

  Future<void> publishTeam(String id) => store.transaction((tx) async {
    final draft = await tx.get(path('teamDrafts', id));
    if (draft == null) throw const ContentFailure('profile_missing');
    final name = LocalizedText.fromMap(
      Map<String, dynamic>.from(draft.data['name'] as Map),
    );
    final role = LocalizedText.fromMap(
      Map<String, dynamic>.from(draft.data['role'] as Map),
    );
    if (!name.complete || !role.complete) {
      throw const ContentFailure('profile_incomplete');
    }
    final bio = LocalizedText.fromMap(
      Map<String, dynamic>.from(draft.data['bio'] as Map),
    );
    if ((bio.ar.isNotEmpty || bio.en.isNotEmpty) && !bio.complete) {
      throw const ContentFailure('profile_bio_incomplete');
    }
    final photoId = draft.data['photoId'] as String? ?? '';
    final photo = photoId.isEmpty ? null : await tx.get(path('media', photoId));
    if (photoId.isNotEmpty &&
        (photo?.data['verified'] != true ||
            photo?.data['ready'] != true ||
            !(photo!.data['public']['mime'] as String).startsWith('image/'))) {
      throw const ContentFailure('media_not_ready');
    }
    final links = (draft.data['links'] as List? ?? [])
        .map((v) => Map<String, String>.from(v as Map))
        .toList();
    ProjectContent(links: links).validateDraft();
    if (links.any(
      (v) =>
          !ProjectContent.validUrl(v['url']!) ||
          v['labelAr']!.trim().isEmpty ||
          v['labelEn']!.trim().isEmpty,
    )) {
      throw const ContentFailure('invalid_link');
    }
    tx.set(path('team', id), {
      'name': name.toMap(),
      'role': role.toMap(),
      'bio': bio.toMap(),
      'order': draft.data['order'],
      if (photo != null) 'photo': photo.data['public'],
      if (links.isNotEmpty) 'links': links,
    });
  });
  Future<void> hideTeam(String id) =>
      store.commit([DocumentWrite.delete(path('team', id))]);
  Future<void> saveCompanyDraft({
    required LocalizedText about,
    required LocalizedText service,
    Map<String, String> contacts = const {},
  }) async {
    if ([
      about,
      service,
    ].any((t) => t.ar.length > 30000 || t.en.length > 30000)) {
      throw const ContentFailure('text_too_long');
    }
    final safe = validContacts(contacts);
    await store.commit([
      DocumentWrite.set(path('companyDrafts', 'current'), {
        'name': 'YOGEN',
        'about': about.toMap(),
        'service': service.toMap(),
        'contacts': safe,
        'updatedAt': serverTime,
        'updatedBy': actor,
      }),
    ]);
  }

  Future<void> publishCompany() => store.transaction((tx) async {
    final draft = await tx.get(path('companyDrafts', 'current'));
    if (draft == null) throw const ContentFailure('company_missing');
    final about = LocalizedText.fromMap(
          Map<String, dynamic>.from(draft.data['about'] as Map),
        ),
        service = LocalizedText.fromMap(
          Map<String, dynamic>.from(draft.data['service'] as Map),
        );
    if (!about.complete || !service.complete) {
      throw const ContentFailure('company_incomplete');
    }
    tx.set(path('company', 'current'), {
      'name': 'YOGEN',
      'about': about.toMap(),
      'service': service.toMap(),
      'contacts': validContacts(
        Map<String, String>.from(draft.data['contacts'] as Map),
      ),
    });
  });
  static Map<String, String> validContacts(Map<String, String> contacts) {
    final result = <String, String>{};
    for (final entry in contacts.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      final valid = switch (entry.key) {
        'email' => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value),
        'whatsapp' => RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value),
        'website' => ProjectContent.validUrl(value),
        _ => false,
      };
      if (!valid) throw ContentFailure('invalid_contact', [entry.key]);
      result[entry.key] = value;
    }
    return result;
  }
}
