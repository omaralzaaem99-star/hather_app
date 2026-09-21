import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/features/auth/core/auth_log.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/notifications/fcm_notification_service.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/core/utils/validators.dart';
import 'package:hather_app/features/auth/data/datasources/supabase_auth_remote_datasource.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/auth/domain/entities/login_phone_status.dart';
import 'package:hather_app/features/auth/domain/entities/pending_registration_draft.dart';
import 'package:hather_app/features/auth/domain/entities/verify_otp_result.dart';
import 'package:hather_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_state.dart';
import 'package:hather_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  StreamSubscription<AuthChangeEvent>? _supabaseAuthSub;

  @override
  AuthState build() {
    ref.keepAlive();
    ref.onDispose(() {
      unawaited(_supabaseAuthSub?.cancel());
    });
    _bindSupabaseAuthListener();
    return const AuthState();
  }

  void _bindSupabaseAuthListener() {
    if (AppConfig.useFakeAuth) return;
    final remote = ref.read(authRemoteDataSourceProvider);
    if (remote is! SupabaseAuthRemoteDataSource) return;
    _supabaseAuthSub?.cancel();
    _supabaseAuthSub = remote.subscribeAuthEvents(_onSupabaseAuthEvent);
  }

  void _onSupabaseAuthEvent(AuthChangeEvent event) {
    switch (event) {
      case AuthChangeEvent.initialSession:
        AuthLog.authEvent('initialSession');
      case AuthChangeEvent.signedIn:
        AuthLog.authEvent('signedIn');
      case AuthChangeEvent.tokenRefreshed:
        AuthLog.authEvent('tokenRefreshed');
        if (state.isAuthenticated) {
          unawaited(_syncSessionFromSupabase());
        }
      case AuthChangeEvent.userUpdated:
        AuthLog.authEvent('userUpdated');
      case AuthChangeEvent.passwordRecovery:
        AuthLog.authEvent('passwordRecovery');
      case AuthChangeEvent.signedOut:
        AuthLog.authEvent('signedOut');
        if (state.isAuthenticated) {
          AuthLog.authLogout(
            reason: 'supabase signedOut event',
            source: 'auth_controller.onAuthStateChange',
            explicitUserInitiated: false,
          );
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      case AuthChangeEvent.mfaChallengeVerified:
        AuthLog.authEvent('mfaChallengeVerified');
      case AuthChangeEvent.userDeleted:
        AuthLog.authEvent('userDeleted');
    }
  }

  Future<void> _syncSessionFromSupabase() async {
    final result = await _repository.refreshPersistedSession();
    result.when(
      success: (session) {
        if (session != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            session: session,
          );
        }
      },
      onFailure: (_) {
        AuthLog.profileLoadFailedKeepingSession();
      },
    );
  }

  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.initializing, clearFailure: true);
    final result = await _repository.restoreSession();
    result.when(
      success: (session) {
        if (session != null && session.isValid) {
          state = AuthState(status: AuthStatus.authenticated, session: session);
        } else {
          AuthLog.startupUnauthenticatedConfirmed();
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      },
      onFailure: (failure) {
        AuthLog.startupKeepingCachedSession(reason: 'restore failure');
        final cached = state.session;
        if (cached != null && cached.isValid) {
          state = AuthState(
            status: AuthStatus.authenticated,
            session: cached,
            failure: failure is Failure ? failure : const UnknownFailure(),
          );
          return;
        }
        state = AuthState(
          status: AuthStatus.unauthenticated,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
      },
    );
  }

  Future<void> onAppResumed() async {
    if (!state.isAuthenticated) return;
    AuthLog.appResumeCheckingAuth();
    final refreshed = await refreshProfile();
    if (refreshed) {
      AuthLog.appResumeSessionValid();
      return;
    }
    final session = state.session;
    if (session != null &&
        session.expiresAt.isAfter(DateTime.now().toUtc())) {
      AuthLog.appResumeSessionValid();
      return;
    }
    AuthLog.appResumeRefreshRequired();
    final result = await _repository.refreshPersistedSession();
    result.when(
      success: (refreshedSession) {
        if (refreshedSession != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            session: refreshedSession,
          );
        }
        AuthLog.appResumeSessionValid();
      },
      onFailure: (_) {
        AuthLog.profileLoadFailedKeepingSession();
      },
    );
  }

  Future<SignInResult> signIn({
    required String phone,
    required String secretCode,
  }) async {
    final phoneError = Validators.validatePhone(phone);
    final codeError = Validators.validateSecretCode(secretCode);
    if (phoneError != null || codeError != null) {
      state = state.copyWith(
        status: AuthStatus.failure,
        failure: const ValidationFailure(),
      );
      return SignInResult.failure;
    }

    state = state.copyWith(
      status: AuthStatus.loading,
      clearFailure: true,
      clearRegisterRedirect: true,
    );
    final result = await _repository.signInWithPhoneAndPassword(
      phone: phone,
      secretCode: secretCode,
    );
    return result.when(
      success: (session) {
        state = AuthState(
          status: AuthStatus.authenticated,
          session: session,
          message: 'login_success',
        );
        return SignInResult.success;
      },
      onFailure: (failure) {
        if (failure is PhoneNotRegisteredFailure) {
          final localPhone =
              PhoneNumberFormatter.toLocalDisplay(failure.phoneE164 ?? phone) ??
              phone;
          state = AuthState(
            status: AuthStatus.unauthenticated,
            registerPrefillPhoneLocal: localPhone,
            showRegisterFromLoginHint: true,
          );
          return SignInResult.phoneNotRegistered;
        }
        state = state.copyWith(
          status: AuthStatus.failure,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return SignInResult.failure;
      },
    );
  }

  void clearRegisterRedirect() {
    state = state.copyWith(clearRegisterRedirect: true);
  }

  void clearLoginRedirect() {
    state = state.copyWith(clearLoginRedirect: true);
  }

  void prepareRegisterFromLogin(String localPhone) {
    state = state.copyWith(
      registerPrefillPhoneLocal: localPhone,
      showRegisterFromLoginHint: true,
      clearFailure: true,
    );
  }

  Future<bool> registerAccount({
    required String fullName,
    required String phone,
    required String secretCode,
  }) async {
    final nameError = Validators.validateFullName(fullName);
    final phoneError = Validators.validatePhone(phone);
    final codeError = Validators.validateSecretCode(secretCode);
    if (nameError != null || phoneError != null || codeError != null) {
      state = state.copyWith(
        status: AuthStatus.failure,
        failure: const ValidationFailure(),
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, clearFailure: true);
    final result = await _repository.registerAccount(
      fullName: Validators.normalizeFullName(fullName),
      phone: phone,
      secretCode: secretCode,
    );
    return result.when(
      success: (session) {
        state = AuthState(
          status: AuthStatus.authenticated,
          session: session,
          message: 'account_created',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthStatus.failure,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return false;
      },
    );
  }

  Future<bool> startRegistration({
    required String fullName,
    required String phone,
    required String secretCode,
  }) async {
    final nameError = Validators.validateFullName(fullName);
    final phoneError = Validators.validatePhone(phone);
    final codeError = Validators.validateSecretCode(secretCode);
    if (nameError != null || phoneError != null || codeError != null) {
      state = state.copyWith(
        status: AuthStatus.failure,
        failure: const ValidationFailure(),
      );
      return false;
    }

    final normalizedName = Validators.normalizeFullName(fullName);
    final e164 = PhoneNumberFormatter.normalizeToE164(phone);
    if (e164 != null) {
      AuthLog.registerStarting(e164);
    }

    state = state.copyWith(status: AuthStatus.loading, clearFailure: true);
    final result = await _repository.startRegistration(
      fullName: normalizedName,
      phone: phone,
      secretCode: secretCode,
    );
    return result.when(
      success: (challenge) {
        AuthLog.registerOtpRequiredEmitted(challenge.phone);
        AuthLog.registerNavigatingToOtp(challenge.phone);
        state = state.copyWith(
          status: AuthStatus.otpRequired,
          pendingChallenge: challenge,
          pendingRegistration: PendingRegistrationDraft(
            fullName: normalizedName,
            phone: challenge.phone,
            secretCode: secretCode,
          ),
          clearFailure: true,
        );
        return true;
      },
      onFailure: (failure) {
        if (failure is PhoneAlreadyExistsFailure) {
          final phoneForRedirect = failure.phoneE164 ?? e164 ?? phone;
          final localPhone =
              PhoneNumberFormatter.toLocalDisplay(phoneForRedirect) ??
              phone;
          AuthLog.registerBlockedExistingPhone(failure.phoneE164 ?? e164 ?? phone);
          state = AuthState(
            status: AuthStatus.unauthenticated,
            loginPrefillPhoneLocal: localPhone,
            redirectToLoginFromRegistration: true,
            failure: failure,
          );
          return false;
        }
        if (kDebugMode) {
          debugPrint(
            'REGISTER: controller failure type=${failure.runtimeType} '
            'message=${failure is Failure ? failure.message : failure}',
          );
        }
        state = state.copyWith(
          status: AuthStatus.failure,
          failure: failure is Failure ? failure : const UnknownFailure(),
          clearPendingRegistration: true,
          clearChallenge: true,
        );
        return false;
      },
    );
  }

  Future<bool> requestPasswordReset(String phone) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      clearFailure: true,
      clearPendingRegistration: true,
    );
    final result = await _repository.requestPasswordReset(phone: phone);
    return result.when(
      success: (challenge) {
        state = state.copyWith(
          status: AuthStatus.otpRequired,
          pendingChallenge: challenge,
          clearFailure: true,
          clearPendingRegistration: true,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthStatus.failure,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return false;
      },
    );
  }

  Future<bool> resendOtp() async {
    final challengeId = state.pendingChallenge?.challengeId;
    if (challengeId == null) return false;
    state = state.copyWith(status: AuthStatus.loading, clearFailure: true);
    final result = await _repository.resendOtp(challengeId: challengeId);
    return result.when(
      success: (challenge) {
        state = state.copyWith(
          status: AuthStatus.otpRequired,
          pendingChallenge: challenge,
          clearFailure: true,
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthStatus.otpRequired,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return false;
      },
    );
  }

  Future<VerifyOtpResult?> verifyOtp(String otp) async {
    final challenge = state.pendingChallenge;
    if (challenge == null) return null;

    final purpose = challenge.purpose;
    final draft = state.pendingRegistration;

    if (purpose == OtpPurpose.registration &&
        (draft == null ||
            draft.fullName.isEmpty ||
            draft.phone.isEmpty ||
            draft.secretCode.isEmpty)) {
      state = state.copyWith(
        status: AuthStatus.otpRequired,
        failure: const ServerFailure(
          message: 'انتهت جلسة التسجيل، ابدأ من جديد',
        ),
      );
      return null;
    }

    state = state.copyWith(status: AuthStatus.loading, clearFailure: true);
    final result = await _repository.verifyOtp(
      challengeId: challenge.challengeId,
      otp: otp,
      purpose: purpose,
      fullName: draft?.fullName,
      phone: draft?.phone ?? challenge.phone,
      secretCode: draft?.secretCode,
      externalUserId: challenge.externalUserId,
    );
    return result.when(
      success: (verifyResult) {
        if (verifyResult is RegistrationVerified) {
          state = AuthState(
            status: AuthStatus.authenticated,
            session: verifyResult.session,
            message: 'account_created',
          );
        } else if (verifyResult is PasswordResetOtpVerified) {
          state = state.copyWith(
            status: AuthStatus.success,
            clearFailure: true,
            clearPendingRegistration: true,
          );
        }
        return verifyResult;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthStatus.otpRequired,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return null;
      },
    );
  }

  Future<bool> resetPassword({
    required String challengeId,
    required String newSecretCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearFailure: true);
    final result = await _repository.resetPassword(
      challengeId: challengeId,
      newSecretCode: newSecretCode,
    );
    return result.when(
      success: (_) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          message: 'password_reset_success',
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthStatus.failure,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return false;
      },
    );
  }

  Future<void> signOut() async {
    AuthLog.authLogout(
      reason: 'user requested sign out',
      source: 'auth_controller.signOut',
      explicitUserInitiated: true,
    );
    await FcmNotificationService.instance.deactivateCurrentInstallation();
    await _repository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Deletes the current account permanently. On success clears local session.
  Future<bool> deleteMyAccount({required String password}) async {
    state = state.copyWith(clearFailure: true);
    final result = await _repository.deleteMyAccount(password: password);
    return result.when(
      success: (_) {
        AuthLog.authLogout(
          reason: 'self-service account deletion',
          source: 'auth_controller.deleteMyAccount',
          explicitUserInitiated: true,
        );
        unawaited(
          FcmNotificationService.instance.deactivateCurrentInstallation(),
        );
        state = const AuthState(status: AuthStatus.unauthenticated);
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthStatus.failure,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return false;
      },
    );
  }

  Future<bool> refreshProfile() async {
    final session = state.session;
    if (session == null || !session.isValid) return false;

    state = state.copyWith(clearFailure: true);
    final result = await _repository.refreshProfile();
    return result.when(
      success: (user) {
        state = AuthState(
          status: AuthStatus.authenticated,
          session: AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            user: user,
            expiresAt: session.expiresAt,
          ),
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return false;
      },
    );
  }

  Future<bool> convertToCaptain() async {
    // Keep AuthStatus.authenticated — flipping to `loading` makes
    // isAuthenticated false and GoRouter redirects to /login, tearing down
    // MainShell mid-frame (Duplicate GlobalKey / LayoutBuilder crashes).
    state = state.copyWith(clearFailure: true);
    final result = await _repository.convertToCaptain();
    return result.when(
      success: (user) {
        final session = state.session;
        if (session == null) {
          state = state.copyWith(
            status: AuthStatus.failure,
            failure: const UnauthorizedFailure(),
          );
          return false;
        }
        state = AuthState(
          status: AuthStatus.authenticated,
          session: AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            user: user,
            expiresAt: session.expiresAt,
          ),
        );
        return true;
      },
      onFailure: (failure) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          failure: failure is Failure ? failure : const UnknownFailure(),
        );
        return false;
      },
    );
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }

  /// Keep registration draft so the form can be restored; drop OTP challenge only.
  void returnToRegistrationEdit() {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearChallenge: true,
      clearFailure: true,
    );
  }

  void leaveOtpForPhoneChange() {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearChallenge: true,
      clearFailure: true,
      clearPendingRegistration: true,
    );
  }

  void markUnauthenticated() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
