import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client configuration only; never a service-account credential.
class FirebaseConfig {
  static const projectId = 'portfolio-14d15';
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String authDomain;
  final String storageBucket;
  final String iosBundleId;

  const FirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    this.authDomain = 'portfolio-14d15.firebaseapp.com',
    this.storageBucket = '',
    this.iosBundleId = 'com.yogen.portfolio',
  });

  factory FirebaseConfig.fromMap(Map<String, dynamic> json) {
    if ((json['projectId'] ?? json['FIREBASE_PROJECT_ID']) != projectId) {
      throw const FormatException('Firebase project must be portfolio-14d15.');
    }
    String field(String name, String define) =>
        (json[name] ?? json[define] ?? '').toString().trim();
    final config = FirebaseConfig(
      apiKey: field('apiKey', 'FIREBASE_API_KEY'),
      appId: field('appId', 'FIREBASE_APP_ID'),
      messagingSenderId: field(
        'messagingSenderId',
        'FIREBASE_MESSAGING_SENDER_ID',
      ),
      authDomain: field('authDomain', 'FIREBASE_AUTH_DOMAIN'),
      storageBucket: field('storageBucket', 'FIREBASE_STORAGE_BUCKET'),
      iosBundleId: field('iosBundleId', 'FIREBASE_IOS_BUNDLE_ID'),
    );
    if (!config.isConfigured) {
      throw const FormatException(
        'apiKey, appId and messagingSenderId required.',
      );
    }
    return config;
  }

  static const environment = FirebaseConfig(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'portfolio-14d15.firebaseapp.com',
    ),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.yogen.portfolio',
    ),
  );

  bool get isConfigured =>
      apiKey.isNotEmpty &&
      RegExp(r'^1:\d+:(web|android|ios):[a-zA-Z0-9]+$').hasMatch(appId) &&
      RegExp(r'^\d+$').hasMatch(messagingSenderId);

  bool supports(TargetPlatform platform, {bool web = kIsWeb}) =>
      web || platform != TargetPlatform.linux;

  void validatePlatform(TargetPlatform platform, {bool web = kIsWeb}) {
    if (!supports(platform, web: web)) {
      throw UnsupportedError('FlutterFire has no Linux client in this stack.');
    }
    final type = web || platform == TargetPlatform.windows
        ? 'web'
        : platform == TargetPlatform.android
        ? 'android'
        : 'ios';
    if (!appId.contains(':$type:')) {
      throw FormatException('Register Firebase $type app for this platform.');
    }
    if (messagingSenderId != appId.split(':')[1]) {
      throw const FormatException('appId and messagingSenderId do not match.');
    }
  }

  FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
    iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
  );
}
