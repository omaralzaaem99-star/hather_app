import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/core/widgets/app_text_field.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Iraqi phone field — country code stays hidden; paste of +964/07 is normalized.
class PhoneTextField extends StatelessWidget {
  const PhoneTextField({
    required this.controller,
    super.key,
    this.errorText,
    this.onChanged,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextInputAction textInputAction;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppTextField(
      controller: controller,
      enabled: enabled,
      hintText: l10n.phoneNumber,
      errorText: errorText,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      textDirection: TextDirection.ltr,
      autofillHints: const [AutofillHints.telephoneNumber],
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+\s\-]')),
        _IraqiPhonePasteFormatter(),
      ],
      prefixIcon: Icon(
        Icons.phone_android_rounded,
        color: AppColors.icon,
        size: AppDimensions.iconSize,
      ),
    );
  }
}

/// Converts pasted +964 / 964 / 07… into local `07XXXXXXXXX` for the field.
class _IraqiPhonePasteFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = PhoneNumberFormatter.toEnglishDigits(newValue.text);
    final isPaste = newValue.text.length - oldValue.text.length > 1;

    if (isPaste) {
      final local = PhoneNumberFormatter.toLocalDisplay(text);
      if (local != null) {
        return TextEditingValue(
          text: local,
          selection: TextSelection.collapsed(offset: local.length),
        );
      }
    }

    if (text.startsWith('+964')) {
      text = text.substring(4);
    } else if (text.startsWith('964') && text.length > 3) {
      text = text.substring(3);
    }

    text = text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.length > 11) {
      text = text.substring(0, 11);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
