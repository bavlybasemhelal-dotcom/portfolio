import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'drive_bridge.dart';

Future<void> downloadMedia(
  Uint8List bytes,
  String name,
  String mime,
  String fileId,
) async {
  if (!RegExp(r'^[\w-]{10,200}$').hasMatch(fileId)) {
    throw const DriveFailure('invalid_file_id');
  }
  if (!await launchUrl(
    Uri.https('drive.google.com', '/uc', {'export': 'download', 'id': fileId}),
    mode: LaunchMode.externalApplication,
  )) {
    throw const DriveFailure('download_unavailable');
  }
}
