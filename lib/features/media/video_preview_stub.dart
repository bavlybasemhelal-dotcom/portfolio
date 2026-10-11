import 'package:flutter/material.dart';
import 'dart:typed_data';

class VideoPreview extends StatelessWidget {
  final String fileId;
  final Uint8List? bytes;
  const VideoPreview({super.key, required this.fileId, this.bytes});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        'Drive preview: https://drive.google.com/file/d/$fileId/view\n'
        'Native player selection is a phase-05 check.',
      ),
    ),
  );
}
