import 'dart:io';
import 'dart:typed_data';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'package:yogen_portfolio/domain/project.dart';
import 'package:yogen_portfolio/domain/media.dart';
import 'package:yogen_portfolio/features/media/media_transport.dart';

PublicProject publicFixture(int index) => PublicProject(
  'fixture-$index',
  ProjectContent(
    title: LocalizedText(ar: 'مشروع اختبار $index', en: 'Test project $index'),
    summary: const LocalizedText(
      ar: 'وصف مشروع الاختبار',
      en: 'A labelled technical project',
    ),
    body: const LocalizedText(
      ar: 'تفاصيل التجربة',
      en: 'Technical fixture details',
    ),
    contribution: const LocalizedText(
      ar: 'مساهمة تجريبية',
      en: 'Fixture contribution',
    ),
    problem: const LocalizedText(ar: 'تحدي اختبار', en: 'Test challenge'),
    solution: const LocalizedText(ar: 'حل اختبار', en: 'Test solution'),
    categoryId: index == 2 ? 'apps' : 'systems',
    slug: 'fixture-$index',
    usage: 'demo',
    attribution: 'company',
    mediaIds: ['image-$index', 'other-$index'],
    tags: const [
      LocalizedText(ar: 'ويب', en: 'Web'),
      LocalizedText(ar: 'تطبيقات', en: 'Applications'),
    ],
    order: index,
  ),
  const LocalizedText(ar: 'أنظمة', en: 'Systems'),
  [
    for (final id in ['image-$index', 'other-$index'])
      {
        'id': id,
        'mime': 'image/png',
        'driveFileId': 'test-file-123456',
        'name': 'test.png',
        'bytes': 100,
        'alt': {'ar': 'صورة اختبار', 'en': 'Test image'},
        'thumbnailDriveFileId': 'test-thumb-123456',
      },
  ],
);

class FixturePublicRepository extends PublicContentRepository {
  PublicContent value;
  bool fail = false;
  FixturePublicRepository({int count = 3})
    : value = PublicContent(
        projects: List.generate(count, publicFixture),
        endpoint: 'https://script.google.com/macros/s/fixture/exec',
      ),
      super(FirestoreRestStore(projectId: 'test', token: () async => null));
  @override
  Future<PublicContent> load() async {
    if (fail) throw const DataFailure('offline');
    return value;
  }
}

class FixtureMediaTransport implements MediaTransport {
  final requested = <String>[];
  @override
  Future<Uint8List> read(
    String url,
    String site,
    String id, {
    bool thumbnail = false,
    Future<void>? abortTrigger,
  }) async {
    requested.add(id);
    return File('assets/fixtures/phase05/صورة-أفقية.png').readAsBytesSync();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Map<String, dynamic>> ping(String url, String token, String site) =>
      throw UnimplementedError();
  @override
  Future<MediaSource?> status(
    String url,
    String token,
    String site,
    UploadOperation operation,
  ) => throw UnimplementedError();
  @override
  Future<MediaSource> upload(
    String url,
    String token,
    String site,
    UploadOperation operation,
    Uint8List bytes, {
    Uint8List? thumbnail,
  }) => throw UnimplementedError();
}
