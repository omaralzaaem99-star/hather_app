import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';

abstract class DeliveryRepository {
  Future<Result<List<OrderTypeOption>>> fetchOrderTypes();
  Future<Result<DeliveryOrderSettings>> fetchOrderSettings();
  Future<Result<List<HomeAd>>> fetchHomeAds();
  Future<Result<CouponValidation>> validateCoupon({
    required String code,
    required String feeOptionId,
  });
  Future<Result<DeliveryOrder>> createOrder(CreateDeliveryOrderInput input);
  Future<Result<List<DeliveryOrder>>> fetchMyOrders();
  Future<Result<DeliveryOrder>> getOrderDetail(String orderId);
  Future<Result<DeliveryOrder>> cancelOrder(String orderId);
}
