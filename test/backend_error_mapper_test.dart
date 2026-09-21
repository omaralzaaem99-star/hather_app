import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('hides missing RPC / migration guidance from users', () {
    final failure = mapBackendError(
      const PostgrestException(
        message: 'Could not find the function public.create_own_delivery_order',
        code: 'PGRST202',
      ),
      context: BackendErrorContext.deliverySettings,
      debugTag: 'DELIVERY_SETTINGS_LOAD_FAILED',
    );

    expect(failure, isA<ServerFailure>());
    final message = (failure as ServerFailure).message ?? '';
    expect(message, 'تعذر تحميل إعدادات الطلب حالياً. حاول مرة أخرى.');
    expect(message.toLowerCase(), isNot(contains('sql')));
    expect(message.toLowerCase(), isNot(contains('supabase')));
    expect(message, isNot(contains('027')));
    expect(message, isNot(contains('028')));
  });

  test('maps submit failures to generic Arabic copy', () {
    final failure = mapBackendError(
      const PostgrestException(
        message: 'column request_number does not exist',
        code: '42703',
      ),
      context: BackendErrorContext.deliverySubmit,
      debugTag: 'DELIVERY_ORDER_CREATE_FAILED',
    );

    expect(
      (failure as ServerFailure).message,
      'تعذر إرسال الطلب. حاول مرة أخرى.',
    );
  });

  test('keeps Arabic business messages for captains', () {
    final failure = mapBackendError(
      const PostgrestException(
        message: 'تم قبول هذا الطلب من كابتن آخر',
        code: 'P0001',
      ),
      context: BackendErrorContext.captainOrder,
    );

    expect(
      (failure as ServerFailure).message,
      contains('كابتن آخر'),
    );
  });

  test('detects technical UI messages', () {
    expect(
      isTechnicalUserMessage(
        'إعدادات قاعدة البيانات غير مكتملة. طبّق ملف SQL رقم 027 ثم 028 على Supabase.',
      ),
      isTrue,
    );
  });
}
