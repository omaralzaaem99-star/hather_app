import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/core/utils/validators.dart';

void main() {
  group('PhoneNumberFormatter', () {
    test('normalizes local Iraqi mobile to E.164', () {
      expect(
        PhoneNumberFormatter.normalizeToE164('07901234567'),
        '+9647901234567',
      );
    });

    test('normalizes without leading zero', () {
      expect(
        PhoneNumberFormatter.normalizeToE164('7901234567'),
        '+9647901234567',
      );
    });

    test('converts Arabic digits', () {
      expect(
        PhoneNumberFormatter.normalizeToE164('٠٧٩٠١٢٣٤٥٦٧'),
        '+9647901234567',
      );
    });

    test('rejects invalid numbers', () {
      expect(PhoneNumberFormatter.normalizeToE164('123'), isNull);
      expect(PhoneNumberFormatter.normalizeToE164('05901234567'), isNull);
    });

    test('creates local display form', () {
      expect(
        PhoneNumberFormatter.toLocalDisplay('+9647901234567'),
        '07901234567',
      );
      expect(
        PhoneNumberFormatter.toLocalDisplay('9647806560098'),
        '07806560098',
      );
      expect(
        PhoneNumberFormatter.toLocalDisplay('+9647806560098'),
        '07806560098',
      );
    });
  });

  group('Validators', () {
    test('rejects empty full name', () {
      expect(
        Validators.validateFullName(''),
        FieldValidationError.fullNameRequired,
      );
    });

    test('rejects digits-only name', () {
      expect(
        Validators.validateFullName('12345'),
        FieldValidationError.fullNameDigitsOnly,
      );
    });

    test('rejects short secret code', () {
      expect(
        Validators.validateSecretCode('123'),
        FieldValidationError.secretCodeTooShort,
      );
    });

    test('rejects mismatched secret codes', () {
      expect(
        Validators.validateSecretCodeConfirmation(
          secretCode: '123456',
          confirmation: '654321',
        ),
        FieldValidationError.secretCodeMismatch,
      );
    });

    test('rejects incomplete otp', () {
      expect(Validators.validateOtp('123'), FieldValidationError.otpIncomplete);
    });

    test('accepts valid registration fields', () {
      expect(Validators.validateFullName('أحمد علي'), isNull);
      expect(Validators.validatePhone('07901234567'), isNull);
      expect(Validators.validateSecretCode('123456'), isNull);
      expect(
        Validators.validateSecretCodeConfirmation(
          secretCode: '123456',
          confirmation: '123456',
        ),
        isNull,
      );
      expect(Validators.validateOtp('654321'), isNull);
    });
  });
}
