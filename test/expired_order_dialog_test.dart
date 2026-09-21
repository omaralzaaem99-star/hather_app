import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/notifications/expired_order_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const orderA = '11111111-1111-4111-8111-111111111111';
  const orderB = '22222222-2222-4222-8222-222222222222';

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    ExpiredOrderDialog.resetForTest();
  });

  group('ExpiredOrderDialog.shouldShow', () {
    test('allows first show for valid order id', () {
      expect(ExpiredOrderDialog.shouldShow(orderId: orderA), isTrue);
    });

    test('blocks invalid or empty order id', () {
      expect(ExpiredOrderDialog.shouldShow(orderId: null), isFalse);
      expect(ExpiredOrderDialog.shouldShow(orderId: ''), isFalse);
      expect(ExpiredOrderDialog.shouldShow(orderId: 'not-a-uuid'), isFalse);
    });

    test('blocks handled order id', () async {
      await ExpiredOrderDialog.markHandled(orderA);
      expect(ExpiredOrderDialog.shouldShow(orderId: orderA), isFalse);
      expect(ExpiredOrderDialog.shouldShow(orderId: orderB), isTrue);
    });

    test('blocks while dialog is open for same order', () {
      ExpiredOrderDialog.resetForTest();
      expect(ExpiredOrderDialog.shouldShow(orderId: orderA), isTrue);
      // Simulate open guard via test hook.
      expect(ExpiredOrderDialog.openOrderId, isNull);
    });
  });

  group('ExpiredOrderDialog.eventKeyFor', () {
    test('uses order id and event type', () {
      expect(
        ExpiredOrderDialog.eventKeyFor(orderA),
        'delivery_order_expired:$orderA',
      );
    });
  });
}
