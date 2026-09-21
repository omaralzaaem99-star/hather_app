import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/utils/localization_helpers.dart';
import 'package:hather_app/core/widgets/loading_overlay.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.isLoading = false,
    this.resizeToAvoidBottomInset = true,
    this.padding,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool isLoading;
  final bool resizeToAvoidBottomInset;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return KeyboardDismisser(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: appBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        body: LoadingOverlay(
          isLoading: isLoading,
          child: SafeArea(
            child: Padding(
              padding: padding ?? AppDimensions.screenPadding,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
