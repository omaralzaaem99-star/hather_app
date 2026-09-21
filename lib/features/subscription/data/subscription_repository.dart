import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/subscription/domain/entities/captain_subscription_info.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SubscriptionRemoteDataSource {
  Future<CaptainSubscriptionInfo> fetchMyCaptainSubscription();
}

class SupabaseSubscriptionRemoteDataSource
    implements SubscriptionRemoteDataSource {
  SupabaseSubscriptionRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<CaptainSubscriptionInfo> fetchMyCaptainSubscription() async {
    try {
      final row = await _client.rpc('get_my_captain_subscription');
      if (row is Map<String, dynamic>) {
        return CaptainSubscriptionInfo.fromJson(row);
      }
      if (row is Map) {
        return CaptainSubscriptionInfo.fromJson(
          Map<String, dynamic>.from(row),
        );
      }
      return CaptainSubscriptionInfo.none();
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.generic,
        debugTag: 'SUBSCRIPTION_LOAD_FAILED',
      );
    }
  }
}

class FakeSubscriptionRemoteDataSource implements SubscriptionRemoteDataSource {
  @override
  Future<CaptainSubscriptionInfo> fetchMyCaptainSubscription() async {
    return CaptainSubscriptionInfo.none();
  }
}

class SubscriptionRepository {
  SubscriptionRepository({required SubscriptionRemoteDataSource remote})
      : _remote = remote;

  final SubscriptionRemoteDataSource _remote;

  Future<Result<CaptainSubscriptionInfo>> getMyCaptainSubscription() async {
    try {
      final info = await _remote.fetchMyCaptainSubscription();
      return Success(info);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }
}
