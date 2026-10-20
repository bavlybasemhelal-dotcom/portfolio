import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/public_content_repository.dart';
import '../media/media_preview.dart';

// Match immutable photo URLs, not member names or IDs. A photo changed in the
// admin must bypass the bundled snapshot and load the newly published image.
const _bundledTeamPhotos = {
  'https://portfolio-14d15.web.app/project-media/cdc2b8d02e0709c580732d62ff02c8d6047cf87d4a8fb0b76773c3ae7c196850.jpg':
      'assets/images/team/george-mounir.jpg',
  'https://portfolio-14d15.web.app/project-media/5db02ecb050da3972927402d588bce7dea13426b775b123ddbff25e3c7541136.jpg':
      'assets/images/team/youssab-wagdy.jpg',
  'https://portfolio-14d15.web.app/project-media/d775788f3eab77b901fff0673bdcc3226266fb00a9fc1a9373875f37ecb7245a.jpg':
      'assets/images/team/bavly-basem.jpg',
};

class TeamPhoto extends ConsumerWidget {
  final Map<String, dynamic> photo;
  final String endpoint, site;
  const TeamPhoto({
    super.key,
    required this.photo,
    required this.endpoint,
    required this.site,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = photo['alt'];
    final alt = description is Map
        ? description[Localizations.localeOf(context).languageCode]
                  as String? ??
              ''
        : description as String? ?? '';
    Widget remote() => DriveImage(
      cache: ref.watch(publicMediaCacheProvider),
      endpoint: endpoint,
      site: site,
      assetId: photo['id'] as String,
      publicUrl: publicImageUrl(photo),
      alt: alt,
      thumbnail: (photo['thumbnailDriveFileId'] as String? ?? '').isNotEmpty,
      height: 300,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );

    final bundled = site == 'yogen'
        ? _bundledTeamPhotos[publicImageUrl(photo)]
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: bundled == null
          ? remote()
          : Image.asset(
              bundled,
              key: ValueKey(bundled),
              semanticLabel: alt,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              cacheWidth: 600,
              errorBuilder: (context, error, stackTrace) => remote(),
            ),
    );
  }
}
