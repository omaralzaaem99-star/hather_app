import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/theme/theme_mode_provider.dart';
import 'package:hather_app/features/account/presentation/widgets/account_widgets.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Theme toggle row for account settings (user + captain).
class AccountThemeSettingRow extends ConsumerWidget {
  const AccountThemeSettingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return AccountSettingsRow(
      label: l10n.themeSettingLabel,
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isDark ? l10n.themeModeDark : l10n.themeModeLight,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Switch(
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}
