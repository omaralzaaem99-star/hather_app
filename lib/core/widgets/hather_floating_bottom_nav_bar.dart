import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';

class ShellNavItem {
  const ShellNavItem({
    required this.branchIndex,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final int branchIndex;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Floating pill bottom bar — shared by user and captain shells.
///
/// Branches: 0=orders, 1=home, 2=account.
/// Visual LTR inside the bar: account | home | orders.
class HatherFloatingBottomNavBar extends StatelessWidget {
  const HatherFloatingBottomNavBar({
    required this.selectedBranch,
    required this.onTap,
    required this.items,
    super.key,
  });

  final int selectedBranch;
  final ValueChanged<int> onTap;
  final List<ShellNavItem> items;

  static const double barHeight = 64;
  static const double horizontalInset = 20;
  static const double bottomGap = 12;
  static const double pillRadius = 999;

  int get _visualIndex {
    switch (selectedBranch) {
      case 2:
        return 0;
      case 1:
        return 1;
      case 0:
        return 2;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          0,
          horizontalInset,
          (bottomInset > 0 ? bottomInset : bottomGap) + 4,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(pillRadius),
          child: Material(
            color: AppColors.navBar,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(pillRadius),
              side: BorderSide(
                color: isLight
                    ? AppColors.onPrimary.withValues(alpha: 0.14)
                    : AppColors.border.withValues(alpha: 0.4),
              ),
            ),
            child: SizedBox(
              height: barHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / items.length;
                  const capsuleInset = 5.0;
                  final highlightLeft =
                      _visualIndex * itemWidth + capsuleInset;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        left: highlightLeft,
                        width: itemWidth - (capsuleInset * 2),
                        top: capsuleInset,
                        bottom: capsuleInset,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isLight
                                  ? [
                                      AppColors.primaryHover,
                                      AppColors.primary.withValues(alpha: 0.92),
                                    ]
                                  : [
                                      AppColors.primary.withValues(alpha: 0.32),
                                      AppColors.primary.withValues(
                                        alpha: 0.18,
                                      ),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(pillRadius),
                            border: Border.all(
                              color: isLight
                                  ? AppColors.icon.withValues(alpha: 0.48)
                                  : AppColors.icon.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (final item in items)
                            Expanded(
                              child: _FloatingNavTab(
                                label: item.label,
                                icon: item.icon,
                                activeIcon: item.activeIcon,
                                selected:
                                    selectedBranch == item.branchIndex,
                                isLight: isLight,
                                onTap: () => onTap(item.branchIndex),
                                compact: textScale > 1.15,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavTab extends StatelessWidget {
  const _FloatingNavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.isLight,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final bool isLight;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final Color labelColor;

    if (isLight) {
      iconColor = selected
          ? AppColors.icon
          : AppColors.onPrimary.withValues(alpha: 0.78);
      labelColor = selected
          ? AppColors.onPrimary
          : AppColors.onPrimary.withValues(alpha: 0.78);
    } else {
      iconColor = selected ? AppColors.icon : AppColors.textMuted;
      labelColor = selected ? AppColors.textPrimary : AppColors.textMuted;
    }

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.icon.withValues(alpha: 0.12),
        highlightColor: AppColors.icon.withValues(alpha: 0.06),
        child: SizedBox.expand(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 2 : 4,
              vertical: compact ? 6 : 8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    selected ? activeIcon : icon,
                    key: ValueKey(selected),
                    size: selected ? 23 : 21,
                    color: iconColor,
                  ),
                ),
                SizedBox(height: compact ? 2 : 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: AppTextStyles.caption.copyWith(
                    color: labelColor,
                    fontSize: selected ? 12 : 11,
                    height: 1.05,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
