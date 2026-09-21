/// Legal document types stored in Supabase `legal_documents.document_type`.
enum LegalDocumentType {
  privacyPolicy('privacy_policy'),
  termsOfUse('terms_of_use');

  const LegalDocumentType(this.apiValue);
  final String apiValue;
}

class LegalDocument {
  const LegalDocument({
    required this.documentType,
    required this.title,
    required this.content,
    required this.contentFormat,
    required this.isPublished,
    this.id,
    this.updatedAt,
  });

  final String? id;
  final LegalDocumentType documentType;
  final String title;
  final String content;
  final String contentFormat;
  final bool isPublished;
  final DateTime? updatedAt;

  bool get hasContent => content.trim().isNotEmpty;

  factory LegalDocument.fromJson(
    Map<String, dynamic> json, {
    required LegalDocumentType fallbackType,
  }) {
    final typeRaw = (json['document_type'] as String?)?.trim();
    final type = LegalDocumentType.values.firstWhere(
      (t) => t.apiValue == typeRaw,
      orElse: () => fallbackType,
    );
    DateTime? updatedAt;
    final updatedRaw = json['updated_at'];
    if (updatedRaw is String && updatedRaw.isNotEmpty) {
      updatedAt = DateTime.tryParse(updatedRaw);
    }
    return LegalDocument(
      id: json['id']?.toString(),
      documentType: type,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : fallbackType == LegalDocumentType.privacyPolicy
              ? 'سياسة الخصوصية'
              : 'شروط الاستخدام',
      content: (json['content'] as String?) ?? '',
      contentFormat: (json['content_format'] as String?) ?? 'markdown',
      isPublished: json['is_published'] == true,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'document_type': documentType.apiValue,
        'title': title,
        'content': content,
        'content_format': contentFormat,
        'is_published': isPublished,
        'updated_at': updatedAt?.toIso8601String(),
      };
}
