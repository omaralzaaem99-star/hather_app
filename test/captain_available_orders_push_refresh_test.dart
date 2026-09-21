import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/captain/presentation/providers/captain_available_orders_push_refresh.dart';

void main() {
  group('shouldRefreshCaptainAvailableOrdersFromPush', () {
    test('refreshes for new available order push types', () {
      expect(
        shouldRefreshCaptainAvailableOrdersFromPush('delivery_order_available'),
        isTrue,
      );
      expect(
        shouldRefreshCaptainAvailableOrdersFromPush('delivery_order_released'),
        isTrue,
      );
    });

    test('does not refresh for unrelated push types', () {
      for (final type in [
        'delivery_order_assigned',
        'delivery_order_cancelled',
        'delivery_order_completed',
        'delivery_order_accepted',
        'admin_broadcast',
        'support_reply',
        null,
        '',
      ]) {
        expect(
          shouldRefreshCaptainAvailableOrdersFromPush(type),
          isFalse,
          reason: type ?? 'null',
        );
      }
    });
  });
}
