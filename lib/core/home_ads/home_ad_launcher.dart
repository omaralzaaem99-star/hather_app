import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/features/support/core/support_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tap actions for home banner ads.
class HomeAdLauncher {
  const HomeAdLauncher._();

  static Future<bool> openLink(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openWhatsApp(String localPhone) async {
    final e164 = PhoneNumberFormatter.normalizeToE164(localPhone);
    if (e164 == null) return false;

    for (final uri in SupportLauncher.whatsAppLaunchUris(e164)) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      } on Object {
        // Try wa.me fallback.
      }
    }
    return false;
  }
}
