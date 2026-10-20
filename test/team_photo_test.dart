import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/data/document_store.dart';
import 'package:yogen_portfolio/data/public_content_repository.dart';
import 'package:yogen_portfolio/features/media/media_preview.dart';
import 'package:yogen_portfolio/features/media/media_transport.dart';
import 'package:yogen_portfolio/features/public/team_photo.dart';
import 'support/public_fixtures.dart';

class RecordingPhotoCache extends MediaByteCache {
  final requests = <({String id, String publicUrl, bool thumbnail})>[];
  RecordingPhotoCache() : super(FixtureMediaTransport());

  @override
  Future<Uint8List> read(
    String url,
    String site,
    String id, {
    bool thumbnail = false,
    bool retry = false,
    String publicUrl = '',
  }) async {
    requests.add((id: id, publicUrl: publicUrl, thumbnail: thumbnail));
    return File('assets/fixtures/phase05/صورة-أفقية.png').readAsBytesSync();
  }
}

class TeamReadStore extends FirestoreRestStore {
  TeamReadStore() : super(projectId: 'fixture', token: () async => null);
  @override
  Future<dynamic> request(
    String url, {
    String method = 'POST',
    Object? body,
    bool missingOk = false,
  }) async => [];
  @override
  Future<StoredDocument?> get(String path) async => null;
  @override
  Future<List<StoredDocument>> listAll(String collection) async => [
    const StoredDocument('sites/yogen/team/member-a', {
      'name': {'ar': 'عضو', 'en': 'Member'},
      'role': {'ar': 'مطور', 'en': 'Developer'},
    }),
  ];
}

void main() {
  test(
    'Public team retains its document ID without requiring an ID field',
    () async {
      final store = TeamReadStore();
      addTearDown(store.close);
      final content = await PublicContentRepository(store).load();
      expect(content.team.single['id'], 'member-a');
    },
  );

  for (final member in ['george-mounir', 'youssab-wagdy', 'bavly-basem']) {
    testWidgets('Bundled $member photo loads without a member ID or network', (
      tester,
    ) async {
      final asset = 'assets/images/team/$member.jpg';
      final hash = sha256.convert(File(asset).readAsBytesSync());
      final cache = RecordingPhotoCache();
      addTearDown(cache.clear);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [publicMediaCacheProvider.overrideWithValue(cache)],
          child: MaterialApp(
            home: Scaffold(
              body: TeamPhoto(
                photo: {
                  'id': 'photo-a',
                  'driveFileId': '',
                  'publicUrl':
                      'https://portfolio-14d15.web.app/project-media/$hash.jpg',
                  'alt': {'ar': 'صورة العضو', 'en': 'Team member portrait'},
                },
                endpoint: '',
                site: 'yogen',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(asset)), findsOneWidget);
      expect(find.byType(DriveImage), findsNothing);
      expect(cache.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Changed and new team photos use the current media reference', (
    tester,
  ) async {
    final cache = RecordingPhotoCache();
    addTearDown(cache.clear);
    final asset = 'assets/images/team/bavly-basem.jpg';
    final hash = sha256.convert(File(asset).readAsBytesSync());
    var photo = <String, dynamic>{
      'id': 'photo-a',
      'driveFileId': '',
      'publicUrl': 'https://portfolio-14d15.web.app/project-media/$hash.jpg',
      'alt': {'ar': 'صورة العضو', 'en': 'Team member portrait'},
    };
    Future<void> show() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [publicMediaCacheProvider.overrideWithValue(cache)],
          child: MaterialApp(
            home: Scaffold(
              body: TeamPhoto(photo: photo, endpoint: '', site: 'yogen'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show();
    expect(cache.requests, isEmpty);
    // Even if an asset ID is reused, a new URL must not show the bundled image.
    photo = {
      ...photo,
      'publicUrl':
          'https://portfolio-14d15.web.app/project-media/${'a' * 64}.jpg',
    };
    await show();
    expect(find.byKey(ValueKey(asset)), findsNothing);
    expect(cache.requests.single.publicUrl, photo['publicUrl']);
    expect(cache.requests.single.thumbnail, false);
    final image = tester.widget<DriveImage>(find.byType(DriveImage));
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.topCenter);
    photo = {
      ...photo,
      'id': 'photo-b',
      'driveFileId': 'new-drive-file-123456',
      'thumbnailDriveFileId': 'new-drive-thumbnail-123456',
    };
    await show();
    expect(cache.requests.last.id, 'photo-b');
    expect(cache.requests.last.publicUrl, isEmpty);
    expect(cache.requests.last.thumbnail, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
