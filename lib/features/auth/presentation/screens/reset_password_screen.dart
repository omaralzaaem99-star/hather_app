import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/utils/localization_helpers.dart';
import 'package:hather_app/core/utils/validators.dart';
import 'package:hather_app/core/widgets/auth_header.dart';
import 'package:hather_app/core/widgets/error_message.dart';
import 'package:hather_app/core/widgets/password_text_field.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_state.dart';
import 'package:hather_app/features/auth/presentation/widgets/auth_card.dart';
import 'package:hather_app/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.challengeId, super.key});

  final String challengeId;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _secretController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _secretError;
  String? _confirmError;
  bool _submitting = false;

  @override
  void dispose() {
    _secretController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final secretError = Validators.validateSecretCode(_secretController.text);
    final confirmError = Validators.validateSecretCodeConfirmation(
      secretCode: _secretController.text,
      confirmation: _confirmController.text,
    );

    setState(() {
      _secretError = secretError == null
          ? null
          : localizeFieldError(l10n, secretError);
      _confirmError = confirmError == FieldValidationError.secretCodeMismatch
          ? localizeFieldError(l10n, confirmError!)
          : null;
    });

    if (secretError != null || confirmError != null || _submitting) return;

    setState(() => _submitting = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(
          challengeId: widget.challengeId,
          newSecretCode: _secretController.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordResetSuccess)));
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final formError = auth.status == AuthStatus.failure && auth.failure != null
        ? mapFailureToMessage(context, auth.failure!)
        : null;

    return AuthScaffold(
      top: BrandTitle(name: l10n.appName, compact: true),
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              title: l10n.resetPasswordTitle,
              subtitle: l10n.resetPasswordSubtitle,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            AuthFormErrorBanner(message: formError),
            PasswordTextField(
              controller: _secretController,
              errorText: _secretError,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_secretError != null) setState(() => _secretError = null);
              },
            ),
            const SizedBox(height: 12),
            PasswordTextField(
              controller: _confirmController,
              hintText: l10n.confirmSecretCode,
              errorText: _confirmError,
              onChanged: (_) {
                if (_confirmError != null) {
                  setState(() => _confirmError = null);
                }
              },
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            PrimaryButton(
              label: l10n.saveNewSecretCode,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
