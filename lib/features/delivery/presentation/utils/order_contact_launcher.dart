import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/features/support/core/support_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launch helpers for user ↔ captain contact on order detail.
class OrderContactLauncher {
  const OrderContactLauncher._();

  /// Local Iraqi display: 07XXXXXXXXX (English digits).
  static String? localDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return PhoneNumberFormatter.toLocalDisplay(raw);
  }

  static bool hasCallablePhone(String? raw) => localDisplay(raw) != null;

  /// Dialer URI uses E.164: tel:+9647XXXXXXXXX
  static Uri? telUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final e164 = PhoneNumberFormatter.normalizeToE164(raw);
    if (e164 == null) return null;
    return SupportLauncher.telUri(e164);
  }

  static List<Uri> whatsAppLaunchUris(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return SupportLauncher.whatsAppLaunchUris(raw);
  }

  static Future<bool> tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  static Future<bool> launchFirst(Iterable<Uri> uris) async {
    for (final uri in uris) {
      if (await tryLaunch(uri)) return true;
    }
    return false;
  }
}
