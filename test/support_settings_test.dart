import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/support/core/support_launcher.dart';
import 'package:hather_app/features/support/domain/entities/support_settings.dart';

void main() {
  group('SupportSettings', () {
    test('parses enabled channels from json', () {
      final settings = SupportSettings.fromJson({
        'whatsapp_enabled': true,
        'whatsapp_number': '+9647806560098',
        'phone_enabled': false,
        'phone_number': null,
        'email_enabled': true,
        'email_address': 'support@hather.app',
        'support_message': 'مرحباً',
      });

      expect(settings.hasWhatsappChannel, isTrue);
      expect(settings.hasPhoneChannel, isFalse);
      expect(settings.hasEmailChannel, isTrue);
      expect(settings.hasAnyChannel, isTrue);
      expect(settings.supportMessage, 'مرحباً');
    });

    test('empty settings have no channels', () {
      final settings = SupportSettings.empty();
      expect(settings.hasAnyChannel, isFalse);
    });

    test('enabled flag without number is not a channel', () {
      final settings = SupportSettings.fromJson({
        'whatsapp_enabled': true,
        'whatsapp_number': null,
        'phone_enabled': true,
        'phone_number': '',
        'email_enabled': true,
        'email_address': ' ',
        'support_message': null,
      });

      expect(settings.hasAnyChannel, isFalse);
    });
  });

  group('SupportLauncher', () {
    test('builds WhatsApp URL without plus sign', () {
      expect(
        SupportLauncher.whatsAppUrl('+9647806560098'),
        'https://wa.me/9647806560098',
      );
    });

    test('builds WhatsApp URL from local-style stored value', () {
      expect(
        SupportLauncher.whatsAppUrl('07806560098'),
        'https://wa.me/9647806560098',
      );
    });

    test('builds native WhatsApp send URI', () {
      expect(
        SupportLauncher.whatsAppSendUri('+9647806560098').toString(),
        'whatsapp://send?phone=9647806560098',
      );
    });

    test('orders native URI before wa.me', () {
      final uris = SupportLauncher.whatsAppLaunchUris('+9647806560098');
      expect(uris.first.toString(), 'whatsapp://send?phone=9647806560098');
      expect(uris.last.toString(), 'https://wa.me/9647806560098');
    });

    test('builds tel URI with E.164 number', () {
      expect(
        SupportLauncher.telUri('+9647806560098').toString(),
        'tel:+9647806560098',
      );
    });

    test('builds mailto URI', () {
      expect(
        SupportLauncher.mailtoUri('support@hather.app').toString(),
        'mailto:support@hather.app',
      );
    });
  });
}
