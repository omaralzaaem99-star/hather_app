import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application runtime configuration.
///
/// Priority:
/// 1. Non-empty `--dart-define` value
/// 2. Otherwise value from loaded `.env` (via flutter_dotenv)
///
/// Never read dotenv outside this class. Never store service_role / OTPIQ here.
class AppConfig {
  const AppConfig._();

  static const String _urlFromDefine = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _publishableFromDefine = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String _anonFromDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String _useFakeFromDefine = String.fromEnvironment(
    'USE_FAKE_AUTH',
    defaultValue: '',
  );

  static String get supabaseUrl {
    if (_urlFromDefine.trim().isNotEmpty) {
      return _urlFromDefine.trim();
    }
    return _readEnv('SUPABASE_URL');
  }

  static String get supabasePublishableKey {
    if (_publishableFromDefine.trim().isNotEmpty) {
      return _publishableFromDefine.trim();
    }
    final fromEnv = _readEnv('SUPABASE_PUBLISHABLE_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (_anonFromDefine.trim().isNotEmpty) {
      return _anonFromDefine.trim();
    }
    return _readEnv('SUPABASE_ANON_KEY');
  }

  /// Alias kept for older call sites.
  static String get supabaseAnonKey => supabasePublishableKey;

  /// Fake auth is DEBUG/PROFILE only. Release always uses real Supabase Auth.
  /// Default when unset: false (real auth).
  ///
  /// Hard guarantee: even if `.env` or `--dart-define=USE_FAKE_AUTH=true`
  /// is present in a release artifact, this getter returns false.
  static bool get useFakeAuth {
    if (kReleaseMode) return false;

    if (_useFakeFromDefine.trim().isNotEmpty) {
      return _parseStrictBool(_useFakeFromDefine);
    }
    final fromEnv = _readEnv('USE_FAKE_AUTH');
    if (fromEnv.isNotEmpty) {
      return _parseStrictBool(fromEnv);
    }
    return false;
  }

  /// True only when fake OTP / fake auth UI may be shown (never in release).
  static bool get showDevAuthUi => !kReleaseMode && useFakeAuth;

  static const int otpLength = 6;
  static const int otpResendSeconds = 60;
  static const int otpExpirySeconds = 300;
  static const int minSecretCodeLength = 6;
  static const String iraqCountryCode = '+964';

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Call after [dotenv.load]. Does not print secret values.
  static void validate() {
    if (useFakeAuth) return;

    if (supabaseUrl.isEmpty) {
      throw StateError(
        'Real auth requires SUPABASE_URL '
        '(set in .env or --dart-define=SUPABASE_URL=...).',
      );
    }
    if (supabasePublishableKey.isEmpty) {
      throw StateError(
        'Real auth requires SUPABASE_PUBLISHABLE_KEY '
        '(set in .env or --dart-define=SUPABASE_PUBLISHABLE_KEY=...).',
      );
    }
  }

  static String _readEnv(String key) {
    try {
      return (dotenv.env[key] ?? '').trim();
    } on Object {
      return '';
    }
  }

  /// Only exact true/false (case-insensitive). Other text throws.
  static bool _parseStrictBool(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'true') return true;
    if (value == 'false') return false;
    throw StateError(
      'Invalid boolean for USE_FAKE_AUTH: expected true or false.',
    );
  }
}
