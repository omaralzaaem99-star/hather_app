import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/utils/phone_auth_identifier.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';

void main() {
  group('PhoneAuthIdentifier', () {
    test('detects legacy internal email', () {
      expect(
        PhoneAuthIdentifier.isInternalEmail('9647901234567@hather.local'),
        isTrue,
      );
      expect(PhoneAuthIdentifier.isInternalEmail('user@gmail.com'), isFalse);
    });

    test('sanitizes legacy internal email from user messages', () {
      final cleaned = PhoneAuthIdentifier.sanitizeUserMessage(
        'User already registered: 9647901234567@hather.local',
      );
      expect(cleaned.contains('@hather.local'), isFalse);
      expect(cleaned.contains('رقم الهاتف'), isTrue);
    });

    test('phone normalize still produces E.164 for auth', () {
      expect(
        PhoneNumberFormatter.normalizeToE164('07568887222'),
        '+9647568887222',
      );
    });
  });
}
