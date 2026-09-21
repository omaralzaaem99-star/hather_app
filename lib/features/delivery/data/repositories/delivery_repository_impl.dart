import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/delivery/data/datasources/delivery_remote_datasource.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:hather_app/features/delivery/presentation/utils/user_orders_sort.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  DeliveryRepositoryImpl({
    required DeliveryRemoteDataSource remote,
  }) : _remote = remote;

  final DeliveryRemoteDataSource _remote;

  @override
  Future<Result<List<OrderTypeOption>>> fetchOrderTypes() => _guard(
        () => _remote.fetchOrderTypes(),
        context: BackendErrorContext.deliverySettings,
      );

  @override
  Future<Result<DeliveryOrderSettings>> fetchOrderSettings() => _guard(
        () => _remote.fetchOrderSettings(),
        context: BackendErrorContext.deliverySettings,
      );

  @override
  Future<Result<List<HomeAd>>> fetchHomeAds() => _guard(
        () => _remote.fetchHomeAds(),
        context: BackendErrorContext.generic,
      );

  @override
  Future<Result<CouponValidation>> validateCoupon({
    required String code,
    required String feeOptionId,
  }) =>
      _guard(
        () => _remote.validateCoupon(code: code, feeOptionId: feeOptionId),
        context: BackendErrorContext.deliveryCoupon,
      );

  @override
  Future<Result<DeliveryOrder>> createOrder(CreateDeliveryOrderInput input) {
    return _guard(
      () => _remote.createOrder(input),
      context: BackendErrorContext.deliverySubmit,
    );
  }

  @override
  Future<Result<List<DeliveryOrder>>> fetchMyOrders() {
    return _guard(
      () async {
        final orders = await _remote.fetchMyOrders();
        return sortUserDeliveryOrders(orders);
      },
      context: BackendErrorContext.deliveryOrders,
    );
  }

  @override
  Future<Result<DeliveryOrder>> getOrderDetail(String orderId) {
    return _guard(
      () => _remote.getOrderDetail(orderId),
      context: BackendErrorContext.deliveryDetail,
    );
  }

  @override
  Future<Result<DeliveryOrder>> cancelOrder(String orderId) {
    return _guard(
      () => _remote.cancelOrder(orderId),
      context: BackendErrorContext.deliveryCancel,
    );
  }

  Future<Result<T>> _guard<T>(
    Future<T> Function() action, {
    required BackendErrorContext context,
  }) async {
    try {
      return Success(await action());
    } on Failure catch (failure) {
      return Err(mapBackendError(failure, context: context));
    } catch (error) {
      return Err(
        mapBackendError(
          error,
          context: context,
          debugTag: 'DELIVERY_REPO_ERROR',
        ),
      );
    }
  }
}
