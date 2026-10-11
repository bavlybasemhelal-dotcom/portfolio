import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesStorageProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences must be initialized by main.'),
);
final preferencesProvider = NotifierProvider<Preferences, AppPreferences>(
  Preferences.new,
);

class AppPreferences {
  final Locale locale;
  final ThemeMode theme;
  final bool paused;
  final bool reduced;
  const AppPreferences({
    this.locale = const Locale('ar'),
    this.theme = ThemeMode.system,
    this.paused = false,
    this.reduced = false,
  });
}

class Preferences extends Notifier<AppPreferences> {
  @override
  AppPreferences build() {
    final storage = ref.watch(preferencesStorageProvider);
    return AppPreferences(
      locale: Locale(storage.getString('language') == 'en' ? 'en' : 'ar'),
      paused: storage.getBool('motionPaused') ?? false,
      reduced: storage.getBool('motionReduced') ?? false,
      theme: switch (storage.getString('theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
    );
  }

  Future<void> language() async {
    final locale = Locale(state.locale.languageCode == 'ar' ? 'en' : 'ar');
    await setLanguage(locale.languageCode);
  }

  Future<void> setLanguage(String code) async {
    final locale = Locale(code == 'en' ? 'en' : 'ar');
    state = AppPreferences(
      locale: locale,
      theme: state.theme,
      paused: state.paused,
      reduced: state.reduced,
    );
    await ref
        .read(preferencesStorageProvider)
        .setString('language', locale.languageCode);
  }

  Future<void> theme([Brightness? current]) async {
    final isDark =
        state.theme == ThemeMode.dark ||
        (state.theme == ThemeMode.system && current == Brightness.dark);
    final theme = isDark ? ThemeMode.light : ThemeMode.dark;
    state = AppPreferences(
      locale: state.locale,
      theme: theme,
      paused: state.paused,
      reduced: state.reduced,
    );
    await ref.read(preferencesStorageProvider).setString('theme', theme.name);
  }

  void pause() {
    state = AppPreferences(
      locale: state.locale,
      theme: state.theme,
      paused: !state.paused,
      reduced: state.reduced,
    );
    ref.read(preferencesStorageProvider).setBool('motionPaused', state.paused);
  }

  void reduce() {
    state = AppPreferences(
      locale: state.locale,
      theme: state.theme,
      paused: state.paused,
      reduced: !state.reduced,
    );
    ref
        .read(preferencesStorageProvider)
        .setBool('motionReduced', state.reduced);
  }
}
