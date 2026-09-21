import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';

/// User "طلباتي" list: status priority first, then newest within each status.
int userOrderStatusSortPriority(String status) {
  return switch (status) {
    'pending' => 1,
    'active' => 2,
    'completed' => 3,
    'cancelled' => 4,
    'expired' => 5,
    _ => 6,
  };
}

List<DeliveryOrder> sortUserDeliveryOrders(Iterable<DeliveryOrder> orders) {
  final visible = orders.where((order) => !order.isExpired).toList();
  visible.sort((a, b) {
    final byStatus = userOrderStatusSortPriority(a.status)
        .compareTo(userOrderStatusSortPriority(b.status));
    if (byStatus != 0) return byStatus;
    return b.createdAt.compareTo(a.createdAt);
  });
  return visible;
}
