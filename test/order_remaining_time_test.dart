import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/delivery/presentation/utils/order_remaining_time.dart';

void main() {
  group('OrderRemainingTime', () {
    final now = DateTime(2026, 8, 27, 12, 0);

    test('formats minutes only', () {
      final expires = now.add(const Duration(minutes: 10));
      expect(
        OrderRemainingTime.compactLabel(expires, now: now),
        'متبقي 10 دقائق',
      );
      expect(
        OrderRemainingTime.detailValue(expires, now: now),
        '10 دقائق',
      );
    });

    test('formats one hour with minutes', () {
      final expires = now.add(const Duration(hours: 1, minutes: 20));
      expect(
        OrderRemainingTime.compactLabel(expires, now: now),
        'متبقي ساعة و20 دقائق',
      );
    });

    test('formats whole hours', () {
      final expires = now.add(const Duration(hours: 5));
      expect(
        OrderRemainingTime.compactLabel(expires, now: now),
        'متبقي 5 ساعات',
      );
    });

    test('expired label', () {
      final expires = now.subtract(const Duration(minutes: 1));
      expect(
        OrderRemainingTime.compactLabel(expires, now: now),
        'انتهت مدة الطلب',
      );
      expect(OrderRemainingTime.isExpired(expires, now: now), isTrue);
    });

    test('less than one minute', () {
      final expires = now.add(const Duration(seconds: 40));
      expect(
        OrderRemainingTime.detailValue(expires, now: now),
        'أقل من دقيقة',
      );
    });
  });
}
