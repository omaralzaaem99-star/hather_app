import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hather_app/features/auth/data/models/auth_session_model.dart';

/// Abstraction so tests can use in-memory storage without platform channels.
abstract class SessionStorage {
  Future<void> saveSession(AuthSessionModel session);
  Future<AuthSessionModel?> readSession();
  Future<void> clearSession();
}

/// Persists auth session securely. Never stores secret codes.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'hather_auth_session';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  @override
  Future<AuthSessionModel?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSessionModel.fromJson(map);
    } on Object {
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }
}

/// In-memory session storage for unit tests.
class InMemorySessionStorage implements SessionStorage {
  AuthSessionModel? _session;

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    _session = session;
  }

  @override
  Future<AuthSessionModel?> readSession() async => _session;

  @override
  Future<void> clearSession() async {
    _session = null;
  }
}
