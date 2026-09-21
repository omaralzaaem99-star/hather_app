import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/features/support/data/support_repository.dart';
import 'package:hather_app/features/support/domain/entities/support_faq.dart';
import 'package:hather_app/features/support/domain/entities/support_form.dart';
import 'package:hather_app/features/support/domain/entities/support_request.dart';
import 'package:hather_app/features/support/domain/entities/support_settings.dart';

final supportRemoteDataSourceProvider = Provider<SupportRemoteDataSource>((ref) {
  if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) {
    return FakeSupportRemoteDataSource();
  }
  return SupabaseSupportRemoteDataSource();
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(
    remote: ref.watch(supportRemoteDataSourceProvider),
  );
});

final supportSettingsProvider = FutureProvider<SupportSettings>((ref) async {
  final result =
      await ref.watch(supportRepositoryProvider).getSupportSettings();
  return result.when(
    success: (value) => value,
    onFailure: (_) => SupportSettings.empty(),
  );
});

final supportFaqsProvider = FutureProvider<List<SupportFaq>>((ref) async {
  final result = await ref.watch(supportRepositoryProvider).getFaqs();
  return result.when(
    success: (value) => value,
    onFailure: (_) => const [],
  );
});

final supportFormsProvider =
    FutureProvider<List<SupportFormSummary>>((ref) async {
  final result = await ref.watch(supportRepositoryProvider).getForms();
  return result.when(
    success: (value) => value,
    onFailure: (_) => const [],
  );
});

final mySupportRequestsProvider =
    FutureProvider<List<SupportRequestSummary>>((ref) async {
  final result = await ref.watch(supportRepositoryProvider).getMyRequests();
  return result.when(
    success: (value) => value,
    onFailure: (_) => const [],
  );
});

final mySupportRequestDetailProvider =
    FutureProvider.family<SupportRequestDetail, String>((ref, requestId) async {
  final result = await ref
      .watch(supportRepositoryProvider)
      .getMyRequestDetail(requestId);
  return result.when(
    success: (value) => value,
    onFailure: (_) => SupportRequestDetail(
      id: requestId,
      requestNumber: 0,
      formTitle: '',
      status: SupportRequestStatus.newRequest,
      answers: const [],
    ),
  );
});

final supportFormDetailProvider =
    FutureProvider.family<SupportFormDetail, String>((ref, formId) async {
  final result =
      await ref.watch(supportRepositoryProvider).getFormDetail(formId);
  return result.when(
    success: (value) => value,
    onFailure: (_) => SupportFormDetail(id: formId, title: '', fields: const []),
  );
});
