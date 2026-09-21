import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hather_app/features/legal/domain/entities/legal_document.dart';

/// Persists last successful legal document fetch for offline reading.
class LegalDocumentCache {
  LegalDocumentCache({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static String _key(LegalDocumentType type) =>
      'hather_legal_document_${type.apiValue}';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> save(LegalDocument document) async {
    if (!document.hasContent) return;
    final prefs = await _ensurePrefs();
    await prefs.setString(_key(document.documentType), jsonEncode(document.toCacheJson()));
  }

  Future<LegalDocument?> read(LegalDocumentType type) async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_key(type));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final doc = LegalDocument.fromJson(
        Map<String, dynamic>.from(map),
        fallbackType: type,
      );
      return doc.hasContent ? doc : null;
    } on Object {
      return null;
    }
  }
}
