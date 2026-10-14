import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../app/yogen_app.dart';
import '../../core/viewport_visibility.dart';
import 'media_transport.dart';
import 'video_preview.dart';
import 'download.dart';

class DriveImage extends StatefulWidget {
  final MediaByteCache cache;
  final String endpoint, site, assetId, alt;

  /// Only supplied for files already published with public Drive sharing.
  final String? publicFileId;
  final String? publicUrl;
  final bool thumbnail;
  final double height;
  final BoxFit fit;
  final Alignment alignment;
  const DriveImage({
    super.key,
    required this.cache,
    required this.endpoint,
    required this.site,
    required this.assetId,
    required this.alt,
    this.publicFileId,
    this.publicUrl,
    this.thumbnail = false,
    this.height = 180,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });
  @override
  State<DriveImage> createState() => _DriveImageState();
}

class _DriveImageState extends State<DriveImage> {
  Future<Uint8List>? future;
  bool visible = false;
  int networkRevision = 0;

  void visibilityChanged(bool value) {
    if (!mounted || (visible == value && !(value && future == null))) return;
    setState(() {
      visible = value;
      if (value && future == null) load();
    });
  }

  void load({bool retry = false}) {
    if (publicImageUrl != null) return;
    future = widget.cache.read(
      widget.endpoint,
      widget.site,
      widget.assetId,
      thumbnail: widget.thumbnail,
      retry: retry,
    );
  }

  String? get publicImageUrl {
    final hosted = Uri.tryParse(widget.publicUrl ?? '');
    if (hosted != null &&
        hosted.scheme == 'https' &&
        hosted.host == 'portfolio-14d15.web.app' &&
        hosted.userInfo.isEmpty &&
        !hosted.hasQuery &&
        !hosted.hasFragment &&
        RegExp(r'^/project-media/[a-f0-9]{64}\.jpg$').hasMatch(hosted.path)) {
      return hosted.toString();
    }
    final id = widget.publicFileId;
    if (id == null || !RegExp(r'^[\w-]{10,}$').hasMatch(id)) return null;
    return 'https://lh3.googleusercontent.com/d/$id';
  }

