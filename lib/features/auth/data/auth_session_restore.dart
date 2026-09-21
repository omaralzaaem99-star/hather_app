import 'package:supabase_flutter/supabase_flutter.dart';

bool isSupabaseAccessTokenExpired(Session session) {
  final expiresAt = session.expiresAt;
  if (expiresAt == null) return false;
  return DateTime.fromMillisecondsSinceEpoch(
    expiresAt * 1000,
    isUtc: true,
  ).isBefore(DateTime.now().toUtc());
}

bool isInvalidRefreshTokenError(AuthException error) {
  final message = error.message.toLowerCase();
  final status = error.statusCode ?? '';
  return status == '401' ||
      message.contains('invalid refresh token') ||
      message.contains('refresh token not found') ||
      message.contains('refresh_token') && message.contains('invalid') ||
      message.contains('session not found') ||
      message.contains('jwt expired') && message.contains('refresh');
}

bool isTransientAuthRestoreError(Object error) {
  if (error is AuthException && !isInvalidRefreshTokenError(error)) {
    final message = error.message.toLowerCase();
    if (message.contains('network') || message.contains('timeout')) {
      return true;
    }
  }
  final raw = error.toString().toLowerCase();
  return raw.contains('socket') ||
      raw.contains('network') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection') ||
      raw.contains('timeout');
}
