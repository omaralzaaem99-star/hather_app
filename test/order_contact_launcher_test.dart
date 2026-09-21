import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/delivery/presentation/utils/order_contact_launcher.dart';

void main() {
  group('OrderContactLauncher', () {
    test('formats captain phone for local Iraqi display', () {
      expect(
        OrderContactLauncher.localDisplay('+9647806560098'),
        '07806560098',
      );
      expect(
        OrderContactLauncher.localDisplay('9647806560098'),
        '07806560098',
      );
    });

    test('builds tel URI with E.164 for dialer', () {
      expect(
        OrderContactLauncher.telUri('+9647806560098')?.toString(),
        'tel:+9647806560098',
      );
    });

    test('builds WhatsApp URIs from local stored forms', () {
      final uris = OrderContactLauncher.whatsAppLaunchUris('07806560098');
      expect(uris, isNotEmpty);
      expect(
        uris.first.toString(),
        contains('9647806560098'),
      );
    });
  });
}
