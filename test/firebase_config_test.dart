import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/core/firebase_config.dart';

void main() {
  const config = FirebaseConfig(
    apiKey: 'test-public-key',
    appId: '1:123:web:abc123',
    messagingSenderId: '123',
  );
  test('Correct project and compatible platform are mandatory', () {
    config.validatePlatform(TargetPlatform.windows, web: false);
    expect(
      () => config.validatePlatform(TargetPlatform.android, web: false),
      throwsFormatException,
    );
    expect(
      () => config.validatePlatform(TargetPlatform.linux, web: false),
      throwsUnsupportedError,
    );
    expect(
      () => FirebaseConfig.fromMap({'projectId': 'other-project'}),
      throwsFormatException,
    );
    expect(
      () => const FirebaseConfig(
        apiKey: 'test-public-key',
        appId: '1:123:web:abc',
        messagingSenderId: '999',
      ).validatePlatform(TargetPlatform.windows, web: false),
      throwsFormatException,
    );
  });
  test('Public definitions map into the correct Firebase options', () {
    final loaded = FirebaseConfig.fromMap({
      'FIREBASE_PROJECT_ID': 'portfolio-14d15',
      'FIREBASE_API_KEY': 'test-public-key',
      'FIREBASE_APP_ID': '1:123:web:abc123',
      'FIREBASE_MESSAGING_SENDER_ID': '123',
    });
    expect(loaded.options.projectId, 'portfolio-14d15');
    expect(loaded.isConfigured, true);
  });
}
