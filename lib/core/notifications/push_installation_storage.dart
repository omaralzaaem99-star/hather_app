import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persists a stable per-installation identifier for push device registration.
class PushInstallationStorage {
  PushInstallationStorage({FlutterSecureStorage? storage})
    : _storage = storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
            aOptions: AndroidOptions(
              encryptedSharedPreferences: true,
            ),
          );

  static const _key = 'hather_push_installation_id';

  final FlutterSecureStorage _storage;
  String? _cached;

  Future<String> getOrCreate() async {
    if (_cached != null && _cached!.trim().isNotEmpty) {
      return _cached!;
    }

    String? existing;
    try {
      existing = await _storage.read(key: _key);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('PushInstallationStorage read warning: $error');
      }
    }

    if (existing == null || existing.trim().isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        existing = prefs.getString(_key);
      } on Object catch (error) {
        if (kDebugMode) {
          debugPrint('PushInstallationStorage fallback read warning: $error');
        }
      }
    }

    if (existing != null && existing.trim().isNotEmpty) {
      _cached = existing.trim();
      return _cached!;
    }

    final created = const Uuid().v4();
    try {
      await _storage.write(key: _key, value: created);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('PushInstallationStorage write warning: $error');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, created);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('PushInstallationStorage fallback write warning: $error');
      }
    }

    _cached = created;
    return created;
  }
}
