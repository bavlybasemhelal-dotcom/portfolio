import 'dart:convert';

enum ProjectStatus { draft, published, archived }

class ContentFailure implements Exception {
  final String code;
  final List<String> fields;
  const ContentFailure(this.code, [this.fields = const []]);
  @override
  String toString() => '$code${fields.isEmpty ? '' : ': ${fields.join(', ')}'}';
}

class LocalizedText {
  final String ar, en;
  const LocalizedText({this.ar = '', this.en = ''});
  bool get complete => ar.trim().isNotEmpty && en.trim().isNotEmpty;
  Map<String, Object?> toMap() => {'ar': ar, 'en': en};
  factory LocalizedText.fromMap(Map<String, dynamic> value) => LocalizedText(
    ar: value['ar'] as String? ?? '',
    en: value['en'] as String? ?? '',
  );
}

/// Only public content goes here. Internal notes and audit fields live outside it.
class ProjectContent {
  static List<Map<String, String>> _readLinks(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((x) => Map<String, String>.from(x as Map)).toList();
    }
    final columns = {
      for (final key in ['url', 'labelAr', 'labelEn'])
        key: (value[key] as String).split('\n'),
    };
    if (columns.values.any((v) => v.length != columns['url']!.length)) {
      throw const ContentFailure('invalid_link');
    }
    return List.generate(
      columns['url']!.length,
      (i) => {for (final key in columns.keys) key: columns[key]![i]},
    );
  }

  // Bounded lines keep bilingual lists inside Firestore's rule expression budget.
  static Map<String, String> _lines(List<LocalizedText> values) => {
    'ar': values.map((t) => t.ar).join('\n'),
    'en': values.map((t) => t.en).join('\n'),
  };
  static List<LocalizedText> _readLines(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map(
            (v) => LocalizedText.fromMap(Map<String, dynamic>.from(v as Map)),
          )
          .toList();
    }
    final text = LocalizedText.fromMap(Map<String, dynamic>.from(value as Map));
    final ar = text.ar.split('\n'), en = text.en.split('\n');
    if (ar.length != en.length) {
      throw const ContentFailure('invalid_case_study');
    }
    return List.generate(ar.length, (i) => LocalizedText(ar: ar[i], en: en[i]));
  }

  final LocalizedText title, summary, body, contribution;
  final String categoryId, slug, usage, attribution;
  final List<String> mediaIds;
  final List<Map<String, String>> links;
  final int order;
  final int? year;
  final LocalizedText problem, solution;
  final List<LocalizedText> tags, features;
  final List<String> technologies;
  const ProjectContent({
    this.title = const LocalizedText(),
    this.summary = const LocalizedText(),
    this.body = const LocalizedText(),
    this.contribution = const LocalizedText(),
    this.categoryId = '',
    this.slug = '',
    this.usage = 'unspecified',
    this.attribution = 'unspecified',
    this.mediaIds = const [],
    this.links = const [],
    this.order = 0,
    this.year,
    this.problem = const LocalizedText(),
    this.solution = const LocalizedText(),
    this.tags = const [],
    this.features = const [],
    this.technologies = const [],
  });

  Map<String, Object?> toMap() => {
    'title': title.toMap(),
    'summary': summary.toMap(),
    'body': body.toMap(),
    'contribution': contribution.toMap(),
    'categoryId': categoryId,
    'slug': slug,
    'usage': usage,
    'attribution': attribution,
    'mediaIds': mediaIds,
    'links': links.isEmpty
        ? []
        : {
            for (final key in ['url', 'labelAr', 'labelEn'])
              key: links.map((v) => v[key] ?? '').join('\n'),
          },
    'order': order,
    'year': year,
    if (problem.ar.isNotEmpty || problem.en.isNotEmpty)
      'problem': problem.toMap(),
    if (solution.ar.isNotEmpty || solution.en.isNotEmpty)
      'solution': solution.toMap(),
    if (tags.isNotEmpty) 'tags': _lines(tags),
    if (features.isNotEmpty) 'features': _lines(features),
    if (technologies.isNotEmpty) 'technologies': technologies.join('\n'),
  };
  factory ProjectContent.fromMap(Map<String, dynamic> v) => ProjectContent(
    title: LocalizedText.fromMap(
      Map<String, dynamic>.from(v['title'] as Map? ?? {}),
    ),
    summary: LocalizedText.fromMap(
      Map<String, dynamic>.from(v['summary'] as Map? ?? {}),
    ),
    body: LocalizedText.fromMap(
      Map<String, dynamic>.from(v['body'] as Map? ?? {}),
    ),
    contribution: LocalizedText.fromMap(
      Map<String, dynamic>.from(v['contribution'] as Map? ?? {}),
    ),
    categoryId: v['categoryId'] as String? ?? '',
    slug: v['slug'] as String? ?? '',
    usage: v['usage'] as String? ?? 'unspecified',
    attribution: v['attribution'] as String? ?? 'unspecified',
    mediaIds: List<String>.from(v['mediaIds'] as List? ?? []),
    links: _readLinks(v['links']),
    order: (v['order'] as num? ?? 0).toInt(),
    year: (v['year'] as num?)?.toInt(),
    problem: LocalizedText.fromMap(
      Map<String, dynamic>.from(v['problem'] as Map? ?? {}),
    ),
    solution: LocalizedText.fromMap(
      Map<String, dynamic>.from(v['solution'] as Map? ?? {}),
    ),
    tags: _readLines(v['tags']),
    features: _readLines(v['features']),
    technologies: v['technologies'] is String
        ? (v['technologies'] as String).split('\n')
        : List<String>.from(v['technologies'] as List? ?? []),
  );

  void validateDraft() {
    for (final t in [problem, solution]) {
      if (t.ar.length > 30000 || t.en.length > 30000) {
        throw const ContentFailure('text_too_long');
      }
    }
    if (tags.length > 6 ||
        features.length > 6 ||
        technologies.length > 6 ||
        [...tags, ...features].any(
          (t) =>
              t.ar.length > 600 ||
              t.en.length > 600 ||
              t.ar.contains('\n') ||
              t.en.contains('\n'),
        ) ||
        technologies.any(
          (t) => t.trim().isEmpty || t.length > 80 || t.contains('\n'),
        ) ||
        tags
                .map((t) => t.en.trim().toLowerCase())
                .where((t) => t.isNotEmpty)
                .toSet()
                .length !=
            tags.where((t) => t.en.trim().isNotEmpty).length ||
        technologies.toSet().length != technologies.length) {
      throw const ContentFailure('invalid_case_study');
    }
    if (order < 0 || order > 1000000) {
      throw const ContentFailure('invalid_order');
    }
    if (categoryId.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_-]{1,70}$').hasMatch(categoryId)) {
      throw const ContentFailure('invalid_category');
    }
    final map = toMap();
    if (utf8.encode(jsonEncode(map)).length > 160000) {
      throw const ContentFailure('content_too_large');
    }
    for (final text in [title, summary, body, contribution]) {
      if (text.ar.length > 30000 || text.en.length > 30000) {
        throw const ContentFailure('text_too_long');
      }
    }
    if (mediaIds.length > 6 || mediaIds.toSet().length != mediaIds.length) {
      throw const ContentFailure('media_snapshot_limit');
    }
    if (links.length > 6 ||
        links.any(
          (v) =>
              !v.keys.toSet().containsAll(['url', 'labelAr', 'labelEn']) ||
              v.keys.any((k) => !['url', 'labelAr', 'labelEn'].contains(k)) ||
              (v['url'] ?? '').length > 2048 ||
              ((v['url'] ?? '').isNotEmpty && !validUrl(v['url']!)) ||
              (v['labelAr'] ?? '').length > 200 ||
              (v['labelEn'] ?? '').length > 200 ||
              v.values.any((s) => s.contains('\n')),
        )) {
      throw const ContentFailure('invalid_link');
    }
    if (year != null && (year! < 1990 || year! > 2100)) {
      throw const ContentFailure('invalid_year');
    }
    if (!['unspecified', 'real', 'demo', 'personal'].contains(usage) ||
        ![
          'unspecified',
          'company',
          'team_previous',
          'personal',
        ].contains(attribution)) {
      throw const ContentFailure('invalid_classification');
    }
    if (slug.isNotEmpty &&
        !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      throw const ContentFailure('invalid_slug');
    }
    if (slug.length > 80) throw const ContentFailure('invalid_slug');
  }

  void validatePublication() {
    validateDraft();
    final missing = <String>[];
    for (final entry in {
      'title': title,
      'summary': summary,
      'body': body,
      'contribution': contribution,
    }.entries) {
      if (entry.value.ar.trim().isEmpty) missing.add('${entry.key}.ar');
      if (entry.value.en.trim().isEmpty) missing.add('${entry.key}.en');
    }
    if (categoryId.isEmpty) missing.add('categoryId');
    if (slug.isEmpty) missing.add('slug');
    if (usage == 'unspecified') missing.add('usage');
    if (attribution == 'unspecified') missing.add('attribution');
    if (mediaIds.isEmpty) missing.add('cover');
    for (final e in {'problem': problem, 'solution': solution}.entries) {
      if ((e.value.ar.isNotEmpty || e.value.en.isNotEmpty) &&
          !e.value.complete) {
        missing.add(e.key);
      }
    }
    for (final e in {'tags': tags, 'features': features}.entries) {
      if (e.value.any((v) => !v.complete)) missing.add(e.key);
    }
    if (links.any(
      (v) =>
          !validUrl(v['url']!) ||
          v['labelAr']!.trim().isEmpty ||
          v['labelEn']!.trim().isEmpty,
    )) {
      missing.add('links');
    }
    if (missing.isNotEmpty) {
      throw ContentFailure('publication_incomplete', missing);
    }
  }

  static bool validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }
}

