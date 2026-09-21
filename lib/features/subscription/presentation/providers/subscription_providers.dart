import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/subscription/data/subscription_repository.dart';
import 'package:hather_app/features/subscription/domain/entities/captain_subscription_info.dart';

final subscriptionRemoteDataSourceProvider =
    Provider<SubscriptionRemoteDataSource>((ref) {
  if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) {
    return FakeSubscriptionRemoteDataSource();
  }
  return SupabaseSubscriptionRemoteDataSource();
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(
    remote: ref.watch(subscriptionRemoteDataSourceProvider),
  );
});

/// Loads the signed-in captain's subscription (server-derived active check).
final myCaptainSubscriptionProvider =
    FutureProvider<CaptainSubscriptionInfo>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null || user.accountType != AccountType.captain) {
    return CaptainSubscriptionInfo.none();
  }

  final result =
      await ref.watch(subscriptionRepositoryProvider).getMyCaptainSubscription();
  return result.when(
    success: (value) => value,
    onFailure: (_) => CaptainSubscriptionInfo.none(),
  );
});
