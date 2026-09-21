import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';

abstract class DeliveryRemoteDataSource {
  Future<List<OrderTypeOption>> fetchOrderTypes();
  Future<DeliveryOrderSettings> fetchOrderSettings();
  Future<List<HomeAd>> fetchHomeAds();
  Future<CouponValidation> validateCoupon({
    required String code,
    required String feeOptionId,
  });
  Future<DeliveryOrder> createOrder(CreateDeliveryOrderInput input);
  Future<List<DeliveryOrder>> fetchMyOrders();
  Future<DeliveryOrder> getOrderDetail(String orderId);
  Future<DeliveryOrder> cancelOrder(String orderId);
}
