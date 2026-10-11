import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/domain/project.dart';

void main() {
  test(
    'Optional case study bounded lines round trip and reject partial/mismatched bilingual lists',
    () {
      const value = ProjectContent(
        tags: [
          LocalizedText(ar: 'ويب', en: 'Web'),
          LocalizedText(ar: 'أنظمة', en: 'Systems'),
        ],
        features: [LocalizedText(ar: 'وظيفة', en: 'Feature')],
        technologies: ['Flutter', 'Firebase'],
      );
      value.validateDraft();
      expect(ProjectContent.fromMap(value.toMap()).toMap(), value.toMap());
      expect(
        () => ProjectContent.fromMap({
          ...value.toMap(),
          'tags': {'ar': 'ويب', 'en': 'Web\nSystems'},
        }),
        throwsA(isA<ContentFailure>()),
      );
      expect(
        const ProjectContent(
          tags: [LocalizedText(ar: 'ويب\nأنظمة', en: 'Web')],
        ).validateDraft,
        throwsA(isA<ContentFailure>()),
      );
    },
  );
  ProjectContent complete({List<Map<String, String>> links = const []}) =>
      ProjectContent(
        title: const LocalizedText(ar: 'مشروع تجربة', en: 'Test project'),
        summary: const LocalizedText(ar: 'وصف', en: 'Summary'),
        body: const LocalizedText(
          ar: 'الحل والوظائف',
          en: 'Solution and features',
        ),
        contribution: const LocalizedText(
          ar: 'مساهمة الفريق',
          en: 'Team contribution',
        ),
        categoryId: 'systems',
        slug: 'test-project',
        usage: 'demo',
        attribution: 'company',
        mediaIds: const ['cover'],
        links: links,
      );
  test(
    'Incomplete drafts save without fabricated translations; publishing refuses them',
    () {
      const draft = ProjectContent(title: LocalizedText(ar: 'اسم فقط'));
      expect(draft.validateDraft, returnsNormally);
      expect(
        draft.validatePublication,
        throwsA(
          isA<ContentFailure>().having(
            (v) => v.fields,
            'missing',
            contains('title.en'),
          ),
        ),
      );
    },
  );
  test(
    'A complete project publishes without demo links, team names or results',
    () {
      expect(complete().validatePublication, returnsNormally);
      expect(
        ProjectContent.fromMap(complete().toMap()).toMap(),
        complete().toMap(),
      );
    },
  );
  test(
    'Unsafe links, duplicate assets and oversized public snapshots fail',
    () {
      expect(
        complete(
          links: [
            {
              'url': 'javascript:alert(1)',
              'labelAr': 'رابط',
              'labelEn': 'Link',
            },
          ],
        ).validateDraft,
        throwsA(isA<ContentFailure>()),
      );
      expect(
        const ProjectContent(mediaIds: ['cover', 'cover']).validateDraft,
        throwsA(isA<ContentFailure>()),
      );
      expect(
        ProjectContent(mediaIds: List.generate(7, (i) => '$i')).validateDraft,
        throwsA(isA<ContentFailure>()),
      );
    },
  );
}
