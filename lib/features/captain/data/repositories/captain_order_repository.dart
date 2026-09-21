import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/captain/data/datasources/captain_order_remote_datasource.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:hather_app/features/captain/presentation/utils/captain_available_orders_sort.dart';

class CaptainOrderRepository {
  CaptainOrderRepository({required CaptainOrderRemoteDataSource remote})
      : _remote = remote;

  final CaptainOrderRemoteDataSource _remote;

  Future<Result<List<CaptainAvailableOrder>>> getAvailableOrders() async {
    try {
      final orders = await _remote.fetchAvailableOrders();
      return Success(sortCaptainAvailableOrders(orders));
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  Future<Result<List<CaptainMyOrder>>> getMyOrders() async {
    try {
      final orders = await _remote.fetchMyOrders();
      return Success(orders);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  Future<Result<CaptainActiveOrderCapacity>> getActiveOrderCapacity() async {
    try {
      final capacity = await _remote.fetchActiveOrderCapacity();
      return Success(capacity);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  Future<Result<CaptainOrderDetail>> acceptOrder(String orderId) async {
    try {
      final detail = await _remote.acceptOrder(orderId);
      return Success(detail);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  Future<Result<CaptainOrderDetail>> completeOrder(String orderId) async {
    try {
      final detail = await _remote.completeOrder(orderId);
      return Success(detail);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  Future<Result<CaptainOrderDetail>> getMyOrderDetail(String orderId) async {
    try {
      final detail = await _remote.fetchMyOrderDetail(orderId);
      return Success(detail);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  Future<Result<bool>> reportCustomerNoAnswer(String orderId) async {
    try {
      await _remote.reportCustomerNoAnswer(orderId);
      return const Success(true);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  Future<Result<bool>> transferOrder({
    required String orderId,
    required String reason,
  }) async {
    try {
      await _remote.transferOrder(orderId: orderId, reason: reason);
      return const Success(true);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }
}

CaptainOrderRemoteDataSource createCaptainOrderRemoteDataSource() {
  if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) {
    return FakeCaptainOrderRemoteDataSource();
  }
  return SupabaseCaptainOrderRemoteDataSource();
}
