import 'package:hather_app/core/utils/iqd_format.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/features/support/core/support_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

/// External launch helpers for captain active-order actions.
class CaptainOrderLauncher {
  const CaptainOrderLauncher._();

  static String formatIqd(num amount) => IqdFormat.format(amount);

  /// Local Iraqi display for UI + tel: (07XXXXXXXXX).
  static String? localPhone(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return PhoneNumberFormatter.toLocalDisplay(raw) ?? raw.trim();
  }

  static Uri? telUri(String? rawPhone) {
    final local = localPhone(rawPhone);
    if (local == null || local.isEmpty) return null;
    final digits = PhoneNumberFormatter.digitsOnly(local);
    if (digits.isEmpty) return null;
    return Uri(scheme: 'tel', path: digits);
  }

  /// WhatsApp chat — 07… / +964… → 9647… (display unchanged).
  static List<Uri> whatsAppLaunchUris(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return const [];
    return SupportLauncher.whatsAppLaunchUris(rawPhone);
  }

  /// Waze navigation to customer coordinates.
  static List<Uri> wazeLaunchUris(double lat, double lng) {
    final ll = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    return [
      Uri.parse('waze://?ll=$ll&navigate=yes'),
      Uri.parse('https://waze.com/ul?ll=$ll&navigate=yes'),
    ];
  }

  /// Google Maps navigation/directions to customer coordinates.
  static List<Uri> googleMapsLaunchUris(double lat, double lng) {
    final q = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    return [
      Uri.parse('google.navigation:q=$q'),
      Uri.parse('comgooglemaps://?daddr=$q&directionsmode=driving'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$q&travelmode=driving',
      ),
    ];
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
