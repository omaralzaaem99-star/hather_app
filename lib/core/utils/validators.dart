import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';

/// Field-level validation helpers. Messages are Arabic keys resolved by UI/l10n.
enum FieldValidationError {
  fullNameRequired,
  fullNameTooShort,
  fullNameDigitsOnly,
  phoneRequired,
  phoneInvalid,
  secretCodeRequired,
  secretCodeTooShort,
  secretCodeMismatch,
  otpIncomplete,
}

class Validators {
  const Validators._();

  static String normalizeFullName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static FieldValidationError? validateFullName(String value) {
    final name = normalizeFullName(value);
    if (name.isEmpty) return FieldValidationError.fullNameRequired;
    if (name.length < 2) return FieldValidationError.fullNameTooShort;
    if (RegExp(r'^\d+$').hasMatch(name)) {
      return FieldValidationError.fullNameDigitsOnly;
    }
    return null;
  }

  static FieldValidationError? validatePhone(String value) {
    final sanitized = PhoneNumberFormatter.sanitize(value);
    if (sanitized.isEmpty) return FieldValidationError.phoneRequired;
    if (!PhoneNumberFormatter.isValidIraqiMobile(sanitized)) {
      return FieldValidationError.phoneInvalid;
    }
    return null;
  }

  static FieldValidationError? validateSecretCode(String value) {
    if (value.isEmpty) return FieldValidationError.secretCodeRequired;
    if (value.contains(' ')) {
      // Spaces are not allowed; treat as too short / invalid length message.
      return FieldValidationError.secretCodeTooShort;
    }
    if (value.length < AppConfig.minSecretCodeLength) {
      return FieldValidationError.secretCodeTooShort;
    }
    return null;
  }

  static FieldValidationError? validateSecretCodeConfirmation({
    required String secretCode,
    required String confirmation,
  }) {
    final first = validateSecretCode(secretCode);
    if (first != null) return first;
    if (secretCode != confirmation) {
      return FieldValidationError.secretCodeMismatch;
    }
    return null;
  }

  static FieldValidationError? validateOtp(String value) {
    final digits = PhoneNumberFormatter.digitsOnly(value);
    if (digits.length != AppConfig.otpLength) {
      return FieldValidationError.otpIncomplete;
    }
    return null;
  }
}
