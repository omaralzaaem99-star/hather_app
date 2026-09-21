import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/captain/presentation/utils/captain_order_launcher.dart';

void main() {
  group('CaptainOrderLauncher', () {
    test('localPhone formats Iraqi display', () {
      expect(
        CaptainOrderLauncher.localPhone('+9647756888722'),
        '07756888722',
      );
    });

    test('whatsAppLaunchUris normalizes 07 to 964', () {
      final uris = CaptainOrderLauncher.whatsAppLaunchUris('07756888722');
      expect(uris, isNotEmpty);
      expect(
        uris.last.toString(),
        'https://wa.me/9647756888722',
      );
      expect(
        uris.first.toString(),
        'whatsapp://send?phone=9647756888722',
      );
    });

    test('whatsAppLaunchUris does not duplicate 964 prefix', () {
      final uris = CaptainOrderLauncher.whatsAppLaunchUris('+9647756888722');
      expect(uris.last.toString(), 'https://wa.me/9647756888722');
    });

    test('wazeLaunchUris uses navigate deep link first', () {
      final uris = CaptainOrderLauncher.wazeLaunchUris(32.0101, 44.40288);
      expect(
        uris.first.toString(),
        'waze://?ll=32.010100,44.402880&navigate=yes',
      );
      expect(
        uris.last.toString(),
        'https://waze.com/ul?ll=32.010100,44.402880&navigate=yes',
      );
    });

    test('googleMapsLaunchUris prefers navigation intent', () {
      final uris = CaptainOrderLauncher.googleMapsLaunchUris(32.01, 44.40288);
      expect(
        uris.first.toString(),
        'google.navigation:q=32.010000,44.402880',
      );
      expect(
        uris.last.toString(),
        contains('google.com/maps/dir'),
      );
    });

    test('telUri uses local digits', () {
      expect(
        CaptainOrderLauncher.telUri('+9647756888722')?.toString(),
        'tel:07756888722',
      );
    });
  });
}
