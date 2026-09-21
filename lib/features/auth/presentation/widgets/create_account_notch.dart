import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';

/// Curved bottom CTA — solid #161717 fill matching app background.
class CreateAccountNotch extends StatelessWidget {
  const CreateAccountNotch({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  static const double width = 253;
  static const double height = 59;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const CustomPaint(
              size: Size(width, height),
              painter: _CreateAccountNotchPainter(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateAccountNotchPainter extends CustomPainter {
  const _CreateAccountNotchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Clean upward-center bump (reference login notch), fill = background #161717.
    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.97)
      ..cubicTo(w * 0.08, h * 0.96, w * 0.16, h * 0.88, w * 0.26, h * 0.68)
      ..cubicTo(w * 0.38, h * 0.28, w * 0.38, h * 0.04, w * 0.50, h * 0.04)
      ..cubicTo(w * 0.62, h * 0.04, w * 0.62, h * 0.28, w * 0.74, h * 0.68)
      ..cubicTo(w * 0.84, h * 0.88, w * 0.92, h * 0.96, w, h * 0.97)
      ..lineTo(w, h)
      ..close();

    final fill = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
