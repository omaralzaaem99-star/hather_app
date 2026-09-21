import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/app/app_router.dart';
import 'package:hather_app/core/notifications/fcm_bootstrap.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_theme.dart';
import 'package:hather_app/core/theme/theme_mode_provider.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class HatherApp extends ConsumerWidget {
  const HatherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final brightness = themeMode == ThemeMode.light
        ? Brightness.light
        : Brightness.dark;

    return FcmBootstrap(
      child: MaterialApp.router(
        title: 'حاضر',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          AppColors.bind(brightness);
          SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle(brightness));
          return Directionality(
            textDirection: TextDirection.rtl,
            child: KeyedSubtree(
              key: ValueKey(themeMode),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        routerConfig: router,
      ),
    );
  }
}
