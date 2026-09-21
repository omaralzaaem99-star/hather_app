import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Persists a stable per-installation identifier for push device registration.
class PushInstallationStorage {
  PushInstallationStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'hather_push_installation_id';

  final FlutterSecureStorage _storage;
  String? _cached;

  Future<String> getOrCreate() async {
    final existing = _cached ?? await _storage.read(key: _key);
    if (existing != null && existing.trim().isNotEmpty) {
      _cached = existing.trim();
      return _cached!;
    }

    final created = const Uuid().v4();
    await _storage.write(key: _key, value: created);
    _cached = created;
    return created;
  }
}
