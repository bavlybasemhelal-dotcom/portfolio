import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/features/media/drive_bridge.dart';

void main() {
  test('Reject 20/50/100 MiB before reading or allocating file bytes', () {
    for (final size in [20, 50, 100]) {
      expect(
        () => MediaPolicy.validateSize(size * 1024 * 1024),
        throwsA(isA<DriveFailure>()),
      );
    }
    MediaPolicy.validateSize(5 * 1024 * 1024);
    expect(() => MediaPolicy.validateSize(null), throwsA(isA<DriveFailure>()));
    expect(() => MediaPolicy.validateSize(0), throwsA(isA<DriveFailure>()));
  });
}
