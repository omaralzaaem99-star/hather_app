import 'package:firebase_messaging/firebase_messaging.dart';

/// Data payload keys for Hather FCM push messages.
abstract final class FcmPayloadContract {
  static const String type = 'type';
  static const String notificationId = 'notification_id';
  static const String orderId = 'order_id';
  static const String supportRequestId = 'support_request_id';
  static const String tapDestination = 'tap_destination';
}

/// Parsed FCM data payload — read-only; never writes to [user_notifications].
class FcmPushPayload {
  const FcmPushPayload({
    this.type,
    this.notificationId,
    this.orderId,
    this.supportRequestId,
    this.tapDestination,
  });

  final String? type;
  final String? notificationId;
  final String? orderId;
  final String? supportRequestId;
  final String? tapDestination;

  factory FcmPushPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    return FcmPushPayload(
      type: _stringOrNull(data[FcmPayloadContract.type]),
      notificationId: _stringOrNull(data[FcmPayloadContract.notificationId]),
      orderId: _stringOrNull(data[FcmPayloadContract.orderId]),
      supportRequestId: _stringOrNull(data[FcmPayloadContract.supportRequestId]),
      tapDestination: _stringOrNull(data[FcmPayloadContract.tapDestination]),
    );
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  String toString() =>
      'FcmPushPayload(type: $type, notificationId: $notificationId, '
      'orderId: $orderId, supportRequestId: $supportRequestId, '
      'tapDestination: $tapDestination)';
}
