import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:hather_app/features/captain/presentation/utils/captain_available_orders_sort.dart';

void main() {
  CaptainAvailableOrder orderAt(DateTime createdAt, {String id = 'o1'}) {
    return CaptainAvailableOrder(
      id: id,
      orderTypeName: 'طلب',
      details: 'تفاصيل',
      destinationLabel: 'الكرادة',
      deliveryFeeIqd: 3000,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 1)),
    );
  }

  test('sortCaptainAvailableOrders orders oldest created_at first', () {
    final t430 = DateTime.utc(2026, 1, 1, 13, 30);
    final t410 = DateTime.utc(2026, 1, 1, 13, 10);
    final t350 = DateTime.utc(2026, 1, 1, 12, 50);

    final sorted = sortCaptainAvailableOrders([
      orderAt(t410, id: 'middle'),
      orderAt(t350, id: 'oldest'),
      orderAt(t430, id: 'newest'),
    ]);

    expect(sorted.map((o) => o.id).toList(), ['oldest', 'middle', 'newest']);
  });
}
