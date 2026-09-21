import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/legal/data/legal_document_cache.dart';
import 'package:hather_app/features/legal/domain/entities/legal_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class LegalRemoteDataSource {
  Future<LegalDocument?> fetchPublished(LegalDocumentType type);
}

class SupabaseLegalRemoteDataSource implements LegalRemoteDataSource {
  SupabaseLegalRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<LegalDocument?> fetchPublished(LegalDocumentType type) async {
    try {
      final row = await _client.rpc(
        'get_legal_document',
        params: {'p_document_type': type.apiValue},
      );
      if (row == null) return null;
      final map = row is Map<String, dynamic>
          ? row
          : row is Map
              ? Map<String, dynamic>.from(row)
              : null;
      if (map == null) return null;
      final doc = LegalDocument.fromJson(map, fallbackType: type);
      return doc.hasContent ? doc : null;
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.generic,
        debugTag: 'LEGAL_BACKEND_ERROR',
      );
    }
  }
}

class FakeLegalRemoteDataSource implements LegalRemoteDataSource {
  @override
  Future<LegalDocument?> fetchPublished(LegalDocumentType type) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final title = type == LegalDocumentType.privacyPolicy
        ? 'سياسة الخصوصية'
        : 'شروط الاستخدام';
    return LegalDocument(
      documentType: type,
      title: title,
      content: '# $title\n\nنسخة تجريبية محلية للمحتوى القانوني.',
      contentFormat: 'markdown',
      isPublished: true,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

class LegalRepository {
  LegalRepository({
    required LegalRemoteDataSource remote,
    LegalDocumentCache? cache,
  })  : _remote = remote,
        _cache = cache ?? LegalDocumentCache();

  final LegalRemoteDataSource _remote;
  final LegalDocumentCache _cache;

  /// Prefers network; falls back to cache on failure / empty remote.
  Future<Result<LegalDocument>> getPublishedDocument(
    LegalDocumentType type,
  ) async {
    try {
      final remote = await _remote.fetchPublished(type);
      if (remote != null && remote.hasContent) {
        await _cache.save(remote);
        return Success(remote);
      }
      final cached = await _cache.read(type);
      if (cached != null) return Success(cached);
      return const Err(
        ServerFailure(message: 'المحتوى غير متوفر حالياً'),
      );
    } on Failure catch (failure) {
      final cached = await _cache.read(type);
      if (cached != null) return Success(cached);
      return Err(failure);
    } on Object {
      final cached = await _cache.read(type);
      if (cached != null) return Success(cached);
      return const Err(
        NetworkFailure(
          message: 'تعذر تحميل المحتوى حالياً. يرجى المحاولة مرة أخرى.',
        ),
      );
    }
  }
}
