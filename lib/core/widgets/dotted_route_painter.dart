import 'package:flutter/material.dart';

/// Horizontal dotted delivery route behind OTP pins.
class DottedRoutePainter extends CustomPainter {
  const DottedRoutePainter({
    this.color = const Color(0x457D918A),
    this.dotSize = 2.2,
    this.gap = 4.5,
  });

  final Color color;
  final double dotSize;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cy = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawCircle(Offset(x + dotSize / 2, cy), dotSize / 2, paint);
      x += dotSize + gap;
    }
  }

  @override
  bool shouldRepaint(covariant DottedRoutePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.gap != gap;
  }
}
