import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/constants/auth_assets.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/localization_helpers.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/core/utils/validators.dart';
import 'package:hather_app/core/widgets/app_text_field.dart';
import 'package:hather_app/core/widgets/auth_info_banner.dart';
import 'package:hather_app/core/widgets/auth_header.dart';
import 'package:hather_app/core/widgets/error_message.dart';
import 'package:hather_app/core/widgets/password_text_field.dart';
import 'package:hather_app/core/widgets/phone_text_field.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_state.dart';
import 'package:hather_app/features/auth/presentation/widgets/auth_card.dart';
import 'package:hather_app/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:hather_app/features/auth/presentation/widgets/create_account_notch.dart';
import 'package:hather_app/l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _secretController = TextEditingController();

  String? _nameError;
  String? _phoneError;
  String? _secretError;
  bool _submitting = false;
  bool _showUnregisteredHint = false;

  late final AnimationController _entryController;
  late final Animation<double> _cardSlide;
  late final Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    final draft = auth.pendingRegistration;
    if (auth.registerPrefillPhoneLocal != null) {
      _phoneController.text = auth.registerPrefillPhoneLocal!;
      _showUnregisteredHint = auth.showRegisterFromLoginHint;
    } else if (draft != null) {
      _nameController.text = draft.fullName;
      _phoneController.text =
          PhoneNumberFormatter.toLocalDisplay(draft.phone) ?? draft.phone;
      _secretController.text = draft.secretCode;
    }
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _cardSlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 1, curve: Curves.easeOut),
      ),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final nameError = Validators.validateFullName(_nameController.text);
    final phoneError = Validators.validatePhone(_phoneController.text);
    final secretError = Validators.validateSecretCode(_secretController.text);

    setState(() {
      _nameError = nameError == null
          ? null
          : localizeFieldError(l10n, nameError);
      _phoneError = phoneError == null
          ? null
          : localizeFieldError(l10n, phoneError);
      _secretError = secretError == null
          ? null
          : localizeFieldError(l10n, secretError);
    });

    if (nameError != null || phoneError != null || secretError != null) {
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);
    await ref.read(authControllerProvider.notifier).startRegistration(
          fullName: _nameController.text,
          phone: _phoneController.text,
          secretCode: _secretController.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != AuthStatus.otpRequired &&
          next.status == AuthStatus.otpRequired &&
          next.pendingChallenge != null &&
          context.mounted) {
        context.push('/otp-verification');
      }
      if ((previous?.redirectToLoginFromRegistration ?? false) == false &&
          next.redirectToLoginFromRegistration &&
          context.mounted) {
        ref.read(authControllerProvider.notifier).clearLoginRedirect();
        context.go('/login');
      }
    });

    final auth = ref.watch(authControllerProvider);
    final formError = auth.status == AuthStatus.failure && auth.failure != null
        ? mapFailureToMessage(context, auth.failure!)
        : null;

    return AuthScaffold(
      backgroundAsset: AuthAssets.registerBackground,
      backgroundAlignment: const Alignment(0, -0.55),
      brandTopFactor: 0.05,
      top: BrandTitle(name: l10n.appName, compact: true),
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _cardSlide.value),
            child: Opacity(opacity: _cardFade.value, child: child),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            AuthCard(
              glass: true,
              bottomInset: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(
                    title: l10n.registerTitle,
                    subtitle: l10n.registerSubtitle,
                  ),
                  const SizedBox(height: 22),
                  if (_showUnregisteredHint) ...[
                    AuthInfoBanner(message: l10n.registerUnregisteredPhoneHint),
                    const SizedBox(height: 14),
                  ],
                  AuthFormErrorBanner(message: formError),
                  AppTextField(
                    controller: _nameController,
                    hintText: l10n.fullName,
                    errorText: _nameError,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.icon,
                      size: AppDimensions.iconSize,
                    ),
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  PhoneTextField(
                    controller: _phoneController,
                    errorText: _phoneError,
                    onChanged: (_) {
                      if (_phoneError != null) {
                        setState(() => _phoneError = null);
                      }
                      ref.read(authControllerProvider.notifier).clearFailure();
                    },
                  ),
                  const SizedBox(height: 12),
                  PasswordTextField(
                    controller: _secretController,
                    errorText: _secretError,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_secretError != null) {
                        setState(() => _secretError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: l10n.createAccountAction,
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.alreadyHaveAccount,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.68),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              child: CreateAccountNotch(
                label: l10n.loginAction,
                onTap: _goToLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
