import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hather_app/core/notifications/fcm_payload_contract.dart';
import 'package:hather_app/firebase_options.dart';

/// Background / terminated isolate entry point for FCM.
/// Does not insert into [user_notifications] — server remains source of truth.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    final payload = FcmPushPayload.fromRemoteMessage(message);
    debugPrint('FCM background message: $payload');
  }
}
