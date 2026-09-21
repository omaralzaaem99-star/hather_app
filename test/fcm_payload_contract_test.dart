import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/notifications/fcm_payload_contract.dart';

void main() {
  group('FcmPushPayload', () {
    test('parses data payload contract fields', () {
      final message = RemoteMessage(
        data: const {
          'type': 'delivery_order_accepted',
          'notification_id': 'notif-123',
          'order_id': 'order-456',
          'support_request_id': 'support-789',
        },
      );

      final payload = FcmPushPayload.fromRemoteMessage(message);

      expect(payload.type, 'delivery_order_accepted');
      expect(payload.notificationId, 'notif-123');
      expect(payload.orderId, 'order-456');
      expect(payload.supportRequestId, 'support-789');
      expect(payload.tapDestination, isNull);
    });

    test('parses tap_destination', () {
      final message = RemoteMessage(
        data: const {
          'type': 'admin_broadcast',
          'tap_destination': 'home',
        },
      );

      final payload = FcmPushPayload.fromRemoteMessage(message);

      expect(payload.type, 'admin_broadcast');
      expect(payload.tapDestination, 'home');
    });

    test('ignores empty string values', () {
      final message = RemoteMessage(
        data: const {
          'type': '',
          'notification_id': '   ',
          'order_id': 'order-1',
        },
      );

      final payload = FcmPushPayload.fromRemoteMessage(message);

      expect(payload.type, isNull);
      expect(payload.notificationId, isNull);
      expect(payload.orderId, 'order-1');
    });
  });
}
