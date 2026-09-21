import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_theme.dart';
import 'package:hather_app/core/theme/hather_theme_colors.dart';
import 'package:hather_app/core/widgets/auth_header.dart';
import 'package:hather_app/core/widgets/error_message.dart';
import 'package:hather_app/core/widgets/home_screen_header.dart';
import 'package:hather_app/core/widgets/hather_floating_bottom_nav_bar.dart';
import 'package:hather_app/features/auth/presentation/widgets/create_account_notch.dart';
import 'package:hather_app/features/delivery/presentation/widgets/order_progress_tracker.dart';
import 'package:hather_app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget lightHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          AppColors.bind(Brightness.light);
          return Scaffold(body: child);
        },
      ),
    );
  }

  group('Light mode audit widgets', () {
    test('light glassFill is opaque enough for auth cards', () {
      expect(
        HatherThemeColors.light.glassFill.a,
        greaterThan(0.85),
      );
    });

    testWidgets('HomeScreenHeader shows app name and welcome text', (
      tester,
    ) async {
      await tester.pumpWidget(
        lightHarness(
          child: HomeScreenHeader(
            welcomeName: 'أحمد',
            onNotificationsPressed: () {},
          ),
        ),
      );

      expect(find.text('حاضر'), findsOneWidget);
      expect(find.text('مرحباً، أحمد'), findsOneWidget);

      final welcome = tester.widget<Text>(find.text('مرحباً، أحمد'));
      expect(welcome.style?.color, AppColors.onPrimary.withValues(alpha: 0.88));
    });

    testWidgets('BrandTitle shows app name text', (tester) async {
      await tester.pumpWidget(
        lightHarness(child: const BrandTitle(name: 'حاضر')),
      );

      final title = tester.widget<Text>(find.text('حاضر'));
      expect(title.style?.color, AppColors.onPrimary);
    });

    testWidgets('AuthFormErrorBanner error text stays readable', (
      tester,
    ) async {
      await tester.pumpWidget(
        lightHarness(
          child: const AuthFormErrorBanner(message: 'خطأ في تسجيل الدخول'),
        ),
      );

      final errorText = tester.widget<Text>(
        find.text('خطأ في تسجيل الدخول'),
      );
      expect(errorText.style?.color, AppColors.error);
    });

    testWidgets('CreateAccountNotch label uses light textPrimary', (
      tester,
    ) async {
      await tester.pumpWidget(
        lightHarness(
          child: CreateAccountNotch(
            label: 'إنشاء حساب',
            onTap: () {},
          ),
        ),
      );

      final label = tester.widget<Text>(find.text('إنشاء حساب'));
      expect(label.style?.color, AppColors.textPrimary);
    });

    testWidgets('OrderProgressTracker pending renders in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        lightHarness(
          child: const OrderProgressTracker(status: 'pending'),
        ),
      );

      expect(find.textContaining('بانتظار'), findsWidgets);
      expect(find.byType(OrderProgressTracker), findsOneWidget);
    });

    testWidgets('OrderProgressTracker progress card uses light surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        lightHarness(
          child: const OrderProgressTracker(status: 'active'),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(OrderProgressTracker),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.surface);
    });
    test('light navBar uses brand primary green', () {
      AppColors.bind(Brightness.light);
      expect(AppColors.navBar, HatherThemeColors.light.navBar);
      expect(AppColors.navBar, const Color(0xFF144D37));
    });

    testWidgets('floating bottom nav has no outer shadow in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        lightHarness(
          child: HatherFloatingBottomNavBar(
            selectedBranch: 1,
            onTap: (_) {},
            items: const [
              ShellNavItem(
                branchIndex: 2,
                label: 'الحساب',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
              ),
              ShellNavItem(
                branchIndex: 1,
                label: 'الرئيسية',
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
              ),
              ShellNavItem(
                branchIndex: 0,
                label: 'طلباتي',
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
              ),
            ],
          ),
        ),
      );

      final materialFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.color == AppColors.navBar &&
            widget.elevation == 0,
      );
      expect(materialFinder, findsOneWidget);

      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      for (final box in decoratedBoxes) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(
            decoration.boxShadow == null || decoration.boxShadow!.isEmpty,
            isTrue,
          );
        }
      }
    });
  });
}
