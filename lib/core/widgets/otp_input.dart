import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/core/widgets/delivery_otp_pin.dart';
import 'package:hather_app/core/widgets/dotted_route_painter.dart';

/// Six delivery-pin OTP fields — keeps paste / focus / clear API for auth screens.
class OtpInput extends StatefulWidget {
  const OtpInput({
    required this.onCompleted,
    super.key,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.length = AppConfig.otpLength,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;
  final int length;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  String _lastCompleted = '';
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (index) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus && _activeIndex != index) {
          setState(() => _activeIndex = index);
        }
      });
      return node;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get code => _controllers.map((c) => c.text).join();

  void clear({bool notifyChanged = true}) {
    for (final c in _controllers) {
      c.clear();
    }
    _lastCompleted = '';
    _activeIndex = 0;
    if (notifyChanged) {
      widget.onChanged?.call('');
    }
    if (widget.enabled) {
      _focusNodes.first.requestFocus();
    }
    setState(() {});
  }

  void _emit() {
    final value = code;
    widget.onChanged?.call(value);
    if (value.length == widget.length &&
        value != _lastCompleted &&
        widget.enabled) {
      _lastCompleted = value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.enabled) return;
        if (code == value) {
          widget.onCompleted(value);
        }
      });
    }
  }

  String _digitsOnly(String raw) {
    final english = PhoneNumberFormatter.toEnglishDigits(raw);
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const western = '0123456789';
    final buffer = StringBuffer();
    for (final rune in english.runes) {
      final char = String.fromCharCode(rune);
      final p = persian.indexOf(char);
      if (p >= 0) {
        buffer.write(western[p]);
      } else if (RegExp(r'\d').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  void _handlePaste(String digits) {
    final clipped = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].text = i < clipped.length ? clipped[i] : '';
    }
    final focusIndex = clipped.length >= widget.length
        ? widget.length - 1
        : clipped.length;
    _activeIndex = focusIndex.clamp(0, widget.length - 1);
    _focusNodes[_activeIndex].requestFocus();
    _emit();
    setState(() {});
  }

  void _onChanged(int index, String raw) {
    final digits = _digitsOnly(raw);
    if (digits.length > 1) {
      _handlePaste(digits);
      return;
    }

    _controllers[index].value = TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );

    if (digits.isNotEmpty && index < widget.length - 1) {
      _activeIndex = index + 1;
      _focusNodes[index + 1].requestFocus();
    } else {
      _activeIndex = index;
    }

    if (digits.isEmpty) {
      _lastCompleted = '';
    }

    _emit();
    setState(() {});
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _activeIndex = index - 1;
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      _lastCompleted = '';
      _emit();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            const gap = 6.0;
            final calculatedWidth =
                (availableWidth - (gap * (widget.length - 1))) / widget.length;
            final pinWidth = calculatedWidth.clamp(42.0, 64.0);
            final pinHeight = pinWidth * (112 / 72);
            final totalPinsWidth =
                pinWidth * widget.length + gap * (widget.length - 1);
            final sideInset = ((availableWidth - totalPinsWidth) / 2).clamp(
              0.0,
              double.infinity,
            );
            final routeTop = pinHeight * (83 / 112);

            return SizedBox(
              height: pinHeight + 14,
              width: availableWidth,
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: sideInset + pinWidth * 0.35,
                    right: sideInset + pinWidth * 0.35,
                    top: 8 + routeTop - 1,
                    height: 4,
                    child: const CustomPaint(
                      painter: DottedRoutePainter(),
                      child: SizedBox.expand(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var index = 0; index < widget.length; index++) ...[
                            if (index > 0) const SizedBox(width: gap),
                            Focus(
                              onKeyEvent: (node, event) => _onKey(index, event),
                              child: DeliveryOtpPin(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                width: pinWidth,
                                enabled: widget.enabled,
                                isActive: widget.enabled &&
                                    _focusNodes[index].hasFocus,
                                isFilled: _controllers[index].text.isNotEmpty,
                                hasError: hasError,
                                autofillHints: index == 0
                                    ? const [AutofillHints.oneTimeCode]
                                    : null,
                                onChanged: (value) => _onChanged(index, value),
                                onTap: () {
                                  setState(() => _activeIndex = index);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
