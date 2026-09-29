import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/notifications/fcm_background_handler.dart';
import 'core/notifications/fcm_notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/controllers/auth_state.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('dotenv.load warning (non-fatal): $e');
    }
  }

  try {
    AppConfig.validate();
  } catch (e) {
    debugPrint('AppConfig.validate warning: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    if (kDebugMode) {
      debugPrint('Firebase initialized');
    }
  } catch (e) {
    debugPrint('Firebase initialization warning (non-fatal): $e');
  }

  final container = ProviderContainer();

  try {
    await container.read(themeModeProvider.notifier).loadSaved();
  } catch (e) {
    debugPrint('Theme load warning (non-fatal): $e');
  }

  final initialMode = container.read(themeModeProvider);

  AppColors.bind(
    initialMode == ThemeMode.light ? Brightness.light : Brightness.dark,
  );

  await _initializeSupabaseIfNeeded();

  _wirePushAuthLifecycle(container);

  runApp(
    UncontrolledProviderScope(container: container, child: const HatherApp()),
  );

  // FCM must not block the first render of the application.
  unawaited(FcmNotificationService.instance.initialize(container: container));
}

Future<void> _initializeSupabaseIfNeeded() async {
  if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) {
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
      debug: kDebugMode,
    );
  } catch (e) {
    debugPrint('Supabase initialization warning (non-fatal): $e');
  }
}

void _wirePushAuthLifecycle(ProviderContainer container) {
  container.listen<AuthState>(authControllerProvider, (previous, next) {
    final wasAuth = previous?.isAuthenticated ?? false;

    if (next.isAuthenticated && !wasAuth) {
      unawaited(FcmNotificationService.instance.syncCurrentDevice());
    }
  }, fireImmediately: true);
}
