import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/utils/localization_helpers.dart';
import 'package:hather_app/core/utils/validators.dart';
import 'package:hather_app/core/widgets/auth_header.dart';
import 'package:hather_app/core/widgets/error_message.dart';
import 'package:hather_app/core/widgets/phone_text_field.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_state.dart';
import 'package:hather_app/features/auth/presentation/widgets/auth_card.dart';
import 'package:hather_app/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  String? _phoneError;
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final phoneError = Validators.validatePhone(_phoneController.text);
    setState(() {
      _phoneError = phoneError == null
          ? null
          : localizeFieldError(l10n, phoneError);
    });
    if (phoneError != null || _submitting) return;

    setState(() => _submitting = true);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(_phoneController.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      context.push('/otp-verification');
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
      showHeroBackground: false,
      brandTopFactor: 0.08,
      leading: AuthBackButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/login');
          }
        },
      ),
      top: BrandTitle(name: l10n.appName, compact: true),
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              title: l10n.forgotPasswordTitle,
              subtitle: l10n.forgotPasswordSubtitle,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            AuthFormErrorBanner(message: formError),
            PhoneTextField(
              controller: _phoneController,
              errorText: _phoneError,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_phoneError != null) setState(() => _phoneError = null);
                ref.read(authControllerProvider.notifier).clearFailure();
              },
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            PrimaryButton(
              label: l10n.sendOtpAction,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
