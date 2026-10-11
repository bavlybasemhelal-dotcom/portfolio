import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yogen_portfolio/core/preferences.dart';

void main() {
  test(
    'First theme switch from a dark system follows the visible theme',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [preferencesStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      expect(container.read(preferencesProvider).theme, ThemeMode.system);
      await container.read(preferencesProvider.notifier).theme(Brightness.dark);
      expect(container.read(preferencesProvider).theme, ThemeMode.light);
      expect(storage.getString('theme'), 'light');
    },
  );
}
