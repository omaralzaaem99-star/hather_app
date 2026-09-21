import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/theme_preference_repository.dart';

final themePreferenceRepositoryProvider =
    Provider<ThemePreferenceRepository>((ref) {
  return const ThemePreferenceRepository();
});

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  static Brightness _brightnessFor(ThemeMode mode) =>
      mode == ThemeMode.light ? Brightness.light : Brightness.dark;

  Future<void> loadSaved() async {
    final saved =
        await ref.read(themePreferenceRepositoryProvider).load();
    state = saved;
    AppColors.bind(_brightnessFor(saved));
  }

  Future<void> setDark() async {
    AppColors.bind(Brightness.dark);
    state = ThemeMode.dark;
    await ref.read(themePreferenceRepositoryProvider).save(ThemeMode.dark);
  }

  Future<void> setLight() async {
    AppColors.bind(Brightness.light);
    state = ThemeMode.light;
    await ref.read(themePreferenceRepositoryProvider).save(ThemeMode.light);
  }

  Future<void> toggle() async {
    if (state == ThemeMode.dark) {
      await setLight();
    } else {
      await setDark();
    }
  }
}
