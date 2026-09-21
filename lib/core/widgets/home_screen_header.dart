import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Same green hero gradient as [AccountProfileHeader].
LinearGradient get _accountHeaderGradient => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.primary.withValues(alpha: 0.95),
        AppColors.primary.withValues(alpha: 0.82),
        AppColors.primary.withValues(alpha: 0.68),
      ],
    );

/// Subtle topography lines — matches account profile header pattern.
class _HomeHeaderPatternPainter extends CustomPainter {
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

/// Top welcome bar: app name + greeting, shared on user/captain home.
class HomeScreenHeader extends StatelessWidget {
  const HomeScreenHeader({
    required this.welcomeName,
    required this.onNotificationsPressed,
    this.unreadCount = 0,
    super.key,
  });

  final String welcomeName;
  final VoidCallback onNotificationsPressed;
  final int unreadCount;

  String get _badgeLabel {
    if (unreadCount <= 0) return '';
    if (unreadCount > 99) return '99+';
    return '$unreadCount';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final badge = _badgeLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _accountHeaderGradient,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _HomeHeaderPatternPainter()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.appName,
                          style: AppTextStyles.brandTitle.copyWith(
                            fontSize: 28,
                            color: AppColors.onPrimary,
                            shadows: const [],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.homeWelcome(welcomeName),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 13,
                            color: AppColors.onPrimary.withValues(
                              alpha: 0.88,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: l10n.notificationsTitle,
                        onPressed: onNotificationsPressed,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.onPrimary.withValues(alpha: 0.12),
                          side: BorderSide(
                            color: AppColors.onPrimary.withValues(
                              alpha: 0.22,
                            ),
                          ),
                          minimumSize: const Size(44, 44),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.onPrimary,
                          size: AppDimensions.iconSize,
                        ),
                      ),
                      if (badge.isNotEmpty)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.icon,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              badge,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
