import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/yogen_app.dart';
import '../../core/backend.dart';
import '../media/drive_bridge.dart';
import '../media/video_preview.dart';

class MediaPage extends ConsumerStatefulWidget {
  const MediaPage({super.key});
  @override
  ConsumerState<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends ConsumerState<MediaPage> {
  final url = TextEditingController(),
      fileId = TextEditingController(),
      videoId = TextEditingController();
  String? previewVideo;
  Uint8List? videoBytes;
  final bridge = DriveBridge();
  DriveFile? uploaded;
  Uint8List? image;
  String? requestId;
  String message = '';
  bool busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (url.text.isEmpty) {
      final query = GoRouterState.of(context).uri.queryParameters;
      url.text =
          query['bridge'] ?? const String.fromEnvironment('DRIVE_WEB_APP_URL');
      fileId.text = query['file'] ?? '';
      videoId.text = query['video'] ?? '';
    }
  }

  @override
  void dispose() {
    url.dispose();
    fileId.dispose();
    videoId.dispose();
    bridge.close();
    super.dispose();
  }

  Future<void> action(Future<String> Function() operation) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final text = await operation();
      if (mounted) setState(() => message = text);
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String> token() async {
    final backend = ref.read(backendProvider.notifier);
    if (!ref.read(backendProvider).ready || backend.auth.currentUser == null) {
      throw const DriveFailure('sign_in_required');
    }
    return (await backend.auth.currentUser!.getIdToken())!;
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr(c, 'تجربة الوسائط', 'Media experiment'),
        style: Theme.of(c).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(
        tr(
          c,
          'حد حماية التجربة: 5 MiB. لم يعتمد بعد كحد رفع للخدمة. تسجيل الدخول مطلوب للرفع فقط.',
          'Experimental guardrail: 5 MiB. This is not a validated service limit. Only uploading requires sign-in.',
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: url,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'Apps Script Web App URL'),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton(
            onPressed: busy
                ? null
                : () => action(() async {
                    await bridge.ping(url.text, await token());
                    return 'bridge_ready';
                  }),
            child: Text(tr(c, 'فحص الاتصال', 'Check bridge')),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () => action(() async {
                    final idToken = await token();
                    final files = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: [
                        'png',
                        'jpg',
                        'jpeg',
                        'webp',
                        'mp4',
                        'webm',
                        'pdf',
                      ],
                    );
                    if (files.isEmpty) return 'cancelled';
                    final file = files.single;
                    final size = await file.length();
                    MediaPolicy.validateSize(size);
                    final bytes = await file.readAsBytes();
                    requestId = DateTime.now()
                        .toUtc()
                        .microsecondsSinceEpoch
                        .toString();
                    final value = await bridge.upload(
                      url: url.text,
                      token: idToken,
                      bytes: bytes,
                      name: file.name,
                      mime: MediaPolicy.mime(file.name),
                      requestId: requestId!,
                    );
                    uploaded = value;
                    fileId.text = value.id;
                    await ref
                        .read(backendProvider.notifier)
                        .recordMedia(requestId!, value.toMap());
                    return 'uploaded_and_recorded: ${value.id}';
                  }),
            child: Text(tr(c, 'اختيار ورفع ملف', 'Choose and upload')),
          ),
          OutlinedButton(
            onPressed: busy || uploaded == null
                ? null
                : () => action(() async {
                    await ref
                        .read(backendProvider.notifier)
                        .recordMedia(requestId!, uploaded!.toMap());
                    return 'metadata_recorded_without_reupload';
                  }),
            child: Text(tr(c, 'إعادة حفظ المرجع', 'Retry metadata')),
          ),
        ],
      ),
      const SizedBox(height: 24),
      TextField(
        controller: fileId,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(
          labelText: 'Public test image file ID',
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => action(() async {
                final value = await bridge.image(url.text, fileId.text.trim());
                if (mounted) setState(() => image = value);
                return 'anonymous_image_loaded: ${value.length} bytes';
              }),
        child: Text(tr(c, 'عرض الصورة بدون دخول', 'Display without login')),
      ),
      const SizedBox(height: 16),
      if (busy) const LinearProgressIndicator(),
      Text(message),
      if (uploaded != null)
        SelectableText(
          'Drive: ${uploaded!.name} · ${uploaded!.bytes} bytes · ${uploaded!.id}',
        ),
      if (image != null) ...[
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Image.memory(
              image!,
              height: 240,
              fit: BoxFit.contain,
              semanticLabel: 'Drive test image card',
              errorBuilder: (_, _, _) => const Text('invalid_image_bytes'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Image.memory(
          image!,
          height: 360,
          fit: BoxFit.contain,
          semanticLabel: 'Drive test image gallery',
          errorBuilder: (_, _, _) => const Text('invalid_image_bytes'),
        ),
      ],
      const SizedBox(height: 24),
      TextField(
        controller: videoId,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(
          labelText: 'Public test video file ID',
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () {
          if (RegExp(r'^[\w-]{10,}$').hasMatch(videoId.text.trim())) {
            setState(() {
              previewVideo = videoId.text.trim();
              videoBytes = null;
            });
          } else {
            setState(() => message = 'invalid_file_id');
          }
        },
        child: Text(tr(c, 'معاينة الفيديو', 'Preview video')),
      ),
      OutlinedButton(
        onPressed: busy
            ? null
            : () => action(() async {
                final bytes = await bridge.video(url.text, videoId.text.trim());
                if (mounted) {
                  setState(() {
                    videoBytes = bytes;
                    previewVideo = videoId.text.trim();
                  });
                }
                return 'anonymous_video_loaded: ${bytes.length} bytes';
              }),
        child: Text(tr(c, 'تحميل الفيديو وتشغيله', 'Load video and play')),
      ),
      if (previewVideo != null)
        VideoPreview(fileId: previewVideo!, bytes: videoBytes),
    ],
  );
}
