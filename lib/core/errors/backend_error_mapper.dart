import 'package:flutter/foundation.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User-facing error contexts for backend/Postgres/Supabase failures.
enum BackendErrorContext {
  deliverySettings,
  deliverySubmit,
  deliveryCoupon,
  deliveryOrders,
  deliveryDetail,
  deliveryCancel,
  captainOrder,
  support,
  notifications,
  generic,
}

/// Maps backend exceptions to safe Arabic [Failure] messages for production UI.
///
/// Technical details are logged via [debugPrint] only — never returned for widgets.
Failure mapBackendError(
  Object error, {
  required BackendErrorContext context,
  String debugTag = 'BACKEND_ERROR',
}) {
  if (error is Failure) {
    return _sanitizeFailure(error, context: context);
  }

  if (error is PostgrestException) {
    _logPostgrest(debugTag, error);
    return _fromPostgrest(error, context: context);
  }

  final raw = error.toString();
  _logRaw(debugTag, raw);

  if (_looksLikeNetwork(raw)) {
    return NetworkFailure(message: userMessageFor(context, network: true));
  }

  return ServerFailure(message: userMessageFor(context));
}

/// Safe Arabic copy for a given context (and optional network variant).
String userMessageFor(BackendErrorContext context, {bool network = false}) {
  if (network) {
    return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
  }
  return switch (context) {
    BackendErrorContext.deliverySettings =>
      'تعذر تحميل إعدادات الطلب حالياً. حاول مرة أخرى.',
    BackendErrorContext.deliverySubmit =>
      'تعذر إرسال الطلب. حاول مرة أخرى.',
    BackendErrorContext.deliveryCoupon => 'كوبون غير صالح',
    BackendErrorContext.deliveryOrders =>
      'تعذر تحميل الطلبات. حاول مرة أخرى.',
    BackendErrorContext.deliveryDetail =>
      'تعذر تحميل تفاصيل الطلب. حاول مرة أخرى.',
    BackendErrorContext.deliveryCancel =>
      'تعذر إلغاء الطلب. حاول مرة أخرى.',
    BackendErrorContext.captainOrder =>
      'تعذر إكمال العملية. حاول مرة أخرى.',
    BackendErrorContext.support =>
      'تعذر إكمال طلب الدعم. حاول مرة أخرى.',
    BackendErrorContext.notifications =>
      'تعذر تحميل الإشعارات. حاول مرة أخرى.',
    BackendErrorContext.generic => 'حدث خطأ، حاول مرة أخرى.',
  };
}

/// Returns true when [message] must never be shown in production UI.
bool isTechnicalUserMessage(String? message) {
  if (message == null) return false;
  final value = message.trim();
  if (value.isEmpty) return false;

  final lower = value.toLowerCase();
  const technicalTokens = <String>[
    'supabase',
    'postgres',
    'postgresql',
    'postgrest',
    'pgrst',
    'schema cache',
    'schema_cache',
    'migration',
    'rpc',
    'sql',
    '.sql',
    'stack trace',
    'exception',
    'socketexception',
    'failed host lookup',
    'could not find the function',
    'does not exist',
    'undefined column',
    'permission denied for',
    'relation "',
    'column "',
    'function public.',
    'create_own_delivery_order',
    'get_delivery_order_settings',
    'validate_delivery_coupon',
    'request_number',
    'order_type',
    'jwt',
    'bearer',
    'api key',
    'apikey',
    'طبّق ملف',
    'طبق ملف',
    'ملف sql',
  ];
  for (final token in technicalTokens) {
    if (lower.contains(token)) return true;
  }

  // Migration numbers / internal paths leaking into UI
  if (RegExp(r'\b0?\d{2,3}_[a-z0-9_]+\.sql\b', caseSensitive: false)
      .hasMatch(value)) {
    return true;
  }
  if (RegExp(r'رقم\s*0?\d{2,3}').hasMatch(value)) return true;

  return _looksMostlyEnglish(value);
}

/// Strips technical ServerFailure messages when mapping for UI.
String sanitizeFailureMessage(
  String? message, {
  required BackendErrorContext context,
  bool isNetwork = false,
}) {
  if (message == null || message.trim().isEmpty) {
    return userMessageFor(context, network: isNetwork);
  }
  if (isTechnicalUserMessage(message)) {
    return userMessageFor(context, network: isNetwork);
  }
  return message.trim();
}

Failure _sanitizeFailure(
  Failure failure, {
  required BackendErrorContext context,
}) {
  if (failure is NetworkFailure) {
    return NetworkFailure(
      message: sanitizeFailureMessage(
        failure.message,
        context: context,
        isNetwork: true,
      ),
    );
  }
  if (failure is ValidationFailure) {
    final msg = failure.message?.trim();
    if (msg == null || msg.isEmpty || isTechnicalUserMessage(msg)) {
      return ValidationFailure(message: userMessageFor(context));
    }
    return failure;
  }
  if (failure is UnauthorizedFailure) {
    final msg = failure.message?.trim();
    if (msg == null || msg.isEmpty || isTechnicalUserMessage(msg)) {
      return const UnauthorizedFailure(message: 'غير مصرح بهذه العملية');
    }
    return failure;
  }

  final msg = failure.message;
  if (msg == null || msg.isEmpty || isTechnicalUserMessage(msg)) {
    return ServerFailure(message: userMessageFor(context));
  }
  return ServerFailure(message: msg.trim());
}

Failure _fromPostgrest(
  PostgrestException error, {
  required BackendErrorContext context,
}) {
  final message = error.message.trim();
  final details = (error.details?.toString() ?? '').trim();
  final hint = (error.hint ?? '').trim();
  final combined = '$message $details $hint';

  if (_looksLikeNetwork(combined)) {
    return NetworkFailure(message: userMessageFor(context, network: true));
  }

  // Allow known Arabic business messages from RPCs (never English/tech).
  for (final candidate in [message, details]) {
    if (candidate.isEmpty) continue;
    if (!isTechnicalUserMessage(candidate) && _hasArabic(candidate)) {
      return ServerFailure(message: candidate);
    }
  }

  return ServerFailure(message: userMessageFor(context));
}

void _logPostgrest(String tag, PostgrestException error) {
  if (!kDebugMode) return;
  debugPrint(
    '$tag code=${error.code} message=${error.message} '
    'details=${error.details} hint=${error.hint}',
  );
}

void _logRaw(String tag, String raw) {
  if (!kDebugMode) return;
  final safe = raw
      .replaceAll(RegExp(r'(bearer\s+)[^\s]+', caseSensitive: false), r'$1***')
      .replaceAll(
        RegExp(r'(api[_-]?key|token|password|secret|otp)\s*[:=]\s*\S+',
            caseSensitive: false),
        '***',
      );
  debugPrint('$tag message=$safe');
}

bool _looksLikeNetwork(String value) {
  final lower = value.toLowerCase();
  return lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      (lower.contains('network') && lower.contains('error'));
}

bool _hasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);

bool _looksMostlyEnglish(String value) {
  final letters = value.replaceAll(RegExp(r'[^A-Za-z\u0600-\u06FF]'), '');
  if (letters.length < 8) return false;
  final english = value.replaceAll(RegExp(r'[^A-Za-z]'), '');
  return english.length >= 8 && english.length >= (letters.length * 0.6);
}
