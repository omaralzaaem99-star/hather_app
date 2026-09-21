import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/widgets/hather_floating_bottom_nav_bar.dart';

/// Shared shell wrapper for user and captain bottom navigation.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    required this.navigationShell,
    required this.navItems,
    this.onBranchTap,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellNavItem> navItems;
  final ValueChanged<int>? onBranchTap;

  void _onTap(int index) {
    onBranchTap?.call(index);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: HatherFloatingBottomNavBar(
        selectedBranch: navigationShell.currentIndex,
        onTap: _onTap,
        items: navItems,
      ),
    );
  }
}
