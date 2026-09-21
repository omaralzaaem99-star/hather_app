import 'package:hather_app/core/utils/phone_number_formatter.dart';

/// Builds external URLs for support channels.
class SupportLauncher {
  const SupportLauncher._();

  static String _internationalDigits(String phoneNumber) {
    final e164 =
        PhoneNumberFormatter.normalizeToE164(phoneNumber) ?? phoneNumber;
    final digits = PhoneNumberFormatter.sanitize(e164);
    return digits.startsWith('+') ? digits.substring(1) : digits;
  }

  /// WhatsApp wa.me link uses international digits without `+`.
  static String whatsAppUrl(String phoneNumber) {
    return 'https://wa.me/${_internationalDigits(phoneNumber)}';
  }

  /// Native WhatsApp deep link — preferred on Android/iOS.
  static Uri whatsAppSendUri(String phoneNumber) {
    return Uri.parse(
      'whatsapp://send?phone=${_internationalDigits(phoneNumber)}',
    );
  }

  /// Ordered launch targets: native app first, then universal link.
  static List<Uri> whatsAppLaunchUris(String phoneNumber) {
    return [
      whatsAppSendUri(phoneNumber),
      Uri.parse(whatsAppUrl(phoneNumber)),
    ];
  }

  static Uri telUri(String phoneNumber) {
    final e164 =
        PhoneNumberFormatter.normalizeToE164(phoneNumber) ?? phoneNumber;
    final sanitized = PhoneNumberFormatter.sanitize(e164);
    return Uri(scheme: 'tel', path: sanitized);
  }

  static Uri mailtoUri(String email) {
    return Uri(scheme: 'mailto', path: email.trim());
  }
}
