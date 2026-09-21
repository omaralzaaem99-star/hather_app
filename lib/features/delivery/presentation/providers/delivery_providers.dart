import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/features/delivery/data/datasources/delivery_remote_datasource.dart';
import 'package:hather_app/features/delivery/data/datasources/fake_delivery_remote_datasource.dart';
import 'package:hather_app/features/delivery/data/datasources/supabase_delivery_remote_datasource.dart';
import 'package:hather_app/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/features/delivery/domain/repositories/delivery_repository.dart';

final deliveryRemoteDataSourceProvider = Provider<DeliveryRemoteDataSource>((
  ref,
) {
  if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) {
    return FakeDeliveryRemoteDataSource();
  }
  return SupabaseDeliveryRemoteDataSource();
});

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepositoryImpl(
    remote: ref.watch(deliveryRemoteDataSourceProvider),
  );
});

final orderDetailProvider =
    FutureProvider.family<DeliveryOrder?, String>((ref, orderId) async {
  final result =
      await ref.watch(deliveryRepositoryProvider).getOrderDetail(orderId);
  return result.when(
    success: (value) => value,
    onFailure: (_) => null,
  );
});

final orderTypesProvider = FutureProvider<List<OrderTypeOption>>((ref) async {
  final result = await ref.watch(deliveryRepositoryProvider).fetchOrderTypes();
  return result.when(
    success: (value) => value,
    onFailure: (_) => const [],
  );
});

final deliveryOrderSettingsProvider =
    FutureProvider<DeliveryOrderSettings>((ref) async {
  final result =
      await ref.watch(deliveryRepositoryProvider).fetchOrderSettings();
  return result.when(
    success: (value) => value,
    onFailure: (failure) {
      throw failure;
    },
  );
});

final homeAdsProvider = FutureProvider<List<HomeAd>>((ref) async {
  final result = await ref.watch(deliveryRepositoryProvider).fetchHomeAds();
  return result.when(
    success: (value) => value,
    onFailure: (_) => const [],
  );
});

final myOrdersProvider = FutureProvider<List<DeliveryOrder>>((ref) async {
  final result = await ref.watch(deliveryRepositoryProvider).fetchMyOrders();
  return result.when(
    success: (value) => value,
    onFailure: (_) => const [],
  );
});
