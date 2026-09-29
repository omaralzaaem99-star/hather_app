import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../data/datasources/delivery_remote_datasource.dart';
import '../../data/datasources/fake_delivery_remote_datasource.dart';
import '../../data/datasources/supabase_delivery_remote_datasource.dart';
import '../../data/repositories/delivery_repository_impl.dart';
import '../../domain/entities/delivery_entities.dart';
import '../../domain/repositories/delivery_repository.dart';

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

final orderDetailProvider = FutureProvider.family<DeliveryOrder?, String>((
  ref,
  orderId,
) async {
  final result = await ref
      .watch(deliveryRepositoryProvider)
      .getOrderDetail(orderId);
  return result.when(success: (value) => value, onFailure: (_) => null);
});

final orderTypesProvider = FutureProvider<List<OrderTypeOption>>((ref) async {
  final result = await ref.watch(deliveryRepositoryProvider).fetchOrderTypes();
  return result.when(success: (value) => value, onFailure: (_) => const []);
});

final deliveryOrderSettingsProvider = FutureProvider<DeliveryOrderSettings>((
  ref,
) async {
  final result = await ref
      .watch(deliveryRepositoryProvider)
      .fetchOrderSettings();
  return result.when(
    success: (value) => value,
    onFailure: (failure) {
      throw failure;
    },
  );
});

final homeAdsProvider = FutureProvider<List<HomeAd>>((ref) async {
  final result = await ref.watch(deliveryRepositoryProvider).fetchHomeAds();
  return result.when(success: (value) => value, onFailure: (_) => const []);
});

final myOrdersProvider = FutureProvider<List<DeliveryOrder>>((ref) async {
  final result = await ref.watch(deliveryRepositoryProvider).fetchMyOrders();
  return result.when(success: (value) => value, onFailure: (_) => const []);
});
