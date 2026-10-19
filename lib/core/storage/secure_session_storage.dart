import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/models/auth_session_model.dart';

/// Abstraction so tests can use in-memory storage without platform channels.
abstract class SessionStorage {
  Future<void> saveSession(AuthSessionModel session);
  Future<AuthSessionModel?> readSession();
  Future<void> clearSession();
}

/// Persists auth session securely. Never stores secret codes.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
            aOptions: AndroidOptions(
              encryptedSharedPreferences: true,
            ),
          );

  static const _sessionKey = 'hather_auth_session';
  static const _fallbackKey = 'hather_auth_session_fallback';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    final encoded = jsonEncode(session.toJson());
    try {
      await _storage.write(key: _sessionKey, value: encoded);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('SecureSessionStorage write warning: $error');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fallbackKey, encoded);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('SecureSessionStorage fallback write warning: $error');
      }
    }
  }

  @override
  Future<AuthSessionModel?> readSession() async {
    String? raw;
    try {
      raw = await _storage.read(key: _sessionKey);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('SecureSessionStorage read warning: $error');
      }
    }

    if (raw == null || raw.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_fallbackKey);
      } on Object catch (error) {
        if (kDebugMode) {
          debugPrint('SecureSessionStorage fallback read warning: $error');
        }
      }
    }

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
    try {
      await _storage.delete(key: _sessionKey);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('SecureSessionStorage delete warning: $error');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackKey);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('SecureSessionStorage fallback delete warning: $error');
      }
    }
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
