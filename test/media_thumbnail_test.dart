import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:yogen_portfolio/features/media/drive_bridge.dart';
import 'package:yogen_portfolio/features/media/thumbnail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixtures = Directory('assets/fixtures/phase05');
  for (final fixture in <(String, int, int)>[
    ('صورة-أفقية.png', 320, 180),
    ('صورة-رأسية.jpg', 320, 569),
    ('صورة-ويب.webp', 320, 240),
  ]) {
    test(
      'actual ${fixture.$1} produces bounded PNG without distortion',
      () async {
        final bytes = File('${fixtures.path}/${fixture.$1}').readAsBytesSync();
        final thumbnail = await createThumbnail(bytes);
        final decoded = image.decodePng(thumbnail);
        expect(decoded, isNotNull);
        expect(decoded!.width, fixture.$2);
        // Platform codecs can floor or round a nonintegral target height.
        expect(decoded.height, closeTo(fixture.$3, 1));
        expect(thumbnail.length, lessThanOrEqualTo(200 * 1024));
      },
    );
  }
  test('small original is not enlarged', () async {
    final bytes = image.encodePng(image.Image(width: 18, height: 9));
    final decoded = image.decodePng(await createThumbnail(bytes))!;
    expect((decoded.width, decoded.height), (18, 9));
  });
  test('truncated input is rejected before upload', () async {
    await expectLater(
      createThumbnail(Uint8List.fromList([137, 80, 78, 71])),
      throwsA(
        isA<DriveFailure>().having((e) => e.code, 'code', 'signature_mismatch'),
      ),
    );
  });
  // A valid oversized strip is small on disk. The guard rejects its dimensions
  // before the platform allocates a raster or any network operation starts.
  test('oversized image axis is rejected', () async {
    final bytes = image.encodePng(image.Image(width: 6001, height: 1));
    await expectLater(
      createThumbnail(bytes),
      throwsA(
        isA<DriveFailure>().having(
          (e) => e.code,
          'code',
          'image_dimensions_exceeded',
        ),
      ),
    );
  });
}
