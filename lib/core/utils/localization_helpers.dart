import 'package:flutter/material.dart';
import 'package:hather_app/core/utils/validators.dart';
import 'package:hather_app/l10n/app_localizations.dart';

String localizeFieldError(AppLocalizations l10n, FieldValidationError error) {
  return switch (error) {
    FieldValidationError.fullNameRequired => l10n.errorFullNameRequired,
    FieldValidationError.fullNameTooShort => l10n.errorFullNameTooShort,
    FieldValidationError.fullNameDigitsOnly => l10n.errorFullNameDigitsOnly,
    FieldValidationError.phoneRequired => l10n.errorPhoneRequired,
    FieldValidationError.phoneInvalid => l10n.errorPhoneInvalid,
    FieldValidationError.secretCodeRequired => l10n.errorSecretCodeRequired,
    FieldValidationError.secretCodeTooShort => l10n.errorSecretCodeTooShort,
    FieldValidationError.secretCodeMismatch => l10n.errorSecretCodeMismatch,
    FieldValidationError.otpIncomplete => l10n.errorOtpIncomplete,
  };
}

/// Dismisses keyboard when tapping outside inputs.
class KeyboardDismisser extends StatelessWidget {
  const KeyboardDismisser({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}
