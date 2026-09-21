import 'package:hather_app/core/config/app_config.dart';

/// Central Iraqi phone number formatting and validation.
///
/// Always store/compare numbers in E.164: +9647XXXXXXXXX
class PhoneNumberFormatter {
  const PhoneNumberFormatter._();

  static const String countryCode = AppConfig.iraqCountryCode;

  /// Converts Arabic-Indic digits to Western digits.
  static String toEnglishDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final index = arabic.indexOf(char);
      buffer.write(index >= 0 ? western[index] : char);
    }
    return buffer.toString();
  }

  /// Removes spaces, dashes, and other separators.
  static String sanitize(String input) {
    final english = toEnglishDigits(input.trim());
    return english.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  /// Returns true when the value can be normalized to a valid Iraqi mobile.
  static bool isValidIraqiMobile(String input) {
    return normalizeToE164(input) != null;
  }

  /// Normalizes local (`07XXXXXXXXX`), international (`9647...`), or E.164
  /// into `+9647XXXXXXXXX`. Returns null when invalid.
  static String? normalizeToE164(String input) {
    var value = sanitize(input);
    if (value.isEmpty) return null;

    if (value.startsWith('00')) {
      value = value.substring(2);
    }

    if (value.startsWith('+')) {
      value = value.substring(1);
    }

    if (value.startsWith('964')) {
      value = value.substring(3);
    }

    if (value.startsWith('0')) {
      value = value.substring(1);
    }

    // Iraqi mobile numbers: 7XXXXXXXXX (10 digits starting with 7)
    if (!RegExp(r'^7\d{9}$').hasMatch(value)) {
      return null;
    }

    return '$countryCode$value';
  }

  /// Display form preferred in Iraqi UI: 07XXXXXXXXX
  static String? toLocalDisplay(String input) {
    final e164 = normalizeToE164(input);
    if (e164 == null) return null;
    final national = e164.substring(countryCode.length);
    return '0$national';
  }

  /// Digits only for input fields (English).
  static String digitsOnly(String input) =>
      toEnglishDigits(input).replaceAll(RegExp(r'\D'), '');
}
