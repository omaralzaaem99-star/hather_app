import 'package:shared_preferences/shared_preferences.dart';

/// Persists dismissed expired-order dialog keys per [orderId] across sessions.
class HandledExpiredOrderStorage {
  HandledExpiredOrderStorage({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _key = 'hather_handled_expired_order_ids';
  static const _maxEntries = 200;

  final SharedPreferences? _preferences;

  Future<Set<String>> readAll() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null || raw.isEmpty) return {};
    return raw.toSet();
  }

  Future<void> add(String orderId) async {
    final trimmed = orderId.trim();
    if (trimmed.isEmpty) return;

    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? <String>[];
    if (existing.contains(trimmed)) return;

    final updated = [...existing, trimmed];
    final capped = updated.length <= _maxEntries
        ? updated
        : updated.sublist(updated.length - _maxEntries);
    await prefs.setStringList(_key, capped);
  }
}
