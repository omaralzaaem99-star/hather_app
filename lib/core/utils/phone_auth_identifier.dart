/// Sanitizes legacy `@hather.local` strings that may still appear in Auth errors.
/// New Phone Auth flows do not generate internal emails.
class PhoneAuthIdentifier {
  const PhoneAuthIdentifier._();

  static const String domain = 'hather.local';

  /// Returns true when [value] looks like a legacy internal auth email.
  static bool isInternalEmail(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.trim().toLowerCase().endsWith('@$domain');
  }

  /// Strips any legacy internal email from a message so it is never shown to users.
  static String sanitizeUserMessage(String message) {
    return message
        .replaceAll(
          RegExp(r'[0-9+]+@hather\.local', caseSensitive: false),
          'رقم الهاتف',
        )
        .replaceAll(RegExp(r'@hather\.local', caseSensitive: false), '')
        .trim();
  }
}
