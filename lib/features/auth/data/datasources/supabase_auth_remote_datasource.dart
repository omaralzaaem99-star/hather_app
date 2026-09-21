import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/features/auth/core/auth_log.dart';
import 'package:hather_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/auth_session_restore.dart';
import 'package:hather_app/features/auth/data/models/auth_session_model.dart';
import 'package:hather_app/features/auth/data/models/auth_user_model.dart';
import 'package:hather_app/features/auth/data/models/login_request_model.dart';
import 'package:hather_app/features/auth/data/models/otp_request_models.dart';
import 'package:hather_app/features/auth/data/models/register_request_model.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/login_phone_status.dart';
import 'package:hather_app/features/auth/domain/entities/phone_registration_status.dart';
import 'package:hather_app/features/auth/data/datasources/supabase_error_mapper.dart';
import 'package:hather_app/features/auth/domain/entities/restore_session_outcome.dart';
import 'package:hather_app/features/auth/domain/entities/verify_otp_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:uuid/uuid.dart';

/// Supabase Native Phone Auth remote.
///
/// Registration: signUp(phone+password) → Auth SMS Hook (OTPIQ) → verifyOTP
/// Login: signInWithPassword(phone+password)
/// Reset: signInWithOtp(shouldCreateUser:false) → verifyOTP → updateUser(password)
///
/// Never stores OTPIQ / service_role secrets. Uses Supabase Phone Auth only.
class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  SupabaseAuthRemoteDataSource({SupabaseClient? client, Uuid? uuid})
    : _client = client ?? Supabase.instance.client,
      _uuid = uuid ?? const Uuid();

  /// Phone signUp + signInWithOtp both verify with `sms` (not `signup`).
  /// See Supabase "Passwords → Signing up with phone" and "Phone login".
  static const OtpType _phoneOtpType = OtpType.sms;

  final SupabaseClient _client;
  final Uuid _uuid;

  /// Pending registration payloads keyed by challengeId (memory only).
  final Map<String, RegisterRequestModel> _pendingByChallenge = {};
  final Map<String, OtpPurpose> _purposeByChallenge = {};
  final Map<String, String> _phoneByChallenge = {};
  final Map<String, OtpType> _otpVerifyTypeByChallenge = {};

  @override
  Future<AuthSessionModel> signIn(LoginRequestModel request) async {
    try {
      final response = await _client.auth.signInWithPassword(
        phone: request.phone,
        password: request.secretCode,
      );

      final session = response.session;
      final user = response.user;
      if (session == null || user == null) {
        throw const InvalidCredentialsFailure();
      }

      final profile = await _requireProfile(user.id);
      return _sessionFromSupabase(session, profile);
    } on Object catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Direct signup without OTP — blocked for production phone flow.
  @override
  Future<AuthSessionModel> registerAccount(RegisterRequestModel request) async {
    throw const ServerFailure(
      message: 'يجب التحقق من رقم الهاتف قبل إنشاء الحساب',
    );
  }

  @override
  Future<OtpChallengeDto> startRegistration(
    RegisterRequestModel request,
  ) async {
    AuthLog.registerStarting(request.phone);
    try {
      await _clearPartialAuthSession();

      final status = await checkPhoneRegistrationStatus(request.phone);
      AuthLog.registerPhoneStatusChecked(request.phone, status);

      switch (status) {
        case PhoneRegistrationStatus.registered:
          throw PhoneAlreadyExistsFailure(phoneE164: request.phone);
        case PhoneRegistrationStatus.pendingVerification:
          AuthLog.registerPendingVerificationResend(request.phone);
          await _resendRegistrationOtpRecovery(request.phone);
          return _createRegistrationChallenge(request);
        case PhoneRegistrationStatus.available:
          return await _startRegistrationForAvailablePhone(request);
      }
    } on Object catch (error, stackTrace) {
      AuthLog.registerFailed(error, stackTrace);
      throw mapSupabaseError(error, otpPurpose: OtpPurpose.registration);
    }
  }

  Future<OtpChallengeDto> _startRegistrationForAvailablePhone(
    RegisterRequestModel request,
  ) async {
    try {
      AuthLog.registerSignUpRequest(request.phone);
      await _client.auth.signUp(
        phone: request.phone,
        password: request.secretCode,
        data: <String, dynamic>{
          'full_name': request.fullName,
        },
      );
      AuthLog.registerSignUpSuccess(request.phone);
      return _createRegistrationChallenge(request);
    } on AuthException catch (error) {
      AuthLog.registerSignUpAuthRecoveryRequired(error);
      return _recoverRegistrationAfterSignUpFailure(request, error);
    } catch (error) {
      if (!isSignUpResponseParseFailure(error)) {
        rethrow;
      }
      AuthLog.registerSignUpParseFailure(error);
      await _resendRegistrationOtpRecovery(request.phone);
      return _createRegistrationChallenge(request);
    }
  }

  Future<OtpChallengeDto> _recoverRegistrationAfterSignUpFailure(
    RegisterRequestModel request,
    AuthException error,
  ) async {
    final status = await checkPhoneRegistrationStatus(request.phone);
    AuthLog.registerPhoneStatusRechecked(request.phone, status);
    switch (status) {
      case PhoneRegistrationStatus.registered:
        throw PhoneAlreadyExistsFailure(phoneE164: request.phone);
      case PhoneRegistrationStatus.pendingVerification:
        await _resendRegistrationOtpRecovery(request.phone);
        return _createRegistrationChallenge(request);
      case PhoneRegistrationStatus.available:
        throw error;
    }
  }

  Future<void> _resendRegistrationOtpRecovery(String phone) async {
    AuthLog.registerAttemptingResendRecovery(phone);
    try {
      await _client.auth.resend(phone: phone, type: _phoneOtpType);
      AuthLog.registerResendRecoverySuccess(phone);
    } on Object catch (error, stackTrace) {
      AuthLog.registerResendRecoveryFailed(error, stackTrace);
      rethrow;
    }
  }

  OtpChallengeDto _createRegistrationChallenge(RegisterRequestModel request) {
    final challengeId = _uuid.v4();
    _pendingByChallenge[challengeId] = request;
    _purposeByChallenge[challengeId] = OtpPurpose.registration;
    _phoneByChallenge[challengeId] = request.phone;
    _otpVerifyTypeByChallenge[challengeId] = _phoneOtpType;

    return OtpChallengeDto(
      challengeId: challengeId,
      phone: request.phone,
      purpose: OtpPurpose.registration,
      expiresAt: DateTime.now().toUtc().add(
        Duration(seconds: AppConfig.otpExpirySeconds),
      ),
    );
  }

  @override
  Future<OtpChallengeDto> sendOtp(SendOtpRequestModel request) async {
    try {
      if (request.purpose != OtpPurpose.passwordReset) {
        throw const ServerFailure(message: 'طلب غير صالح');
      }

      await _client.auth.signInWithOtp(
        phone: request.phone,
        shouldCreateUser: false,
      );

      final challengeId = _uuid.v4();
      _purposeByChallenge[challengeId] = OtpPurpose.passwordReset;
      _phoneByChallenge[challengeId] = request.phone;
      _otpVerifyTypeByChallenge[challengeId] = _phoneOtpType;

      return OtpChallengeDto(
        challengeId: challengeId,
        phone: request.phone,
        purpose: OtpPurpose.passwordReset,
        expiresAt: DateTime.now().toUtc().add(
          Duration(seconds: AppConfig.otpExpirySeconds),
        ),
      );
    } on Object catch (error) {
      throw mapSupabaseError(error, otpPurpose: request.purpose);
    }
  }

  @override
  Future<OtpChallengeDto> resendOtp(String challengeId) async {
    try {
      final phone = _phoneByChallenge[challengeId];
      final purpose = _purposeByChallenge[challengeId];
      if (phone == null || purpose == null) {
        throw const ServerFailure(message: 'انتهت جلسة التحقق، ابدأ من جديد');
      }

      if (purpose == OtpPurpose.registration) {
        final pending = _pendingByChallenge[challengeId];
        if (pending == null) {
          throw const ServerFailure(message: 'انتهت جلسة التسجيل، ابدأ من جديد');
        }
        await _client.auth.resend(phone: phone, type: _phoneOtpType);
        _otpVerifyTypeByChallenge[challengeId] = _phoneOtpType;
      } else {
        await _client.auth.signInWithOtp(
          phone: phone,
          shouldCreateUser: false,
        );
        _otpVerifyTypeByChallenge[challengeId] = _phoneOtpType;
      }

      return OtpChallengeDto(
        challengeId: challengeId,
        phone: phone,
        purpose: purpose,
        expiresAt: DateTime.now().toUtc().add(
          Duration(seconds: AppConfig.otpExpirySeconds),
        ),
      );
    } on Object catch (error) {
      throw mapSupabaseError(
        error,
        otpPurpose: _purposeByChallenge[challengeId],
      );
    }
  }

  @override
  Future<VerifyOtpResult> verifyOtp(VerifyOtpRequestModel request) async {
    try {
      final purpose = request.purpose;
      final phone =
          request.pendingRegistration?.phone ??
          _phoneByChallenge[request.challengeId];
      if (phone == null || phone.isEmpty) {
        throw const ServerFailure(message: 'انتهت جلسة التحقق، ابدأ من جديد');
      }

      final otp = PhoneNumberFormatter.digitsOnly(request.otp);
      if (otp.length != AppConfig.otpLength) {
        throw const InvalidOtpFailure();
      }

      final otpType =
          _otpVerifyTypeByChallenge[request.challengeId] ?? _phoneOtpType;

      if (kDebugMode) {
        AuthLog.otpVerificationStarting(phone);
      }

      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: otpType,
      );

      final session = response.session;
      final authUser = response.user;
      if (session == null || authUser == null) {
        throw const InvalidOtpFailure();
      }

      if (purpose == OtpPurpose.registration) {
        final pending =
            request.pendingRegistration ??
            _pendingByChallenge[request.challengeId];
        if (pending == null) {
          throw const ServerFailure(
            message: 'انتهت جلسة التسجيل، ابدأ من جديد',
          );
        }

        final profile = await _ensureOwnProfile(pending.fullName);
        _clearChallenge(request.challengeId);
        AuthLog.otpVerificationSuccess(phone);
        return RegistrationVerified(
          _sessionFromSupabase(session, profile).toEntity(),
        );
      }

      // Password reset: session is now verified; password set in resetPassword.
      return PasswordResetOtpVerified(
        challengeId: request.challengeId,
        phone: phone,
      );
    } on Object catch (error) {
      if (kDebugMode) {
        AuthLog.otpVerifyFail(error);
      }
      throw mapSupabaseError(error, otpPurpose: request.purpose);
    }
  }

  @override
  Future<void> resetPassword(ResetPasswordRequestModel request) async {
    try {
      final purpose = _purposeByChallenge[request.challengeId];
      final phone = _phoneByChallenge[request.challengeId];
      if (purpose != OtpPurpose.passwordReset || phone == null) {
        throw const ServerFailure(message: 'انتهت جلسة الاستعادة، ابدأ من جديد');
      }

      final current = _client.auth.currentSession;
      if (current == null) {
        throw const UnauthorizedFailure(
          message: 'يلزم التحقق من الرمز قبل تعيين رمز سري جديد',
        );
      }

      await _client.auth.updateUser(
        UserAttributes(password: request.newSecretCode),
      );

      _clearChallenge(request.challengeId);
      await _client.auth.signOut();
    } on Object catch (error) {
      throw mapSupabaseError(error, otpPurpose: OtpPurpose.passwordReset);
    }
  }

  Future<AuthUserModel> _ensureOwnProfile(String fullName) async {
    AuthLog.profileEnsureStarting();
    try {
      final row = await _client.rpc(
        'ensure_own_profile',
        params: <String, dynamic>{'p_full_name': fullName},
      );
      if (row is Map<String, dynamic>) {
        AuthLog.profileEnsureSuccess();
        return AuthUserModel.fromJson(row);
      }
      if (row is List && row.isNotEmpty) {
        AuthLog.profileEnsureSuccess();
        return AuthUserModel.fromJson(
          Map<String, dynamic>.from(row.first as Map),
        );
      }
      throw const ServerFailure(message: 'فشل حفظ بيانات الحساب');
    } on Object catch (error, stackTrace) {
      AuthLog.profileEnsureFailed(error, stackTrace);
      throw mapSupabaseError(error);
    }
  }

  void _clearChallenge(String challengeId) {
    _pendingByChallenge.remove(challengeId);
    _purposeByChallenge.remove(challengeId);
    _phoneByChallenge.remove(challengeId);
    _otpVerifyTypeByChallenge.remove(challengeId);
  }

  Future<void> _clearPartialAuthSession() async {
    try {
      await _client.auth.signOut();
    } on Object {
      // No active session is expected before signUp / OTP.
    }
  }

  AuthSessionModel _sessionFromSupabase(Session session, AuthUserModel user) {
    final expiresAt = session.expiresAt == null
        ? DateTime.now().toUtc().add(const Duration(hours: 1))
        : DateTime.fromMillisecondsSinceEpoch(
            session.expiresAt! * 1000,
            isUtc: true,
          );

    return AuthSessionModel(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      user: user,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on Object catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> deleteMyAccount({required String password}) async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        throw const UnauthorizedFailure(message: 'يلزم تسجيل الدخول');
      }

      final response = await _client.functions.invoke(
        'delete-my-account',
        body: {'password': password},
      );

      if (response.status == 401) {
        final msg = _functionErrorMessage(response.data);
        if (msg.contains('كلمة المرور')) {
          throw InvalidCredentialsFailure(message: msg);
        }
        throw UnauthorizedFailure(
          message: msg.isEmpty ? 'انتهت الجلسة. سجّل الدخول مجدداً.' : msg,
        );
      }

      if (response.status == 409) {
        throw ServerFailure(
          message: _functionErrorMessage(response.data).isEmpty
              ? 'لا يمكن حذف الحساب أثناء وجود طلب نشط.'
              : _functionErrorMessage(response.data),
        );
      }

      if (response.status >= 400) {
        final msg = _functionErrorMessage(response.data);
        throw ServerFailure(
          message: msg.isEmpty
              ? 'تعذر حذف الحساب حالياً. يرجى المحاولة مرة أخرى.'
              : msg,
        );
      }

      final data = response.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        throw const ServerFailure(
          message: 'تعذر حذف الحساب حالياً. يرجى المحاولة مرة أخرى.',
        );
      }
    } on Failure {
      rethrow;
    } on Object catch (error) {
      throw mapSupabaseError(error);
    }
  }

  String _functionErrorMessage(Object? data) {
    if (data is Map) {
      final error = data['error'];
      if (error != null) return error.toString().trim();
      final message = data['message'];
      if (message != null) return message.toString().trim();
    }
    return '';
  }

  @override
  Future<LoginPhoneStatus> resolveLoginPhoneStatus(String phone) async {
    try {
      final raw = await _client.rpc(
        'resolve_login_phone_status',
        params: {'p_phone': phone},
      );
      final status = _parseLoginPhoneStatus(raw);
      if (status == 'PHONE_REGISTERED') {
        return LoginPhoneStatus.phoneRegistered;
      }
      if (status == 'PHONE_NOT_REGISTERED') {
        return LoginPhoneStatus.phoneNotRegistered;
      }
      if (kDebugMode) {
        debugPrint('LOGIN_RESOLVE_UNEXPECTED_STATUS raw=$raw parsed=$status');
      }
      throw const ServerFailure(
        message: 'تعذر التحقق من الرقم. حاول مرة أخرى.',
      );
    } on Object catch (error) {
      if (kDebugMode) {
        AuthLog.loginResolveRpcError(error);
        if (error is PostgrestException) {
          debugPrint(
            'LOGIN_RESOLVE_RPC detail code=${error.code} '
            'message=${error.message}',
          );
        }
      }
      throw mapSupabaseError(error);
    }
  }

  String _parseLoginPhoneStatus(Object? raw) {
    if (raw == null) return '';
    if (raw is String) {
      return raw.trim().replaceAll('"', '');
    }
    return raw.toString().trim().replaceAll('"', '');
  }

  @override
  Future<bool> isPhoneAvailable(String phone) async {
    final status = await checkPhoneRegistrationStatus(phone);
    return status == PhoneRegistrationStatus.available;
  }

  @override
  Future<PhoneRegistrationStatus> checkPhoneRegistrationStatus(
    String phone,
  ) async {
    try {
      final raw = await _client.rpc(
        'check_phone_registration_status',
        params: {'p_phone': phone},
      );
      final status = _parseRegistrationPhoneStatus(raw);
      if (status == null) {
        if (kDebugMode) {
          debugPrint(
            'REGISTER_PHONE_STATUS_UNEXPECTED raw=$raw',
          );
        }
        throw const ServerFailure(
          message: 'تعذر التحقق من الرقم. حاول مرة أخرى.',
        );
      }
      return status;
    } on Object catch (error) {
      if (kDebugMode) {
        AuthLog.registerPhoneStatusRpcError(error);
        if (error is PostgrestException) {
          debugPrint(
            'REGISTER_PHONE_STATUS_RPC detail code=${error.code} '
            'message=${error.message}',
          );
        }
      }
      throw mapSupabaseError(error, otpPurpose: OtpPurpose.registration);
    }
  }

  PhoneRegistrationStatus? _parseRegistrationPhoneStatus(Object? raw) {
    final normalized = _parseLoginPhoneStatus(raw).toLowerCase();
    return switch (normalized) {
      'available' => PhoneRegistrationStatus.available,
      'registered' => PhoneRegistrationStatus.registered,
      'pending_verification' => PhoneRegistrationStatus.pendingVerification,
      _ => null,
    };
  }

  @override
  Future<AuthUserModel?> getUserById(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return AuthUserModel.fromJson(Map<String, dynamic>.from(row));
    } on Object catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<AuthUserModel> _requireProfile(String userId) async {
    final profile = await getUserById(userId);
    if (profile == null) {
      throw const ServerFailure(
        message: 'تعذر تحميل بيانات الحساب، حاول مرة أخرى.',
      );
    }
    return profile;
  }

  @override
  Future<AuthUserModel> convertToCaptain() async {
    if (kDebugMode) {
      final hasSession = _client.auth.currentSession != null;
      final uid = _client.auth.currentUser?.id;
      debugPrint(
        'CAPTAIN_CONVERT_REQUEST_START hasSupabaseSession=$hasSession '
        'uid=${uid ?? 'null'}',
      );
    }
    try {
      final row = await _client.rpc('convert_profile_to_captain');
      if (kDebugMode) {
        debugPrint('CAPTAIN_CONVERT_RPC_SUCCESS');
      }
      if (row is Map<String, dynamic>) {
        return AuthUserModel.fromJson(row);
      }
      if (row is List && row.isNotEmpty) {
        return AuthUserModel.fromJson(
          Map<String, dynamic>.from(row.first as Map),
        );
      }
      throw const ServerFailure(message: 'تعذر تحويل الحساب');
    } on Object catch (error) {
      _logCaptainConvertRpcFailure(error);
      throw mapSupabaseError(error);
    }
  }

  void _logCaptainConvertRpcFailure(Object error) {
    if (!kDebugMode) return;
    if (error is PostgrestException) {
      debugPrint('CAPTAIN_CONVERT_RPC_FAILED');
      debugPrint('code=${error.code}');
      debugPrint('message=${error.message}');
      debugPrint('details=${error.details}');
      debugPrint('hint=${error.hint}');
      return;
    }
    debugPrint('CAPTAIN_CONVERT_RPC_FAILED');
    debugPrint('code=');
    debugPrint('message=${error.runtimeType}');
    debugPrint('details=');
    debugPrint('hint=non-postgrest');
  }

  StreamSubscription<AuthChangeEvent> subscribeAuthEvents(
    void Function(AuthChangeEvent event) handler,
  ) {
    return _client.auth.onAuthStateChange
        .map((data) => data.event)
        .listen(handler);
  }

  /// Restore session from Supabase Auth (source of truth).
  Future<RestoreSessionOutcome> restoreAuthSession({
    AuthUserModel? cachedUser,
  }) async {
    AuthLog.startupStarting();
    AuthLog.startupReadingPersistedSession();

    final initialSession = _client.auth.currentSession;
    if (initialSession == null) {
      AuthLog.startupPersistedSessionMissing();
      return const RestoreSessionNoSession();
    }
    AuthLog.startupPersistedSessionFound();

    var activeSession = initialSession;

    try {
      if (isSupabaseAccessTokenExpired(activeSession)) {
        AuthLog.startupAccessTokenExpired();
        AuthLog.startupRefreshingSession();
        final refreshed = await _client.auth.refreshSession();
        final nextSession = refreshed.session;
        if (nextSession == null) {
          AuthLog.startupRefreshFailed('null session after refresh');
          return const RestoreSessionInvalidRefresh(
            reason: 'null session after refresh',
          );
        }
        activeSession = nextSession;
        AuthLog.startupRefreshSuccess();
      }
    } on AuthException catch (error) {
      if (isInvalidRefreshTokenError(error)) {
        AuthLog.startupRefreshFailed(error);
        return RestoreSessionInvalidRefresh(reason: error.message);
      }
      if (cachedUser != null) {
        AuthLog.startupKeepingCachedSession(reason: 'refresh transient error');
        return RestoreSessionKeepCached(
          _sessionFromSupabase(activeSession, cachedUser).toEntity(),
          reason: error.message,
        );
      }
      AuthLog.startupRefreshFailed(error);
      return RestoreSessionKeepCached(
        _sessionFromSupabase(
          activeSession,
          _fallbackUserFromAuth(activeSession, cachedUser),
        ).toEntity(),
        reason: error.message,
      );
    } on Object catch (error) {
      if (isTransientAuthRestoreError(error) && cachedUser != null) {
        AuthLog.startupKeepingCachedSession(reason: 'network');
        return RestoreSessionKeepCached(
          _sessionFromSupabase(activeSession, cachedUser).toEntity(),
          reason: error.toString(),
        );
      }
      AuthLog.startupRefreshFailed(error);
      if (cachedUser != null) {
        return RestoreSessionKeepCached(
          _sessionFromSupabase(activeSession, cachedUser).toEntity(),
          reason: error.toString(),
        );
      }
      return RestoreSessionKeepCached(
        _sessionFromSupabase(
          activeSession,
          _fallbackUserFromAuth(activeSession, cachedUser),
        ).toEntity(),
        reason: error.toString(),
      );
    }

    return _loadProfileOutcome(activeSession, cachedUser);
  }

  Future<RestoreSessionOutcome> _loadProfileOutcome(
    Session session,
    AuthUserModel? cachedUser,
  ) async {
    try {
      final profile = await getUserById(session.user.id);
      if (profile != null) {
        AuthLog.startupAuthenticated();
        return RestoreSessionSuccess(
          _sessionFromSupabase(session, profile).toEntity(),
        );
      }
      AuthLog.profileLoadFailedKeepingSession();
      if (cachedUser != null) {
        return RestoreSessionSuccess(
          _sessionFromSupabase(session, cachedUser).toEntity(),
        );
      }
      return RestoreSessionSuccess(
        _sessionFromSupabase(
          session,
          _fallbackUserFromAuth(session, cachedUser),
        ).toEntity(),
      );
    } on Object catch (error) {
      AuthLog.profileLoadFailedKeepingSession();
      if (cachedUser != null) {
        AuthLog.startupKeepingCachedSession(reason: 'profile fetch');
        return RestoreSessionKeepCached(
          _sessionFromSupabase(session, cachedUser).toEntity(),
          reason: error.toString(),
        );
      }
      return RestoreSessionKeepCached(
        _sessionFromSupabase(session, _fallbackUserFromAuth(session, cachedUser))
            .toEntity(),
        reason: error.toString(),
      );
    }
  }

  AuthUserModel _fallbackUserFromAuth(
    Session session,
    AuthUserModel? cachedUser,
  ) {
    if (cachedUser != null) return cachedUser;
    final authUser = session.user;
    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    final now = DateTime.now().toUtc();
    return AuthUserModel(
      id: authUser.id,
      fullName: (metadata['full_name'] as String?)?.trim().isNotEmpty == true
          ? (metadata['full_name'] as String).trim()
          : '—',
      phone: authUser.phone ?? '',
      accountType: AccountType.user,
      accountStatus: AccountStatus.active,
      phoneVerified: authUser.phoneConfirmedAt != null,
      createdAt: authUser.createdAt.isNotEmpty
          ? DateTime.tryParse(authUser.createdAt) ?? now
          : now,
      updatedAt: now,
    );
  }
}
