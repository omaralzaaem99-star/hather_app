import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Pointy-top hexagon clip for profile avatar.
class AccountHexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _hexagonPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Path _hexagonPath(Size size, {double inset = 0}) {
  final path = Path();
  final center = Offset(size.width / 2, size.height / 2);
  final radius = (size.width / 2) - inset;

  for (var i = 0; i < 6; i++) {
    final angle = (math.pi / 3 * i) - math.pi / 2;
    final point = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  return path;
}

class _HexagonBorderPainter extends CustomPainter {
  _HexagonBorderPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawPath(_hexagonPath(size, inset: strokeWidth / 2), paint);
  }

  @override
  bool shouldRepaint(covariant _HexagonBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Hexagonal profile avatar with initial letter.
class AccountHexagonAvatar extends StatelessWidget {
  const AccountHexagonAvatar({
    required this.initial,
    this.size = 76,
    super.key,
  });

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _HexagonBorderPainter(
              color: AppColors.icon.withValues(alpha: 0.5),
              strokeWidth: 2,
            ),
          ),
          ClipPath(
            clipper: AccountHexagonClipper(),
            child: Container(
              width: size,
              height: size,
              color: AppColors.icon.withValues(alpha: 0.18),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 26,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative lines on the header background (subtle, like reference topography).
class _HeaderPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.icon.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 5; i++) {
      final path = Path();
      final y = size.height * (0.15 + i * 0.14);
      path.moveTo(0, y);
      path.quadraticBezierTo(
        size.width * 0.35,
        y - 18,
        size.width * 0.65,
        y + 12,
      );
      path.quadraticBezierTo(size.width * 0.85, y + 28, size.width, y + 6);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Top area: title + profile on a continuous green hero block.
class AccountProfileHeader extends StatelessWidget {
  const AccountProfileHeader({
    required this.pageTitle,
    required this.fullName,
    required this.phoneDisplay,
    super.key,
  });

  final String pageTitle;
  final String fullName;
  final String phoneDisplay;

  String get _initial {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayName =
        fullName.trim().isEmpty ? l10n.valueNotAvailable : fullName.trim();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.95),
            AppColors.primary.withValues(alpha: 0.82),
            AppColors.primary.withValues(alpha: 0.68),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HeaderPatternPainter()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  pageTitle,
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AccountHexagonAvatar(initial: _initial),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: AppTextStyles.sectionTitle.copyWith(
                              fontSize: 20,
                              color: AppColors.onPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phoneDisplay,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: AppColors.icon,
                              letterSpacing: 0.3,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual rounded card for each settings block (reference-style).
class AccountSectionCard extends StatelessWidget {
  const AccountSectionCard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderSubtle.withValues(alpha: 0.22),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Scrollable list of separate section cards + logout card.
class AccountSectionCardsList extends StatelessWidget {
  const AccountSectionCardsList({
    required this.sections,
    required this.logoutLabel,
    required this.onLogout,
    super.key,
  });

  final List<Widget> sections;
  final String logoutLabel;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            AccountSectionCard(child: sections[i]),
            if (i < sections.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          AccountLogoutCard(label: logoutLabel, onPressed: onLogout),
        ],
      ),
    );
  }
}

/// Expandable settings section with animated chevron.
class AccountAccordionSection extends StatefulWidget {
  const AccountAccordionSection({
    required this.title,
    this.initiallyExpanded = false,
    this.rows = const [],
    this.expandedBody,
    super.key,
  });

  final String title;
  final bool initiallyExpanded;
  final List<Widget> rows;
  final Widget? expandedBody;

  @override
  State<AccountAccordionSection> createState() =>
      _AccountAccordionSectionState();
}

class _AccountAccordionSectionState extends State<AccountAccordionSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: _expanded ? 1 : 0,
    );
    _rotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.expandedBody ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.rows,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 16,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _rotation,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.borderSubtle.withValues(alpha: 0.3),
                      ),
                    ),
                    body,
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Simple settings row with trailing chevron.
class AccountSettingsRow extends StatelessWidget {
  const AccountSettingsRow({
    required this.label,
    this.onTap,
    this.textColor,
    this.trailing,
    this.showDivider = true,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? textColor;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? AppColors.textPrimary;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        color: color,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                        size: 22,
                      ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderSubtle.withValues(alpha: 0.2),
            ),
          ),
      ],
    );
  }
}

class AccountStatusBadge extends StatelessWidget {
  const AccountStatusBadge({
    required this.label,
    required this.tone,
    super.key,
  });

  final String label;
  final AccountBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      AccountBadgeTone.active => (
          AppColors.primary.withValues(alpha: 0.22),
          AppColors.icon,
        ),
      AccountBadgeTone.expired => (
          AppColors.error.withValues(alpha: 0.16),
          AppColors.error,
        ),
      AccountBadgeTone.neutral => (
          AppColors.surface,
          AppColors.textMuted,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AccountLogoutCard extends StatelessWidget {
  const AccountLogoutCard({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AccountSectionCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: AppColors.error.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.error.withValues(alpha: 0.92),
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

enum AccountBadgeTone { active, expired, neutral }
