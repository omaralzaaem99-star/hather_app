import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hather_app/core/widgets/delivery_pin_painter.dart';

/// Single delivery-pin OTP digit field (CustomPainter shape).
class DeliveryOtpPin extends StatelessWidget {
  const DeliveryOtpPin({
    required this.controller,
    required this.focusNode,
    required this.isActive,
    required this.isFilled,
    required this.hasError,
    required this.onChanged,
    required this.width,
    super.key,
    this.onTap,
    this.enabled = true,
    this.autofillHints,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isActive;
  final bool isFilled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTap;
  final double width;
  final bool enabled;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final pinWidth = width;
    final pinHeight = pinWidth * (112 / 72);
    final fontSize = (pinWidth * 0.42).clamp(16.0, 24.0);

    final Color borderColor;
    final double borderWidth;
    if (hasError) {
      borderColor = const Color(0xFFE88B7F);
      borderWidth = 1.5;
    } else if (isActive) {
      borderColor = const Color(0x8A8EA49B);
      borderWidth = 1.5;
    } else if (isFilled) {
      borderColor = const Color(0x668EA49B);
      borderWidth = 1.4;
    } else {
      borderColor = const Color(0x6B8EA49B);
      borderWidth = 1.4;
    }

    final shadows = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: isActive ? 0.38 : 0.20),
        blurRadius: isActive ? 12 : 7,
        offset: Offset(0, isActive ? 8 : 4),
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, isActive ? -8 : 0, 0),
      width: pinWidth,
      height: pinHeight,
      decoration: BoxDecoration(boxShadow: shadows),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!enabled) return;
          focusNode.requestFocus();
          onTap?.call();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size(pinWidth, pinHeight),
              painter: DeliveryPinPainter(
                borderColor: borderColor,
                borderWidth: borderWidth,
                hasError: hasError,
              ),
            ),
            Positioned(
              top: pinHeight * 0.13,
              left: pinWidth * 0.15,
              width: pinWidth * 0.70,
              height: pinHeight * 0.50,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textAlign: TextAlign.center,
                showCursor: true,
                cursorColor: Colors.white,
                cursorWidth: 1.4,
                autofillHints: autofillHints,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  filled: false,
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
