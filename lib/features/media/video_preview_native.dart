import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../app/yogen_app.dart';
import 'download_native.dart';

class VideoPreview extends StatefulWidget {
  final String fileId, mime;
  final Uint8List? bytes;
  const VideoPreview({
    super.key,
    required this.fileId,
    this.bytes,
    this.mime = 'video/mp4',
  });
  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? player;
  Directory? temporary;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    if (widget.bytes == null ||
        !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return;
    }
    final epoch = ++generation;
    Directory? folder;
    VideoPlayerController? controller;
    try {
      folder = await (await getTemporaryDirectory()).createTemp('yogen-media-');
      final file = File(
        '${folder.path}/video.${widget.mime == 'video/webm' ? 'webm' : 'mp4'}',
      );
      await file.writeAsBytes(widget.bytes!, flush: true);
      controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted || epoch != generation) {
        await controller.dispose();
        await folder.delete(recursive: true);
        return;
      }
      setState(() {
        player = controller;
        temporary = folder;
      });
    } catch (_) {
      await controller?.dispose();
      if (folder != null) await folder.delete(recursive: true);
      if (mounted && epoch == generation) {
        setState(() => error = 'native_playback_unavailable');
      }
    }
  }

  Future<void> release() async {
    final old = player, folder = temporary;
    player = null;
    temporary = null;
    await old?.dispose();
    if (folder != null) await folder.delete(recursive: true);
  }

  @override
  void didUpdateWidget(VideoPreview old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) {
      generation++;
      unawaited(release().then((_) => load()));
    }
  }

  @override
  void dispose() {
    generation++;
    unawaited(release());
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (error != null ||
        !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS) ||
        widget.bytes == null) {
      return Column(
        children: [
          Text(
            tr(
              c,
              'المشغل غير متاح على هذا الجهاز. يمكنك فتح ملف الفيديو.',
              'Playback is unavailable on this device. You can open the video file.',
            ),
          ),
          TextButton(
            onPressed: () => downloadMedia(
              widget.bytes ?? Uint8List(0),
              'video',
              widget.mime,
              widget.fileId,
            ),
            child: Text(tr(c, 'فتح الفيديو', 'Open video')),
          ),
        ],
      );
    }
    final controller = player;
    if (controller == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        VideoProgressIndicator(controller, allowScrubbing: true),
        TextButton.icon(
          onPressed: () async {
            controller.value.isPlaying
                ? await controller.pause()
                : await controller.play();
            if (mounted) setState(() {});
          },
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
          label: Text(
            controller.value.isPlaying
                ? tr(c, 'إيقاف', 'Pause')
                : tr(c, 'تشغيل', 'Play'),
          ),
        ),
      ],
    );
  }
}
