import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/auth/data/datasources/supabase_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isSignUpResponseParseFailure', () {
    test('detects format, type, and malformed GoTrue parse errors', () {
      expect(
        isSignUpResponseParseFailure(const FormatException('bad json')),
        isTrue,
      );
      expect(isSignUpResponseParseFailure(TypeError()), isTrue);
      expect(
        isSignUpResponseParseFailure(
          Exception('malformed GoTrue response body'),
        ),
        isTrue,
      );
      expect(
        isSignUpResponseParseFailure(
          const AuthException('User already registered'),
        ),
        isFalse,
      );
    });
  });
}