class ProjectDraft {
  final String id, stableSlug, internalNote, createdBy, updatedBy;
  final ProjectContent content;
  final ProjectStatus status;
  final int revision, publishedRevision;
  final DateTime? createdAt, updatedAt;
  const ProjectDraft({
    required this.id,
    required this.content,
    required this.status,
    required this.revision,
    required this.publishedRevision,
    this.stableSlug = '',
    this.internalNote = '',
    this.createdBy = '',
    this.updatedBy = '',
    this.createdAt,
    this.updatedAt,
  });
  factory ProjectDraft.fromMap(String id, Map<String, dynamic> v) =>
      ProjectDraft(
        id: id,
        content: ProjectContent.fromMap(
          Map<String, dynamic>.from(v['content'] as Map),
        ),
        status: ProjectStatus.values.byName(v['status'] as String),
        revision: (v['revision'] as num).toInt(),
        publishedRevision: (v['publishedRevision'] as num).toInt(),
        stableSlug: v['stableSlug'] as String,
        internalNote: v['internalNote'] as String,
        createdBy: v['createdBy'] as String,
        updatedBy: v['updatedBy'] as String,
        createdAt: v['createdAt'] as DateTime?,
        updatedAt: v['updatedAt'] as DateTime?,
      );
  bool get hasUnpublishedChanges => revision != publishedRevision;
}
