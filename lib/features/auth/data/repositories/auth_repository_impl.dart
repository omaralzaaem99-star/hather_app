import 'package:flutter/foundation.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/storage/secure_session_storage.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/auth/core/auth_log.dart';
import 'package:hather_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/datasources/supabase_auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/models/auth_session_model.dart';
import 'package:hather_app/features/auth/data/models/login_request_model.dart';
import 'package:hather_app/features/auth/data/models/otp_request_models.dart';
import 'package:hather_app/features/auth/data/models/register_request_model.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/auth/domain/entities/login_phone_status.dart';
import 'package:hather_app/features/auth/domain/entities/restore_session_outcome.dart';
import 'package:hather_app/features/auth/domain/entities/verify_otp_result.dart';
import 'package:hather_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SessionStorage sessionStorage,
  }) : _remote = remote,
       _sessionStorage = sessionStorage;

  final AuthRemoteDataSource _remote;
  final SessionStorage _sessionStorage;

  @override
  Future<Result<AuthSession>> signInWithPhoneAndPassword({
    required String phone,
    required String secretCode,
  }) async {
    try {
      final e164 = _requireE164(phone);
      AuthLog.loginAttemptStart(e164);
      try {
        final session = await _remote.signIn(
          LoginRequestModel(phone: e164, secretCode: secretCode),
        );
        await _sessionStorage.saveSession(session);
        AuthLog.loginSuccess(e164);
        return Success(session.toEntity());
      } on InvalidCredentialsFailure {
        return _resolveFailedLogin(e164);
      } on Failure catch (failure) {
        return Err(failure);
      }
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  Future<Result<AuthSession>> _resolveFailedLogin(String e164) async {
    try {
      final status = await _remote.resolveLoginPhoneStatus(e164);
      switch (status) {
        case LoginPhoneStatus.phoneNotRegistered:
          AuthLog.loginPhoneNotRegistered(e164);
          return Err(PhoneNotRegisteredFailure(phoneE164: e164));
        case LoginPhoneStatus.phoneRegistered:
          AuthLog.loginInvalidPassword(e164);
          return const Err(InvalidPasswordFailure());
      }
    } on NetworkFailure catch (failure) {
      AuthLog.loginResolveSkipped(e164, reason: 'network');
      return Err(failure);
    } on TooManyRequestsFailure catch (failure) {
      AuthLog.loginResolveSkipped(e164, reason: 'rate_limited');
      return Err(failure);
    } on ServerFailure catch (failure) {
      AuthLog.loginResolveSkipped(e164, reason: 'server');
      return Err(failure);
    } on Failure catch (failure) {
      AuthLog.loginResolveSkipped(e164, reason: 'failure');
      return Err(failure);
    } on Object {
      AuthLog.loginResolveSkipped(e164, reason: 'unknown');
      return const Err(
        ServerFailure(message: 'حدث خطأ، حاول مرة أخرى.'),
      );
    }
  }

  @override
  Future<Result<AuthSession>> registerAccount({
    required String fullName,
    required String phone,
    required String secretCode,
  }) async {
    try {
      final e164 = _requireE164(phone);
      final session = await _remote.registerAccount(
        RegisterRequestModel(
          fullName: fullName,
          phone: e164,
          secretCode: secretCode,
        ),
      );
      await _sessionStorage.saveSession(session);
      return Success(session.toEntity());
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<PendingAuthChallenge>> startRegistration({
    required String fullName,
    required String phone,
    required String secretCode,
  }) async {
    try {
      final e164 = _requireE164(phone);
      final challenge = await _remote.startRegistration(
        RegisterRequestModel(
          fullName: fullName,
          phone: e164,
          secretCode: secretCode,
        ),
      );
      return Success(_mapChallenge(challenge));
    } on Failure catch (failure) {
      return Err(failure);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        AuthLog.registerFailed(error, stackTrace);
      }
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<PendingAuthChallenge>> sendOtp({
    required String phone,
    required OtpPurpose purpose,
  }) async {
    try {
      final e164 = _requireE164(phone);
      final challenge = await _remote.sendOtp(
        SendOtpRequestModel(phone: e164, purpose: purpose),
      );
      return Success(_mapChallenge(challenge));
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<PendingAuthChallenge>> resendOtp({
    required String challengeId,
  }) async {
    try {
      final challenge = await _remote.resendOtp(challengeId);
      return Success(_mapChallenge(challenge));
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<VerifyOtpResult>> verifyOtp({
    required String challengeId,
    required String otp,
    required OtpPurpose purpose,
    String? fullName,
    String? phone,
    String? secretCode,
    String? externalUserId,
  }) async {
    try {
      final pending =
          purpose == OtpPurpose.registration &&
              fullName != null &&
              phone != null &&
              secretCode != null
          ? RegisterRequestModel(
              fullName: fullName,
              phone: phone,
              secretCode: secretCode,
            )
          : null;

      final result = await _remote.verifyOtp(
        VerifyOtpRequestModel(
          challengeId: challengeId,
          otp: otp,
          purpose: purpose,
          pendingRegistration: pending,
          externalUserId: externalUserId,
        ),
      );
      if (result is RegistrationVerified) {
        await _sessionStorage.saveSession(
          AuthSessionModel.fromEntity(result.session),
        );
      }
      return Success(result);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<AuthSession>> completeRegistration({
    required String challengeId,
  }) async {
    // Fake path completes inside verifyOtp. Remote/Supabase may need this later.
    return const Err(
      ServerFailure(message: 'completeRegistration is handled by verifyOtp'),
    );
  }

  @override
  Future<Result<PendingAuthChallenge>> requestPasswordReset({
    required String phone,
  }) {
    return sendOtp(phone: phone, purpose: OtpPurpose.passwordReset);
  }

  @override
  Future<Result<void>> resetPassword({
    required String challengeId,
    required String newSecretCode,
  }) async {
    try {
      await _remote.resetPassword(
        ResetPasswordRequestModel(
          challengeId: challengeId,
          newSecretCode: newSecretCode,
        ),
      );
      return const Success(null);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<bool>> checkPhoneAvailability(String phone) async {
    try {
      final e164 = _requireE164(phone);
      final available = await _remote.isPhoneAvailable(e164);
      return Success(available);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<AuthUser?>> getCurrentUser() async {
    try {
      final session = await _sessionStorage.readSession();
      if (session == null || !session.isValid) {
        return const Success(null);
      }
      return Success(session.user.toEntity());
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    try {
      final cached = await _sessionStorage.readSession();
      final remote = _remote;
      if (remote is SupabaseAuthRemoteDataSource) {
        final outcome = await remote.restoreAuthSession(
          cachedUser: cached?.user,
        );
        return _mapRestoreOutcome(outcome, clearOnNoSession: true);
      }

      if (cached == null || !cached.isValid) {
        await _sessionStorage.clearSession();
        AuthLog.startupUnauthenticatedConfirmed();
        return const Success(null);
      }
      AuthLog.startupAuthenticated();
      return Success(cached.toEntity());
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        AuthLog.startupRefreshFailed(error);
        debugPrint(stackTrace.toString());
      }
      final cached = await _sessionStorage.readSession();
      if (cached != null && cached.isValid) {
        AuthLog.startupKeepingCachedSession(reason: 'restore exception');
        return Success(cached.toEntity());
      }
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<AuthSession?>> refreshPersistedSession() async {
    try {
      final cached = await _sessionStorage.readSession();
      final remote = _remote;
      if (remote is! SupabaseAuthRemoteDataSource) {
        if (cached == null || !cached.isValid) {
          return const Success(null);
        }
        return Success(cached.toEntity());
      }

      final outcome = await remote.restoreAuthSession(
        cachedUser: cached?.user,
      );
      return _mapRestoreOutcome(outcome, clearOnNoSession: false);
    } on Object {
      final cached = await _sessionStorage.readSession();
      if (cached != null && cached.isValid) {
        AuthLog.startupKeepingCachedSession(reason: 'resume refresh exception');
        return Success(cached.toEntity());
      }
      return const Err(UnknownFailure());
    }
  }

  Future<Result<AuthSession?>> _mapRestoreOutcome(
    RestoreSessionOutcome outcome, {
    required bool clearOnNoSession,
  }) async {
    switch (outcome) {
      case RestoreSessionNoSession():
        if (clearOnNoSession) {
          await _sessionStorage.clearSession();
        }
        AuthLog.startupUnauthenticatedConfirmed();
        return const Success(null);
      case RestoreSessionInvalidRefresh(:final reason):
        AuthLog.authLogout(
          reason: reason ?? 'invalid refresh token',
          source: 'auth_repository_impl.restoreSession',
          explicitUserInitiated: false,
        );
        try {
          await _remote.signOut();
        } on Failure {
          // Best effort.
        }
        await _sessionStorage.clearSession();
        AuthLog.startupUnauthenticatedConfirmed();
        return const Success(null);
      case RestoreSessionSuccess(:final session):
        await _sessionStorage.saveSession(AuthSessionModel.fromEntity(session));
        AuthLog.startupAuthenticated();
        return Success(session);
      case RestoreSessionKeepCached(:final session):
        await _sessionStorage.saveSession(AuthSessionModel.fromEntity(session));
        AuthLog.startupKeepingCachedSession();
        return Success(session);
    }
  }

  @override
  Future<Result<AuthUser>> refreshProfile() async {
    try {
      final session = await _sessionStorage.readSession();
      if (session == null || !session.isValid) {
        return const Err(UnauthorizedFailure(message: 'يلزم تسجيل الدخول'));
      }
      final remote = _remote;
      if (remote is SupabaseAuthRemoteDataSource) {
        final outcome = await remote.restoreAuthSession(
          cachedUser: session.user,
        );
        switch (outcome) {
          case RestoreSessionSuccess(:final session):
            await _sessionStorage.saveSession(
              AuthSessionModel.fromEntity(session),
            );
            return Success(session.user);
          case RestoreSessionKeepCached(:final session):
            await _sessionStorage.saveSession(
              AuthSessionModel.fromEntity(session),
            );
            AuthLog.profileLoadFailedKeepingSession();
            return Success(session.user);
          case RestoreSessionInvalidRefresh():
          case RestoreSessionNoSession():
            return const Err(
              UnauthorizedFailure(message: 'تعذر تحديث الحساب'),
            );
        }
      }
      return Success(session.user.toEntity());
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<AuthUser>> convertToCaptain() async {
    try {
      final session = await _sessionStorage.readSession();
      if (session == null || !session.isValid) {
        return const Err(UnauthorizedFailure(message: 'يلزم تسجيل الدخول'));
      }
      final updated = await _remote.convertToCaptain();
      final nextSession = AuthSessionModel(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: updated,
        expiresAt: session.expiresAt,
      );
      await _sessionStorage.saveSession(nextSession);
      return Success(updated.toEntity());
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      try {
        await _remote.signOut();
      } on Failure {
        // Still clear local session even if remote sign-out fails.
      }
      await _sessionStorage.clearSession();
      return const Success(null);
    } on Object {
      return const Err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> deleteMyAccount({required String password}) async {
    try {
      final trimmed = password.trim();
      if (trimmed.isEmpty) {
        return const Err(
          ValidationFailure(message: 'أدخل الرمز السري لتأكيد الحذف'),
        );
      }
      await _remote.deleteMyAccount(password: trimmed);
      await _sessionStorage.clearSession();
      try {
        await _remote.signOut();
      } on Object {
        // Auth user already deleted — ignore remote sign-out failures.
      }
      return const Success(null);
    } on Failure catch (failure) {
      return Err(failure);
    } on Object {
      return const Err(
        ServerFailure(
          message: 'تعذر حذف الحساب حالياً. يرجى المحاولة مرة أخرى.',
        ),
      );
    }
  }

  String _requireE164(String phone) {
    final e164 = PhoneNumberFormatter.normalizeToE164(phone);
    if (e164 == null) {
      throw const InvalidPhoneFailure();
    }
    return e164;
  }

  PendingAuthChallenge _mapChallenge(OtpChallengeDto challenge) {
    return PendingAuthChallenge(
      challengeId: challenge.challengeId,
      phone: challenge.phone,
      purpose: challenge.purpose,
      expiresAt: challenge.expiresAt,
      maskedPhone: PhoneNumberFormatter.toLocalDisplay(challenge.phone),
      externalUserId: challenge.externalUserId,
      debugOtp: challenge.debugOtp,
    );
  }
}
