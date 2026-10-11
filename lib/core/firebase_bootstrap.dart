import 'package:firebase_core/firebase_core.dart';
import 'firebase_config.dart';

class FirebaseBootstrap {
  static Future<FirebaseApp>? _initializing;
  static Future<FirebaseApp> initialize(FirebaseConfig config) {
    if (Firebase.apps.isNotEmpty) {
      final app = Firebase.app();
      if (app.options.appId != config.appId) {
        throw StateError(
          'Firebase app configuration changed. Restart the app.',
        );
      }
      return Future.value(app);
    }
    return _initializing ??= Firebase.initializeApp(
      options: config.options,
    ).timeout(const Duration(seconds: 20));
  }
}
