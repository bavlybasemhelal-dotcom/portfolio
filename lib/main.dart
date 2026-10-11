import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/yogen_app.dart';
import 'core/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await SharedPreferences.getInstance();
  // Hash routes are used on static hosting. Apply explicit link language before
  // the first frame, then let system brightness decide the initial theme.
  final initial = Uri.base.fragment.startsWith('/')
      ? Uri.tryParse(Uri.base.fragment)
      : Uri.base;
  final lang = initial?.queryParameters['lang'];
  if (lang == 'ar' || lang == 'en') await storage.setString('language', lang!);
  runApp(
    ProviderScope(
      overrides: [preferencesStorageProvider.overrideWithValue(storage)],
      child: const YogenApp(),
    ),
  );
}
