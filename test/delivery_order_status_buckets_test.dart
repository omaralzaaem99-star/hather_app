import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';

void main() {
  DeliveryOrder order({required String status}) {
    return DeliveryOrder(
      id: 'o1',
      orderTypeName: 'طلب دلفري',
      details: 'x',
      status: status,
      createdAt: DateTime.utc(2026, 8, 26),
      expiresAt: DateTime.utc(2026, 8, 26, 15),
    );
  }

  test('ongoing / completed / previous status buckets', () {
    expect(order(status: 'pending').isOngoing, isTrue);
    expect(order(status: 'active').isOngoing, isTrue);
    expect(order(status: 'completed').isCompleted, isTrue);
    expect(order(status: 'completed').isPrevious, isFalse);
    expect(order(status: 'cancelled').isPrevious, isTrue);
    expect(order(status: 'expired').isPrevious, isFalse);
    expect(order(status: 'expired').isOngoing, isFalse);
    expect(order(status: 'expired').isCompleted, isFalse);
  });
}
