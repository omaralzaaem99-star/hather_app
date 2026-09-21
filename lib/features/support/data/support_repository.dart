import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/support/domain/entities/support_faq.dart';
import 'package:hather_app/features/support/domain/entities/support_form.dart';
import 'package:hather_app/features/support/domain/entities/support_request.dart';
import 'package:hather_app/features/support/domain/entities/support_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SupportRemoteDataSource {
  Future<SupportSettings> fetchSupportSettings();
  Future<List<SupportFaq>> fetchFaqs();
  Future<List<SupportFormSummary>> fetchForms();
  Future<SupportFormDetail> fetchFormDetail(String formId);
  Future<List<SupportRequestSummary>> fetchMyRequests();
  Future<SupportRequestDetail> fetchMyRequestDetail(String requestId);
  Future<SupportSubmissionResult> submitForm({
    required String formId,
    required Map<String, String> answers,
  });
}

List<T> _parseList<T>(
  Object? raw,
  T Function(Map<String, dynamic> json) mapper,
) {
  if (raw is! List) return const [];
  final items = <T>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      items.add(mapper(item));
    } else if (item is Map) {
      items.add(mapper(Map<String, dynamic>.from(item)));
    }
  }
  return items;
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

class SupabaseSupportRemoteDataSource implements SupportRemoteDataSource {
  SupabaseSupportRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<SupportSettings> fetchSupportSettings() async {
    try {
      final row = await _client.rpc('get_support_settings');
      return SupportSettings.fromJson(_asMap(row));
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.support,
        debugTag: 'SUPPORT_BACKEND_ERROR',
      );
    }
  }

  @override
  Future<List<SupportFaq>> fetchFaqs() async {
    try {
      final row = await _client.rpc('get_support_faqs');
      return _parseList(row, SupportFaq.fromJson);
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.support,
        debugTag: 'SUPPORT_BACKEND_ERROR',
      );
    }
  }

  @override
  Future<List<SupportFormSummary>> fetchForms() async {
    try {
      final row = await _client.rpc('get_support_forms');
      return _parseList(row, SupportFormSummary.fromJson);
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.support,
        debugTag: 'SUPPORT_BACKEND_ERROR',
      );
    }
  }

  @override
  Future<SupportFormDetail> fetchFormDetail(String formId) async {
    try {
      final row = await _client.rpc(
        'get_support_form_detail',
        params: {'p_form_id': formId},
      );
      return SupportFormDetail.fromJson(_asMap(row));
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.support,
        debugTag: 'SUPPORT_BACKEND_ERROR',
      );
    }
  }

  @override
  Future<List<SupportRequestSummary>> fetchMyRequests() async {
    try {
      final row = await _client.rpc('my_support_requests');
      return _parseList(row, SupportRequestSummary.fromJson);
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.support,
        debugTag: 'SUPPORT_BACKEND_ERROR',
      );
    }
  }

  @override
  Future<SupportRequestDetail> fetchMyRequestDetail(String requestId) async {
    try {
      final row = await _client.rpc(
        'get_my_support_request_detail',
        params: {'p_id': requestId},
      );
      return SupportRequestDetail.fromJson(_asMap(row));
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.support,
        debugTag: 'SUPPORT_BACKEND_ERROR',
      );
    }
  }

  @override
  Future<SupportSubmissionResult> submitForm({
    required String formId,
    required Map<String, String> answers,
  }) async {
    try {
      final row = await _client.rpc(
        'submit_support_request',
        params: {
          'p_form_id': formId,
          'p_answers': answers,
        },
      );
      return SupportSubmissionResult.fromJson(_asMap(row));
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.support,
        debugTag: 'SUPPORT_BACKEND_ERROR',
      );
    }
  }
}

class FakeSupportRemoteDataSource implements SupportRemoteDataSource {
  @override
  Future<SupportSettings> fetchSupportSettings() async =>
      SupportSettings.empty();

  @override
  Future<List<SupportFaq>> fetchFaqs() async => const [];

  @override
  Future<List<SupportFormSummary>> fetchForms() async => const [];

  @override
  Future<SupportFormDetail> fetchFormDetail(String formId) async {
    return const SupportFormDetail(id: '', title: '', fields: []);
  }

  @override
  Future<List<SupportRequestSummary>> fetchMyRequests() async => const [];

  @override
  Future<SupportRequestDetail> fetchMyRequestDetail(String requestId) async {
    return SupportRequestDetail(
      id: requestId,
      requestNumber: 1,
      formTitle: 'Demo',
      status: SupportRequestStatus.inProgress,
      answers: const [
        SupportRequestAnswer(
          label: 'رقم الطلب',
          fieldKey: 'order_id',
          value: '12345',
        ),
      ],
      adminReply: 'تمت مراجعة المشكلة وسنتابع الطلب.',
      repliedAt: DateTime.utc(2026, 8, 22, 15, 40),
      createdAt: DateTime.utc(2026, 8, 22, 14, 0),
    );
  }

  @override
  Future<SupportSubmissionResult> submitForm({
    required String formId,
    required Map<String, String> answers,
  }) async {
    return const SupportSubmissionResult(
      id: 'fake',
      requestNumber: 1,
      formTitle: 'Demo',
      status: SupportRequestStatus.newRequest,
    );
  }
}

class SupportRepository {
  SupportRepository({required SupportRemoteDataSource remote}) : _remote = remote;

  final SupportRemoteDataSource _remote;

  Future<Result<SupportSettings>> getSupportSettings() =>
      _wrap(() => _remote.fetchSupportSettings());

  Future<Result<List<SupportFaq>>> getFaqs() =>
      _wrap(() => _remote.fetchFaqs());

  Future<Result<List<SupportFormSummary>>> getForms() =>
      _wrap(() => _remote.fetchForms());

  Future<Result<SupportFormDetail>> getFormDetail(String formId) =>
      _wrap(() => _remote.fetchFormDetail(formId));

  Future<Result<List<SupportRequestSummary>>> getMyRequests() =>
      _wrap(() => _remote.fetchMyRequests());

  Future<Result<SupportRequestDetail>> getMyRequestDetail(String requestId) =>
      _wrap(() => _remote.fetchMyRequestDetail(requestId));

  Future<Result<SupportSubmissionResult>> submitForm({
    required String formId,
    required Map<String, String> answers,
  }) =>
      _wrap(() => _remote.submitForm(formId: formId, answers: answers));

  Future<Result<T>> _wrap<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }
}
