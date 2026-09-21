import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/features/auth/data/datasources/supabase_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('combined token expired/invalid maps to InvalidOtpFailure', () {
    const error = AuthException(
      'Token has expired or is invalid',
      statusCode: '401',
    );

    final failure = mapSupabaseError(error);

    expect(failure, isA<InvalidOtpFailure>());
  });

  test('token expired only maps to OtpExpiredFailure', () {
    const error = AuthException(
      'Token has expired',
      statusCode: '401',
    );

    final failure = mapSupabaseError(error);

    expect(failure, isA<OtpExpiredFailure>());
  });

  test('token invalid only maps to InvalidOtpFailure', () {
    const error = AuthException(
      'Token is invalid',
      statusCode: '401',
    );

    final failure = mapSupabaseError(error);

    expect(failure, isA<InvalidOtpFailure>());
  });
}
