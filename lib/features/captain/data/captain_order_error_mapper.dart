import 'package:flutter/foundation.dart';
import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps captain order RPC errors to user-facing Arabic [Failure] messages.
Failure mapCaptainOrderError(Object error) {
  if (error is Failure) {
    return mapBackendError(error, context: BackendErrorContext.captainOrder);
  }

  if (error is PostgrestException) {
    final message = error.message.trim();
    if (kDebugMode) {
      debugPrint(
        'CAPTAIN_ORDER_ERROR code=${error.code} message=$message '
        'details=${error.details}',
      );
    }

    if (message.contains('تم إكمال الطلب مسبقاً')) {
      return const ServerFailure(message: 'تم إكمال الطلب مسبقاً');
    }
    if (message.contains('هذا الطلب لم يعد جارياً')) {
      return const ServerFailure(message: 'هذا الطلب لم يعد جارياً');
    }
    if (message.contains('لا يمكنك إكمال هذا الطلب') ||
        message.contains('captain only') ||
        message.contains('not authenticated') ||
        message.contains('captain account not active') ||
        message.contains('profile not found')) {
      return const ServerFailure(message: 'لا يمكنك إكمال هذا الطلب');
    }
    if (message.contains('تم قبول هذا الطلب من كابتن آخر')) {
      return ServerFailure(message: message);
    }
    if (message.contains('انتهت صلاحية هذا الطلب')) {
      return ServerFailure(message: message);
    }
    if (message.contains('الطلب لم يعد متاحاً')) {
      return ServerFailure(message: message);
    }
    if (message.contains('اشتراكك غير فعال')) {
      return ServerFailure(message: message);
    }
    if (message.contains('الحد الأقصى من الطلبات قيد التنفيذ')) {
      return ServerFailure(message: message);
    }
    if (message.contains('لا يمكنك تحويل هذا الطلب') ||
        message.contains('لا يمكن تحويل طلب') ||
        message.contains('تعذر تحويل الطلب') ||
        message.contains('يجب اختيار سبب التحويل') ||
        message.contains('سبب التحويل طويل') ||
        message.contains('ولا يمكن تحويله')) {
      return ServerFailure(message: message);
    }
    if (message.contains('لا يمكنك تنفيذ هذا الإجراء')) {
      return ServerFailure(message: message);
    }
  }

  return mapBackendError(
    error,
    context: BackendErrorContext.captainOrder,
    debugTag: 'CAPTAIN_ORDER_ERROR',
  );
}

void logCaptainOrderEvent(String event, {String? detail}) {
  if (!kDebugMode) return;
  debugPrint(event);
  if (detail == null || detail.isEmpty) return;
  if (isTechnicalUserMessage(detail)) {
    debugPrint('CAPTAIN_ORDER_DETAIL_REDACTED');
    return;
  }
  debugPrint(detail);
}
