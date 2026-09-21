import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/features/delivery/presentation/utils/user_orders_sort.dart';

DeliveryOrder _order({
  required String id,
  required String status,
  required DateTime createdAt,
}) {
  return DeliveryOrder(
    id: id,
    orderTypeName: 'دلفري',
    details: 'تفاصيل $id',
    status: status,
    createdAt: createdAt,
  );
}

void main() {
  final t1 = DateTime.utc(2026, 8, 29, 10);
  final t2 = DateTime.utc(2026, 8, 29, 9);
  final t3 = DateTime.utc(2026, 8, 28, 12);
  final t4 = DateTime.utc(2026, 8, 27, 8);

  test('active appears before completed', () {
    final sorted = sortUserDeliveryOrders([
      _order(id: 'c1', status: 'completed', createdAt: t1),
      _order(id: 'a1', status: 'active', createdAt: t2),
    ]);

    expect(sorted.map((o) => o.id).toList(), ['a1', 'c1']);
  });

  test('pending then active then completed', () {
    final sorted = sortUserDeliveryOrders([
      _order(id: 'c3', status: 'completed', createdAt: t1),
      _order(id: 'c2', status: 'completed', createdAt: t2),
      _order(id: 'c1', status: 'completed', createdAt: t3),
      _order(id: 'a1', status: 'active', createdAt: t4),
      _order(id: 'p1', status: 'pending', createdAt: t2),
    ]);

    expect(sorted.map((o) => o.id).toList(), [
      'p1',
      'a1',
      'c3',
      'c2',
      'c1',
    ]);
  });

  test('newest first within same status', () {
    final sorted = sortUserDeliveryOrders([
      _order(id: 'a-old', status: 'active', createdAt: t3),
      _order(id: 'a-new', status: 'active', createdAt: t1),
      _order(id: 'a-mid', status: 'active', createdAt: t2),
    ]);

    expect(sorted.map((o) => o.id).toList(), ['a-new', 'a-mid', 'a-old']);
  });

  test('active completed cancelled order', () {
    final sorted = sortUserDeliveryOrders([
      _order(id: 'x-cancel', status: 'cancelled', createdAt: t1),
      _order(id: 'x-done', status: 'completed', createdAt: t2),
      _order(id: 'x-live', status: 'active', createdAt: t3),
    ]);

    expect(sorted.map((o) => o.id).toList(), [
      'x-live',
      'x-done',
      'x-cancel',
    ]);
  });

  test('expired orders are excluded', () {
    final sorted = sortUserDeliveryOrders([
      _order(id: 'expired', status: 'expired', createdAt: t1),
      _order(id: 'active', status: 'active', createdAt: t2),
    ]);

    expect(sorted.map((o) => o.id).toList(), ['active']);
  });
}
