import 'package:hather_app/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PushDeviceRepository {
  PushDeviceRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isEnabled =>
      !AppConfig.useFakeAuth && AppConfig.hasSupabaseConfig;

  SupabaseClient get client {
    final value = _client;
    if (value != null) return value;
    return Supabase.instance.client;
  }

  Future<void> upsertMyDevice({
    required String installationId,
    required String fcmToken,
    required String platform,
  }) async {
    if (!isEnabled) {
      throw StateError('push sync disabled');
    }
    if (client.auth.currentUser == null) {
      throw StateError('not authenticated');
    }
    if (!_isValidInstallationId(installationId)) {
      throw ArgumentError('invalid installation id');
    }

    final token = fcmToken.trim();
    if (token.isEmpty) {
      throw ArgumentError('empty fcm token');
    }

    await client.rpc(
      'upsert_my_push_device',
      params: {
        'p_installation_id': installationId,
        'p_fcm_token': token,
        'p_platform': platform,
      },
    );
  }

  Future<void> deactivateMyDevice(String installationId) async {
    if (!isEnabled) return;
    if (client.auth.currentUser == null) return;
    if (!_isValidInstallationId(installationId)) return;

    await client.rpc(
      'deactivate_my_push_device',
      params: {'p_installation_id': installationId},
    );
  }

  static bool _isValidInstallationId(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && Uuid.isValidUUID(fromString: trimmed);
  }
}

String sanitizePushSyncError(Object error) {
  if (error is PostgrestException) {
    final code = error.code?.trim();
    if (code == '42501') return 'not authenticated';
    if (code == '22023') return 'invalid parameters';
    if (code != null && code.isNotEmpty) return 'rpc error ($code)';
    return 'rpc error';
  }
  if (error is StateError) {
    return error.message;
  }
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'invalid argument';
  }
  return error.runtimeType.toString();
}
