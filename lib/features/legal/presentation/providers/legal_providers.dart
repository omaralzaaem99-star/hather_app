import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../data/legal_repository.dart';
import '../../domain/entities/legal_document.dart';

final legalRemoteDataSourceProvider = Provider<LegalRemoteDataSource>((ref) {
  if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) {
    return FakeLegalRemoteDataSource();
  }
  return SupabaseLegalRemoteDataSource();
});

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository(remote: ref.watch(legalRemoteDataSourceProvider));
});

final legalDocumentProvider =
    FutureProvider.family<LegalDocument, LegalDocumentType>((ref, type) async {
      final result = await ref
          .watch(legalRepositoryProvider)
          .getPublishedDocument(type);
      return result.when(
        success: (doc) => doc,
        onFailure: (failure) => throw failure,
      );
    });
