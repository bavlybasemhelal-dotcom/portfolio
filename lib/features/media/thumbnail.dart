import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as image;
import 'drive_bridge.dart';

/// Decode dimensions before allocating a full image; thumbnail holds <=200 KiB.
Future<Uint8List> createThumbnail(Uint8List bytes) async {
  // Encoded ImageDescriptor dimensions are unsupported in Flutter Web. Read
  // headers only, then ask the platform codec to decode at thumbnail size.
  image.DecodeInfo? dimensions;
  try {
    for (final decoder in <image.Decoder>[
      image.PngDecoder(),
      image.JpegDecoder(),
      image.WebPDecoder(),
    ]) {
      if (decoder.isValidFile(bytes)) {
        dimensions = decoder.startDecode(bytes);
        break;
      }
    }
  } catch (_) {
    throw const DriveFailure('signature_mismatch');
  }
  if (dimensions == null || dimensions.width <= 0 || dimensions.height <= 0) {
    throw const DriveFailure('signature_mismatch');
  }
  if (dimensions.width > 6000 ||
      dimensions.height > 6000 ||
      dimensions.width * dimensions.height > 24000000) {
    throw const DriveFailure('image_dimensions_exceeded');
  }
  final width = dimensions.width.clamp(1, 320);
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: width,
    allowUpscaling: false,
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes > 200 * 1024) {
        throw const DriveFailure('thumbnail_too_large');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
