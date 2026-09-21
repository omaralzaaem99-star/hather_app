import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/features/legal/data/legal_repository.dart';
import 'package:hather_app/features/legal/domain/entities/legal_document.dart';

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
  final result =
      await ref.watch(legalRepositoryProvider).getPublishedDocument(type);
  return result.when(
    success: (doc) => doc,
    onFailure: (failure) => throw failure,
  );
});
