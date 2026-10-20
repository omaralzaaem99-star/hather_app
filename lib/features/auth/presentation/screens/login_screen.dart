import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/routing/authenticated_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/localization_helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../core/test_auth_credentials.dart';
import '../../../../core/widgets/auth_header.dart';
import '../../../../core/widgets/error_message.dart';
import '../../../../core/widgets/password_text_field.dart';
import '../../../../core/widgets/phone_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/login_phone_status.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/create_account_notch.dart';
import '../../../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _secretController = TextEditingController();
  String? _phoneError;
  String? _secretError;
  bool _submitting = false;

  late final AnimationController _entryController;
  late final Animation<double> _cardSlide;
  late final Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    if (auth.loginPrefillPhoneLocal != null) {
      _phoneController.text = auth.loginPrefillPhoneLocal!;
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
    _phoneController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final phoneError = Validators.validatePhone(_phoneController.text);
    final secretError = Validators.validateSecretCode(_secretController.text);

    setState(() {
      _phoneError = phoneError == null
          ? null
          : localizeFieldError(l10n, phoneError);
      _secretError = secretError == null
          ? null
          : localizeFieldError(l10n, secretError);
    });

    if (phoneError != null || secretError != null) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .signIn(
          phone: _phoneController.text,
          secretCode: _secretController.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case SignInResult.success:
        final user = ref.read(authControllerProvider).user;
        context.go(AuthenticatedRoutes.homeFor(user));
      case SignInResult.phoneNotRegistered:
        context.push('/register');
      case SignInResult.failure:
        break;
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
      top: _LoginBrandHeader(appName: l10n.appName),
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
                    greeting: l10n.welcomeBack,
                    title: l10n.loginTitle,
                  ),
                  const SizedBox(height: 22),

                  AuthFormErrorBanner(message: formError),
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
                      ref.read(authControllerProvider.notifier).clearFailure();
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.forgotSecretCode,
                        style: AppTextStyles.link.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: l10n.loginAction,
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                  // if (!kReleaseMode) ...[
                  //   const SizedBox(height: 6),
                  //   Center(
                  //     child: TextButton.icon(
                  //       onPressed: () {
                  //         setState(() {
                  //           _phoneController.text = TestAuthCredentials.phoneLocal;
                  //           _secretController.text = TestAuthCredentials.defaultPassword;
                  //           _phoneError = null;
                  //           _secretError = null;
                  //         });
                  //         ref.read(authControllerProvider.notifier).clearFailure();
                  //       },
                  //       icon: const Icon(Icons.bolt, size: 16, color: AppColors.primary),
                  //       label: const Text(
                  //         'تعبئة حساب الاختبار (07742150942)',
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w600,
                  //           color: AppColors.primary,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ],
                  const SizedBox(height: 10),
                  Text(
                    l10n.noAccount,
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
                label: l10n.createAccount,
                onTap: () {
                  ref
                      .read(authControllerProvider.notifier)
                      .clearRegisterRedirect();
                  context.push('/register');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBrandHeader extends StatelessWidget {
  const _LoginBrandHeader({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/home/login_logo.png',
          height: 120,
          width: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        Text(
          appName,
          style: AppTextStyles.brandTitle.copyWith(
            color: AppColors.onPrimary,
            fontSize: 28,
            shadows: const [],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