  Widget publicImage(BuildContext c) {
    if (!visible) {
      return SizedBox(height: widget.height, width: double.infinity);
    }
    return Image.network(
      publicImageUrl!,
      key: ValueKey('$publicImageUrl:$networkRevision'),
      height: widget.height,
      width: double.infinity,
      fit: widget.fit,
      alignment: widget.alignment,
      semanticLabel: widget.alt,
      loadingBuilder: (c, child, progress) => progress == null
          ? child
          : SizedBox(
              height: widget.height,
              width: double.infinity,
              child: const Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      // Retain verified receipt reads and their retry UI if the public image
      // service is unavailable; do not expose arbitrary URLs or private files.
      errorBuilder: (c, _, _) => (widget.publicFileId ?? '').isEmpty
          ? failure(
              c,
              onRetry: () async {
                await NetworkImage(publicImageUrl!).evict();
                if (mounted) setState(() => networkRevision++);
              },
            )
          : DriveImage(
              cache: widget.cache,
              endpoint: widget.endpoint,
              site: widget.site,
              assetId: widget.assetId,
              alt: widget.alt,
              thumbnail: widget.thumbnail,
              height: widget.height,
              fit: widget.fit,
              alignment: widget.alignment,
            ),
    );
  }

  @override
  void didUpdateWidget(DriveImage old) {
    super.didUpdateWidget(old);
    if (old.assetId != widget.assetId ||
        old.endpoint != widget.endpoint ||
        old.site != widget.site ||
        old.thumbnail != widget.thumbnail ||
        old.publicFileId != widget.publicFileId ||
        old.publicUrl != widget.publicUrl) {
      future = null;
      if (visible) load();
    }
  }

  Widget failure(BuildContext c, {VoidCallback? onRetry}) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined),
          Text(tr(c, 'تعذر تحميل الصورة', 'Image unavailable')),
          TextButton(
            onPressed: onRetry ?? () => setState(() => load(retry: true)),
            child: Text(tr(c, 'إعادة المحاولة', 'Retry')),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext c) => ViewportVisibility(
    onChanged: visibilityChanged,
    child: TickerMode(
      enabled: visible,
      child: publicImageUrl != null
          ? publicImage(c)
          : FutureBuilder<Uint8List>(
              key: ValueKey(
                '${widget.endpoint}:${widget.site}:${widget.assetId}:${widget.thumbnail}',
              ),
              future: future,
              builder: (c, result) {
                if (result.hasError) return failure(c);
                if (future == null) {
                  return SizedBox(
                    height: widget.height,
                    width: double.infinity,
                  );
                }
                if (!result.hasData) {
                  return SizedBox(
                    height: widget.height,
                    width: double.infinity,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                return Semantics(
                  image: true,
                  label: widget.alt,
                  child: Image.memory(
                    result.data!,
                    height: widget.height,
                    width: double.infinity,
                    fit: widget.fit,
                    alignment: widget.alignment,
                    cacheWidth: widget.thumbnail ? 320 : 1600,
                    excludeFromSemantics: true,
                    errorBuilder: (c, _, _) => failure(c),
                  ),
                );
              },
            ),
    ),
  );
}

class MediaViewer extends StatefulWidget {
  final MediaByteCache cache;
  final String endpoint, site;
  final Map<String, dynamic> asset;
  final Map<String, dynamic>? cover;
  const MediaViewer({
    super.key,
    required this.cache,
    required this.endpoint,
    required this.site,
    required this.asset,
    this.cover,
  });
  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  Future<Uint8List>? video;
  bool downloading = false;
  String? error;
  String get id => widget.asset['id'] as String;
  String get mime => widget.asset['mime'] as String;
  @override
  void didUpdateWidget(MediaViewer old) {
    super.didUpdateWidget(old);
    if (old.asset['id'] != id ||
        old.endpoint != widget.endpoint ||
        old.site != widget.site ||
        old.asset['mime'] != mime) {
      video = null;
      error = null;
      downloading = false;
    }
  }

  String alt(BuildContext c, Map<String, dynamic> asset) =>
      asset['alt'][Localizations.localeOf(c).languageCode] as String;
  Future<void> download() async {
    setState(() {
      downloading = true;
      error = null;
    });
    try {
      final bytes = await widget.cache.read(widget.endpoint, widget.site, id);
      await downloadMedia(
        bytes,
        widget.asset['name'] as String,
        mime,
        widget.asset['driveFileId'] as String,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = tr(
            context,
            'تعذر التنزيل. حاول مرة أخرى.',
            'Download failed. Try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (mime.startsWith('image/')) {
      return DriveImage(
        cache: widget.cache,
        endpoint: widget.endpoint,
        site: widget.site,
        assetId: id,
        alt: alt(c, widget.asset),
        publicFileId: widget.asset['driveFileId'] as String?,
        publicUrl: widget.asset['publicUrl'] as String?,
        height: 380,
      );
    }
    if (mime.startsWith('video/')) {
      if (video == null) {
        return Column(
          children: [
            if (widget.cover != null)
              DriveImage(
                cache: widget.cache,
                endpoint: widget.endpoint,
                site: widget.site,
                assetId: widget.cover!['id'] as String,
                alt: alt(c, widget.cover!),
              ),
            FilledButton.icon(
              onPressed: () => setState(() {
                video = widget.cache.read(widget.endpoint, widget.site, id);
              }),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                tr(c, 'تحميل الفيديو وتشغيله', 'Load and play video'),
              ),
            ),
          ],
        );
      }
      return FutureBuilder<Uint8List>(
        future: video,
        builder: (c, result) {
          if (result.hasError) {
            return Column(
              children: [
                Text(tr(c, 'تعذر تحميل الفيديو', 'Video unavailable')),
                TextButton(
                  onPressed: () => setState(() => video = null),
                  child: Text(tr(c, 'إعادة المحاولة', 'Retry')),
                ),
              ],
            );
          }
          if (!result.hasData) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return VideoPreview(
            fileId: widget.asset['driveFileId'] as String,
            bytes: result.data,
            mime: mime,
          );
        },
      );
    }
    return Column(
      children: [
        const Icon(Icons.picture_as_pdf, size: 48),
        Text(widget.asset['name'] as String),
        if (error != null) Text(error!),
        FilledButton.icon(
          onPressed: downloading ? null : download,
          icon: downloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(),
                )
              : const Icon(Icons.download),
          label: Text(tr(c, 'تنزيل المرفق', 'Download attachment')),
        ),
      ],
    );
  }
}
