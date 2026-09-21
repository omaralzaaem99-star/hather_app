import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/localization_helpers.dart';
import 'package:hather_app/core/widgets/error_message.dart';
import 'package:hather_app/core/widgets/auth_header.dart';
import 'package:hather_app/core/widgets/otp_input.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/verify_otp_result.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_state.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Dedicated OTP screen — flat page, no nested card/panel.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpKey = GlobalKey<OtpInputState>();
  String _otp = '';
  String? _otpError;
  bool _submitting = false;
  bool _resending = false;
  bool _missingChallengeRedirectScheduled = false;
  int _secondsLeft = AppConfig.otpResendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConfig.otpResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _verify([String? code]) async {
    final l10n = AppLocalizations.of(context);
    final value = code ?? _otp;
    if (value.length != AppConfig.otpLength) {
      setState(() => _otpError = l10n.errorOtpIncomplete);
      return;
    }
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _otpError = null;
    });

    final result = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(value);
    if (!mounted) return;

    if (result is RegistrationVerified) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.accountCreatedSuccess)),
      );
      return;
    }

    if (result is PasswordResetOtpVerified) {
      setState(() => _submitting = false);
      final challengeId = result.challengeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/reset-password', extra: challengeId);
      });
      return;
    }

    final failure = ref.read(authControllerProvider).failure;
    setState(() {
      _submitting = false;
      if (failure != null) {
        _otpError = mapFailureToMessage(context, failure);
        _otp = '';
      }
    });
    if (failure != null) {
      // Clear digits without notifying — otherwise onChanged wipes the error.
      _otpKey.currentState?.clear(notifyChanged: false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    final ok = await ref.read(authControllerProvider.notifier).resendOtp();
    if (!mounted) return;
    setState(() => _resending = false);
    if (ok) {
      _otpKey.currentState?.clear();
      _otp = '';
      _startTimer();
    }
  }

  void _onChangePhone(OtpPurpose purpose) {
    if (purpose == OtpPurpose.passwordReset) {
      ref.read(authControllerProvider.notifier).leaveOtpForPhoneChange();
      context.go('/forgot-password');
    } else {
      ref.read(authControllerProvider.notifier).returnToRegistrationEdit();
      context.go('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final challenge = auth.pendingChallenge;
    final purpose = challenge?.purpose ?? OtpPurpose.registration;
    final phoneDisplay = challenge?.maskedPhone ?? challenge?.phone ?? '';
    final formError =
        auth.status == AuthStatus.otpRequired && auth.failure != null
        ? mapFailureToMessage(context, auth.failure!)
        : null;

    if (challenge == null &&
        !auth.isAuthenticated &&
        !_missingChallengeRedirectScheduled) {
      _missingChallengeRedirectScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = ref.read(authControllerProvider);
        if (!latest.isAuthenticated && latest.pendingChallenge == null) {
          context.go('/login');
        }
      });
    }

    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: KeyboardDismisser(
        child: SafeArea(
          child: ScrollConfiguration(
            behavior: const _OtpScrollBehavior(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppDimensions.authHorizontalMargin,
                8,
                AppDimensions.authHorizontalMargin,
                24 + (keyboard > 0 ? 8 : 0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  BrandTitle(name: l10n.appName, compact: true),
                  const SizedBox(height: 40),
                  Text(
                    l10n.otpTitle,
                    style: AppTextStyles.screenTitle.copyWith(
                      fontSize: 28,
                      shadows: const [],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.otpSubtitle,
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  if (phoneDisplay.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      phoneDisplay,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 18,
                        letterSpacing: 0.6,
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                  if (AppConfig.showDevAuthUi && challenge?.debugOtp != null) ...[
                    const SizedBox(height: AppDimensions.spaceMd),
                    Text(
                      '${l10n.devOtpHint} ${challenge!.debugOtp}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.icon,
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                  const SizedBox(height: 36),
                  AuthFormErrorBanner(message: formError ?? _otpError),
                  OtpInput(
                    key: _otpKey,
                    enabled: !_submitting,
                    errorText: formError ?? _otpError,
                    onChanged: (value) {
                      _otp = value;
                      // Only clear the wrong-code state once the user types again.
                      if (value.isNotEmpty) {
                        if (_otpError != null) {
                          setState(() => _otpError = null);
                        }
                        ref
                            .read(authControllerProvider.notifier)
                            .clearFailure();
                      }
                    },
                    onCompleted: _verify,
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: l10n.verifyAction,
                    isLoading: _submitting,
                    onPressed: () => _verify(),
                  ),
                  const SizedBox(height: 20),
                  if (_secondsLeft > 0)
                    Text(
                      l10n.resendOtpAfter(_secondsLeft),
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    )
                  else
                    TextButton(
                      onPressed: _resending ? null : _resend,
                      child: _resending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              l10n.resendOtp,
                              style: AppTextStyles.link.copyWith(
                                color: AppColors.icon,
                              ),
                            ),
                    ),
                  TextButton(
                    onPressed: () => _onChangePhone(purpose),
                    child: Text(
                      l10n.changePhoneNumber,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpScrollBehavior extends ScrollBehavior {
  const _OtpScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
