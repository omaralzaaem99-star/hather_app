import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_theme.dart';
import 'package:hather_app/core/theme/hather_theme_colors.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:hather_app/features/captain/presentation/widgets/available_order_card.dart';
import 'package:hather_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget captainHarness({
    required ThemeData theme,
    required Widget child,
  }) {
    return MaterialApp(
      theme: theme,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          AppColors.bind(theme.brightness);
          return Scaffold(body: child);
        },
      ),
    );
  }

  final sampleOrder = CaptainAvailableOrder(
    id: 'order-1',
    orderTypeName: 'delivery',
    requestNumber: 42,
    details: 'طلب تجريبي للاختبار',
    destinationLabel: 'بغداد - الكرادة',
    deliveryFeeIqd: 5000,
    expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    createdAt: DateTime.now(),
  );

  group('Captain light theme widgets', () {
    testWidgets('AvailableOrderCard uses primary request number in light', (
      tester,
    ) async {
      await tester.pumpWidget(
        captainHarness(
          theme: AppTheme.light,
          child: AvailableOrderCard(order: sampleOrder, onTap: () {}),
        ),
      );

      final requestText = tester.widget<Text>(
        find.textContaining('#'),
      );
      expect(requestText.style?.color, AppColors.primary);
    });

    testWidgets('AvailableOrderCard uses mint request number in dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        captainHarness(
          theme: AppTheme.dark,
          child: AvailableOrderCard(order: sampleOrder, onTap: () {}),
        ),
      );

      final requestText = tester.widget<Text>(
        find.textContaining('#'),
      );
      expect(requestText.style?.color, AppColors.icon);
    });

    test('light mode accent and success greens are stronger than dark', () {
      AppColors.bind(Brightness.light);
      expect(AppColors.icon, HatherThemeColors.light.accent);
      expect(AppColors.success, HatherThemeColors.light.success);
      expect(AppColors.icon, const Color(0xFF1A5F44));
      expect(AppColors.success, const Color(0xFF1B6B47));

      AppColors.bind(Brightness.dark);
      expect(AppColors.icon, const Color(0xFF9AD4B8));
      expect(AppColors.success, const Color(0xFF4CAF7A));
    });

    test('captain semantic surfaces bind correctly in light mode', () {
      AppColors.bind(Brightness.light);
      expect(AppColors.surface, HatherThemeColors.light.surface);
      expect(AppColors.background, HatherThemeColors.light.background);
      expect(AppColors.textPrimary, HatherThemeColors.light.textPrimary);
    });
  });
}
