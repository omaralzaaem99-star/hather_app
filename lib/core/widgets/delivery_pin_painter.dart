import 'package:flutter/material.dart';

/// Paints the elongated delivery location pin body (72×112 reference).
class DeliveryPinPainter extends CustomPainter {
  const DeliveryPinPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.hasError,
  });

  final Color borderColor;
  final double borderWidth;
  final bool hasError;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 72;
    final scaleY = size.height / 112;

    final path = Path()
      ..moveTo(36 * scaleX, 2 * scaleY)
      ..cubicTo(
        18 * scaleX,
        2 * scaleY,
        6 * scaleX,
        15 * scaleY,
        6 * scaleX,
        34 * scaleY,
      )
      ..lineTo(6 * scaleX, 59 * scaleY)
      ..cubicTo(
        6 * scaleX,
        79 * scaleY,
        19 * scaleX,
        96 * scaleY,
        36 * scaleX,
        108 * scaleY,
      )
      ..cubicTo(
        53 * scaleX,
        96 * scaleY,
        66 * scaleX,
        79 * scaleY,
        66 * scaleX,
        59 * scaleY,
      )
      ..lineTo(66 * scaleX, 34 * scaleY)
      ..cubicTo(
        66 * scaleX,
        15 * scaleY,
        54 * scaleX,
        2 * scaleY,
        36 * scaleX,
        2 * scaleY,
      )
      ..close();

    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1A2421), Color(0xFF0E1513)],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..isAntiAlias = true;

    canvas.drawPath(path, strokePaint);

    // Digit well
    final digitCenter = Offset(size.width * 0.5, size.height * (37 / 112));
    final digitRadius = size.width * (23 / 72);
    canvas.drawCircle(
      digitCenter,
      digitRadius,
      Paint()..color = const Color(0xFF111816),
    );
    canvas.drawCircle(
      digitCenter,
      digitRadius,
      Paint()
        ..color = hasError ? const Color(0x66FF7B6A) : const Color(0x617F8F89)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Package badge
    final badgeCenter = Offset(size.width * 0.5, size.height * (83 / 112));
    final badgeRadius = size.width * (10 / 72);
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()..color = const Color(0xFF123327),
    );
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()
        ..color = const Color(0x474BE1A5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    _paintPackageIcon(canvas, badgeCenter, badgeRadius * 1.15);
  }

  void _paintPackageIcon(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = const Color(0xFF4BE1A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final w = size * 0.95;
    final h = size * 0.85;
    final left = center.dx - w / 2;
    final right = center.dx + w / 2;
    final top = center.dy - h / 2;
    final bottom = center.dy + h / 2;
    final midY = center.dy - h * 0.08;
    final ridge = h * 0.28;

    final box = Path()
      ..moveTo(center.dx, top)
      ..lineTo(right, top + ridge)
      ..lineTo(right, bottom - ridge * 0.35)
      ..lineTo(center.dx, bottom)
      ..lineTo(left, bottom - ridge * 0.35)
      ..lineTo(left, top + ridge)
      ..close();

    canvas.drawPath(box, paint);
    canvas.drawLine(
      Offset(center.dx, top),
      Offset(center.dx, midY + h * 0.12),
      paint,
    );
    canvas.drawLine(Offset(left, top + ridge), Offset(center.dx, midY), paint);
    canvas.drawLine(Offset(right, top + ridge), Offset(center.dx, midY), paint);
  }

  @override
  bool shouldRepaint(covariant DeliveryPinPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.hasError != hasError;
  }
}
