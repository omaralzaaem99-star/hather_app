import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/widgets/app_text_field.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    required this.controller,
    super.key,
    this.hintText,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final bool enabled;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppTextField(
      controller: widget.controller,
      enabled: widget.enabled,
      hintText: widget.hintText ?? l10n.secretCode,
      errorText: widget.errorText,
      obscureText: _obscure,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.password],
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      prefixIcon: Icon(
        Icons.lock_outline_rounded,
        color: AppColors.icon,
        size: AppDimensions.iconSize,
      ),
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.icon,
          size: 22,
        ),
      ),
    );
  }
}
