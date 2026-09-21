import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';

void main() {
  group('HomeAd', () {
    test('isTappable respects action type', () {
      const none = HomeAd(id: '1', actionType: HomeAdActionType.none);
      const link = HomeAd(
        id: '2',
        actionType: HomeAdActionType.link,
        linkUrl: 'https://example.com',
      );
      const whatsapp = HomeAd(
        id: '3',
        actionType: HomeAdActionType.whatsapp,
        whatsappPhone: '07806560098',
      );

      expect(none.isTappable, isFalse);
      expect(link.isTappable, isTrue);
      expect(whatsapp.isTappable, isTrue);
    });

    test('fromWire maps action types', () {
      expect(HomeAdActionType.fromWire('link'), HomeAdActionType.link);
      expect(HomeAdActionType.fromWire('whatsapp'), HomeAdActionType.whatsapp);
      expect(HomeAdActionType.fromWire(null), HomeAdActionType.none);
    });
  });
}
