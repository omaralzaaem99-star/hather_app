import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_theme.dart';
import 'package:hather_app/core/theme/hather_theme_colors.dart';
import 'package:hather_app/core/theme/theme_mode_provider.dart';
import 'package:hather_app/core/theme/theme_preference_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppColors.bind', () {
    test('dark semantic colors match HatherThemeColors.dark', () {
      AppColors.bind(Brightness.dark);
      expect(AppColors.background, HatherThemeColors.dark.background);
      expect(AppColors.textPrimary, HatherThemeColors.dark.textPrimary);
      expect(AppColors.surface, HatherThemeColors.dark.surface);
    });

    test('light semantic colors match HatherThemeColors.light', () {
      AppColors.bind(Brightness.light);
      expect(AppColors.background, HatherThemeColors.light.background);
      expect(AppColors.textPrimary, HatherThemeColors.light.textPrimary);
      expect(AppColors.surface, HatherThemeColors.light.surface);
    });
  });

  group('AppTheme', () {
    test('dark and light themes include HatherThemeColors extension', () {
      final darkExt =
          AppTheme.dark.extension<HatherThemeColors>();
      final lightExt =
          AppTheme.light.extension<HatherThemeColors>();
      expect(darkExt, HatherThemeColors.dark);
      expect(lightExt, HatherThemeColors.light);
    });

    testWidgets('MaterialApp builds in both themes', (tester) async {
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                AppColors.bind(Theme.of(context).brightness);
                return Scaffold(
                  backgroundColor: AppColors.background,
                  body: Text(
                    'حاضر',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                );
              },
            ),
          ),
        );
        expect(find.text('حاضر'), findsOneWidget);
      }
    });
  });

  group('ThemePreferenceRepository', () {
    test('persists and restores light mode', () async {
      SharedPreferences.setMockInitialValues({});
      const repo = ThemePreferenceRepository();
      await repo.save(ThemeMode.light);
      expect(await repo.load(), ThemeMode.light);
    });

    test('persists and restores dark mode', () async {
      SharedPreferences.setMockInitialValues({});
      const repo = ThemePreferenceRepository();
      await repo.save(ThemeMode.dark);
      expect(await repo.load(), ThemeMode.dark);
    });

    test('defaults to dark when unset', () async {
      SharedPreferences.setMockInitialValues({});
      const repo = ThemePreferenceRepository();
      expect(await repo.load(), ThemeMode.dark);
    });
  });

  group('ThemeModeNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('defaults to dark on fresh install', () {
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(AppColors.semantic, HatherThemeColors.dark);
    });

    test('setLight binds AppColors immediately', () async {
      AppColors.bind(Brightness.dark);
      await container.read(themeModeProvider.notifier).setLight();
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(AppColors.background, HatherThemeColors.light.background);
    });

    test('setDark binds AppColors immediately after light', () async {
      AppColors.bind(Brightness.light);
      await container.read(themeModeProvider.notifier).setDark();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(AppColors.background, HatherThemeColors.dark.background);
    });

    test('toggle six times ends on dark without stale colors', () async {
      AppColors.bind(Brightness.dark);
      final notifier = container.read(themeModeProvider.notifier);
      for (var i = 0; i < 6; i++) {
        await notifier.toggle();
      }
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(AppColors.background, HatherThemeColors.dark.background);
    });

    test('loadSaved restores light and binds AppColors', () async {
      const repo = ThemePreferenceRepository();
      await repo.save(ThemeMode.light);
      await container.read(themeModeProvider.notifier).loadSaved();
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(AppColors.background, HatherThemeColors.light.background);
    });

    test('loadSaved with no pref keeps dark default', () async {
      await container.read(themeModeProvider.notifier).loadSaved();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(AppColors.background, HatherThemeColors.dark.background);
    });

    test('persistence round-trip light then dark', () async {
      const repo = ThemePreferenceRepository();
      final notifier = container.read(themeModeProvider.notifier);

      await notifier.setLight();
      expect(await repo.load(), ThemeMode.light);

      await notifier.setDark();
      expect(await repo.load(), ThemeMode.dark);
      expect(AppColors.background, HatherThemeColors.dark.background);
    });
  });
}
