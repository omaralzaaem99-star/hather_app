import 'package:flutter/material.dart';
import 'package:hather_app/core/constants/auth_assets.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/utils/localization_helpers.dart';
import 'package:hather_app/features/auth/presentation/widgets/auth_hero_background.dart';

/// Shared auth shell: hero background, keyboard-safe scroll, dismiss on tap.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    super.key,
    this.top,
    this.bottom,
    this.leading,
    this.resizeToAvoidBottomInset = true,
    this.showHeroBackground = true,
    this.backgroundAsset = AuthAssets.background,
    this.backgroundAlignment = Alignment.center,
    this.brandTopFactor = AppDimensions.authBrandTopFactor,
  });

  /// Optional brand / back row pinned toward the top of the scroll area.
  final Widget? top;

  /// Main form card / content.
  final Widget child;

  /// Optional footer below the card (e.g. create account).
  final Widget? bottom;

  /// Optional back control overlaid at the top-start.
  final Widget? leading;

  final bool resizeToAvoidBottomInset;

  /// When false, solid background only (no hero image).
  final bool showHeroBackground;
  final String backgroundAsset;
  final AlignmentGeometry backgroundAlignment;
  final double brandTopFactor;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.viewPadding.top;
    final bottomPad = mq.viewPadding.bottom;
    final keyboard = mq.viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showHeroBackground)
            AuthHeroBackground(
              imageAsset: backgroundAsset,
              alignment: backgroundAlignment,
            )
          else
            ColoredBox(color: AppColors.background),
          if (leading != null)
            Positioned(top: topPad + 12, right: 16, child: leading!),
          KeyboardDismisser(
            child: ScrollConfiguration(
              behavior: const _AuthScrollBehavior(),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: mq.size.height),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: topPad,
                      bottom: bottomPad + (keyboard > 0 ? 16 : 28),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (top != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppDimensions.authHorizontalMargin,
                              mq.size.height * brandTopFactor,
                              AppDimensions.authHorizontalMargin,
                              AppDimensions.spaceMd,
                            ),
                            child: top,
                          )
                        else
                          SizedBox(height: mq.size.height * brandTopFactor),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            child,
                            if (bottom != null) ...[
                              const SizedBox(height: AppDimensions.spaceMd),
                              bottom!,
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Disables Android stretch-overscroll which can crash when the keyboard
/// dismisses and auth form content height changes in the same frame.
class _AuthScrollBehavior extends ScrollBehavior {
  const _AuthScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

/// Compact back control for secondary auth screens.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: CircleBorder(
        side: BorderSide(color: AppColors.authPanelBorder),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textPrimary,
            size: 18,
          ),
        ),
      ),
    );
  }
}
