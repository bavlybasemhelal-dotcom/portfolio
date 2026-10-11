import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class VideoPreview extends StatefulWidget {
  final String fileId;
  final Uint8List? bytes;
  final String mime;
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
  String? blobUrl;
  web.HTMLVideoElement? video;
  void release() {
    video?.pause();
    video?.src = '';
    video = null;
    if (blobUrl != null) web.URL.revokeObjectURL(blobUrl!);
    blobUrl = null;
  }

  @override
  void didUpdateWidget(VideoPreview old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) release();
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 350,
    child: widget.bytes == null
        ? HtmlElementView.fromTagName(
            key: ValueKey('iframe-${widget.fileId}'),
            tagName: 'iframe',
            onElementCreated: (element) {
              final frame = element as web.HTMLIFrameElement;
              frame.src =
                  'https://drive.google.com/file/d/${widget.fileId}/preview';
              frame.title = 'Drive video preview';
              frame.allow = 'autoplay; fullscreen';
              frame.style.border = '0';
              frame.style.width = '100%';
              frame.style.height = '100%';
            },
          )
        : HtmlElementView.fromTagName(
            key: ValueKey(widget.bytes),
            tagName: 'video',
            onElementCreated: (element) {
              release();
              final blob = web.Blob(
                [widget.bytes!.toJS].toJS,
                web.BlobPropertyBag(type: widget.mime),
              );
              blobUrl = web.URL.createObjectURL(blob);
              video = element as web.HTMLVideoElement;
              video!.src = blobUrl!;
              video!.controls = true;
              video!.preload = 'metadata';
              video!.setAttribute('aria-label', 'Drive MP4 video');
              video!.style.width = '100%';
              video!.style.height = '100%';
              video!.style.backgroundColor = '#081625';
            },
          ),
  );
}
