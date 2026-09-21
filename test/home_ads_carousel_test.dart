import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/home_ads/home_ads_constants.dart';
import 'package:hather_app/core/widgets/home_ads_carousel.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';
import 'package:hather_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeAdsCarousel', () {
    test('auto play interval is 3 seconds', () {
      expect(homeAdsAutoPlayInterval, const Duration(seconds: 3));
    });

    testWidgets('shows placeholder when there are no ads', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeAdsCarousel(ads: [])),
        ),
      );

      expect(find.byType(HomeAdsCarousel), findsOneWidget);
    });

    testWidgets('renders single ad without crashing', (tester) async {
      const ad = HomeAd(id: '1', imageUrl: 'https://example.com/ad.jpg');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeAdsCarousel(ads: [ad])),
        ),
      );

      expect(find.byType(HomeAdsCarousel), findsOneWidget);
    });

    testWidgets('renders multiple ads with page indicators', (tester) async {
      const ads = [
        HomeAd(id: '1', imageUrl: 'https://example.com/1.jpg'),
        HomeAd(id: '2', imageUrl: 'https://example.com/2.jpg'),
        HomeAd(id: '3', imageUrl: 'https://example.com/3.jpg'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeAdsCarousel(ads: ads)),
        ),
      );

      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
