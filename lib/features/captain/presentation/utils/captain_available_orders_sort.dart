import 'package:hather_app/features/captain/domain/entities/captain_order.dart';

/// Captain home "الطلبات المتاحة": oldest created order first (FIFO).
List<CaptainAvailableOrder> sortCaptainAvailableOrders(
  Iterable<CaptainAvailableOrder> orders,
) {
  final sorted = orders.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return sorted;
}
