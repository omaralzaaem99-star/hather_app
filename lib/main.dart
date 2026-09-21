import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/app/app.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/notifications/fcm_background_handler.dart';
import 'package:hather_app/core/notifications/fcm_notification_service.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/theme_mode_provider.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_state.dart';
import 'package:hather_app/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  AppConfig.validate();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    debugPrint('Firebase initialized');
  }

  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).loadSaved();
  final initialMode = container.read(themeModeProvider);
  AppColors.bind(
    initialMode == ThemeMode.light ? Brightness.light : Brightness.dark,
  );

  await _initializeSupabaseIfNeeded();
  await FcmNotificationService.instance.initialize(container: container);
  _wirePushAuthLifecycle(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HatherApp(),
    ),
  );
}

Future<void> _initializeSupabaseIfNeeded() async {
  if (AppConfig.useFakeAuth) {
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
    debug: kDebugMode,
  );
}

void _wirePushAuthLifecycle(ProviderContainer container) {
  container.listen<AuthState>(
    authControllerProvider,
    (previous, next) {
      final wasAuth = previous?.isAuthenticated ?? false;
      if (next.isAuthenticated && !wasAuth) {
        FcmNotificationService.instance.syncCurrentDevice();
      }
    },
    fireImmediately: true,
  );
}
