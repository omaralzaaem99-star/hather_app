import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/features/captain/data/datasources/captain_order_remote_datasource.dart';
import 'package:hather_app/features/captain/data/repositories/captain_order_repository.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';

final captainOrderRemoteDataSourceProvider =
    Provider<CaptainOrderRemoteDataSource>((ref) {
  return createCaptainOrderRemoteDataSource();
});

final captainOrderRepositoryProvider = Provider<CaptainOrderRepository>((ref) {
  return CaptainOrderRepository(
    remote: ref.watch(captainOrderRemoteDataSourceProvider),
  );
});

final captainAvailableOrdersProvider =
    FutureProvider<List<CaptainAvailableOrder>>((ref) async {
  final result =
      await ref.watch(captainOrderRepositoryProvider).getAvailableOrders();
  return result.when(
    success: (value) => value,
    onFailure: (_) => throw Exception('available orders failed'),
  );
});

final captainMyOrdersProvider = FutureProvider<List<CaptainMyOrder>>((ref) async {
  final result = await ref.watch(captainOrderRepositoryProvider).getMyOrders();
  return result.when(
    success: (value) => value,
    onFailure: (_) => throw Exception('my orders failed'),
  );
});

final captainActiveOrderCapacityProvider =
    FutureProvider<CaptainActiveOrderCapacity>((ref) async {
  final result = await ref
      .watch(captainOrderRepositoryProvider)
      .getActiveOrderCapacity();
  return result.when(
    success: (value) => value,
    onFailure: (_) => throw Exception('active order capacity failed'),
  );
});

void refreshCaptainOrders(WidgetRef ref) {
  ref.invalidate(captainAvailableOrdersProvider);
  ref.invalidate(captainMyOrdersProvider);
  ref.invalidate(captainActiveOrderCapacityProvider);
}
