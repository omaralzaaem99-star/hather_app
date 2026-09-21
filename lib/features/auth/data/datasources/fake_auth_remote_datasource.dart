import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/models/auth_session_model.dart';
import 'package:hather_app/features/auth/data/models/auth_user_model.dart';
import 'package:hather_app/features/auth/data/models/login_request_model.dart';
import 'package:hather_app/features/auth/data/models/otp_request_models.dart';
import 'package:hather_app/features/auth/data/models/register_request_model.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/login_phone_status.dart';
import 'package:hather_app/features/auth/domain/entities/phone_registration_status.dart';
import 'package:hather_app/features/auth/domain/entities/verify_otp_result.dart';
import 'package:uuid/uuid.dart';

/// Development-only authentication fallback (in-memory).
/// Does not send real SMS. Forced off in release builds via [AppConfig.useFakeAuth].
class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  FakeAuthRemoteDataSource({
    Random? random,
    Uuid? uuid,
    this.rateLimit = const Duration(seconds: 5),
    this.networkDelay = const Duration(milliseconds: 250),
  }) : _random = random ?? Random.secure(),
       _uuid = uuid ?? const Uuid();

  final Random _random;
  final Uuid _uuid;
  final Duration rateLimit;
  final Duration networkDelay;

  final Map<String, _StoredAccount> _accountsByPhone = {};
  final Map<String, RegisterRequestModel> _pendingRegistrationsByPhone = {};
  final Map<String, _StoredChallenge> _challenges = {};
  final Map<String, DateTime> _lastOtpRequestAt = {};
  String? _activeUserId;

  /// Test hook — when set, [resolveLoginPhoneStatus] throws this failure.
  Failure? resolveLoginPhoneFailure;

  /// Test-only accessor — never log or show in production UI paths blindly.
  String? lastOtpForTesting(String challengeId) =>
      _challenges[challengeId]?.otpHash == null
      ? null
      : _challenges[challengeId]?.debugOtp;

  @override
  Future<AuthSessionModel> signIn(LoginRequestModel request) async {
    await _simulateLatency();
    final account = _accountsByPhone[request.phone];
    if (account == null ||
        account.secretCodeHash != _hashSecret(request.secretCode)) {
      throw const InvalidCredentialsFailure();
    }
    return _issueSession(account.user);
  }

  @override
  Future<AuthSessionModel> registerAccount(RegisterRequestModel request) async {
    await _simulateLatency();
    if (_accountsByPhone.containsKey(request.phone)) {
      throw PhoneAlreadyExistsFailure(phoneE164: request.phone);
    }
    final now = DateTime.now().toUtc();
    final user = AuthUserModel(
      id: _uuid.v4(),
      fullName: request.fullName,
      phone: request.phone,
      accountType: AccountType.user,
      accountStatus: AccountStatus.active,
      phoneVerified: false,
      createdAt: now,
      updatedAt: now,
    );
    _accountsByPhone[request.phone] = _StoredAccount(
      user: user,
      secretCodeHash: _hashSecret(request.secretCode),
    );
    return _issueSession(user);
  }

  @override
  Future<void> signOut() async {
    await _simulateLatency();
    _activeUserId = null;
  }

  @override
  Future<void> deleteMyAccount({required String password}) async {
    await _simulateLatency();
    final id = _activeUserId;
    if (id == null) {
      throw const UnauthorizedFailure(message: 'يلزم تسجيل الدخول');
    }
    MapEntry<String, _StoredAccount>? match;
    for (final entry in _accountsByPhone.entries) {
      if (entry.value.user.id == id) {
        match = entry;
        break;
      }
    }
    if (match == null) {
      throw const UnauthorizedFailure(message: 'يلزم تسجيل الدخول');
    }
    if (_hashSecret(password) != match.value.secretCodeHash) {
      throw const InvalidCredentialsFailure(message: 'كلمة المرور غير صحيحة');
    }
    _accountsByPhone.remove(match.key);
    _activeUserId = null;
  }

  @override
  Future<OtpChallengeDto> startRegistration(
    RegisterRequestModel request,
  ) async {
    await _simulateLatency();
    final status = await checkPhoneRegistrationStatus(request.phone);
    if (status == PhoneRegistrationStatus.registered) {
      throw PhoneAlreadyExistsFailure(phoneE164: request.phone);
    }
    _enforceRateLimit(request.phone);
    if (status == PhoneRegistrationStatus.pendingVerification) {
      final pending = _pendingRegistrationsByPhone[request.phone];
      return _createChallenge(
        phone: request.phone,
        purpose: OtpPurpose.registration,
        pendingRegistration: pending ?? request,
      );
    }
    _pendingRegistrationsByPhone[request.phone] = request;
    return _createChallenge(
      phone: request.phone,
      purpose: OtpPurpose.registration,
      pendingRegistration: request,
    );
  }

  @override
  Future<OtpChallengeDto> sendOtp(SendOtpRequestModel request) async {
    await _simulateLatency();
    if (request.purpose == OtpPurpose.passwordReset &&
        !_accountsByPhone.containsKey(request.phone)) {
      throw const PhoneNotFoundFailure();
    }
    if (request.purpose == OtpPurpose.registration &&
        _accountsByPhone.containsKey(request.phone)) {
      throw const PhoneAlreadyExistsFailure();
    }
    _enforceRateLimit(request.phone);
    return _createChallenge(phone: request.phone, purpose: request.purpose);
  }

  @override
  Future<OtpChallengeDto> resendOtp(String challengeId) async {
    await _simulateLatency();
    final existing = _challenges[challengeId];
    if (existing == null) {
      throw const ServerFailure(message: 'Challenge not found');
    }
    _enforceRateLimit(existing.phone);
    return _createChallenge(
      phone: existing.phone,
      purpose: existing.purpose,
      pendingRegistration: existing.pendingRegistration,
      reuseId: challengeId,
    );
  }

  @override
  Future<VerifyOtpResult> verifyOtp(VerifyOtpRequestModel request) async {
    await _simulateLatency();
    final challenge = _challenges[request.challengeId];
    if (challenge == null) {
      throw const InvalidOtpFailure();
    }
    if (DateTime.now().toUtc().isAfter(challenge.expiresAt)) {
      _challenges.remove(request.challengeId);
      throw const OtpExpiredFailure();
    }
    if (challenge.otpHash != _hashSecret(request.otp)) {
      throw const InvalidOtpFailure();
    }

    final purpose = request.purpose;
    if (purpose == OtpPurpose.registration) {
      final pending =
          request.pendingRegistration ?? challenge.pendingRegistration;
      if (pending == null) {
        throw const ServerFailure();
      }
      if (_accountsByPhone.containsKey(pending.phone)) {
        throw const PhoneAlreadyExistsFailure();
      }
      final now = DateTime.now().toUtc();
      final user = AuthUserModel(
        id: _uuid.v4(),
        fullName: pending.fullName,
        phone: pending.phone,
        accountType: AccountType.user,
        accountStatus: AccountStatus.active,
        phoneVerified: true,
        createdAt: now,
        updatedAt: now,
      );
      _accountsByPhone[pending.phone] = _StoredAccount(
        user: user,
        secretCodeHash: _hashSecret(pending.secretCode),
      );
      _pendingRegistrationsByPhone.remove(pending.phone);
      _challenges.remove(request.challengeId);
      return RegistrationVerified(_issueSession(user).toEntity());
    }

    // Password reset: mark challenge verified; password set in resetPassword.
    _challenges[request.challengeId] = challenge.copyWith(verified: true);
    if (!_accountsByPhone.containsKey(challenge.phone)) {
      throw const PhoneNotFoundFailure();
    }
    return PasswordResetOtpVerified(
      challengeId: challenge.challengeId,
      phone: challenge.phone,
    );
  }

  @override
  Future<void> resetPassword(ResetPasswordRequestModel request) async {
    await _simulateLatency();
    final challenge = _challenges[request.challengeId];
    if (challenge == null ||
        challenge.purpose != OtpPurpose.passwordReset ||
        !challenge.verified) {
      throw const InvalidOtpFailure();
    }
    final account = _accountsByPhone[challenge.phone];
    if (account == null) {
      throw const PhoneNotFoundFailure();
    }
    _accountsByPhone[challenge.phone] = _StoredAccount(
      user: account.user.copyWith(updatedAt: DateTime.now().toUtc()),
      secretCodeHash: _hashSecret(request.newSecretCode),
    );
    _challenges.remove(request.challengeId);
  }

  @override
  Future<bool> isPhoneAvailable(String phone) async {
    await _simulateLatency();
    final status = await checkPhoneRegistrationStatus(phone);
    return status == PhoneRegistrationStatus.available;
  }

  @override
  Future<PhoneRegistrationStatus> checkPhoneRegistrationStatus(
    String phone,
  ) async {
    await _simulateLatency();
    if (_accountsByPhone.containsKey(phone)) {
      return PhoneRegistrationStatus.registered;
    }
    if (_pendingRegistrationsByPhone.containsKey(phone)) {
      return PhoneRegistrationStatus.pendingVerification;
    }
    return PhoneRegistrationStatus.available;
  }

  @override
  Future<LoginPhoneStatus> resolveLoginPhoneStatus(String phone) async {
    await _simulateLatency();
    if (resolveLoginPhoneFailure != null) {
      throw resolveLoginPhoneFailure!;
    }
    if (_accountsByPhone.containsKey(phone)) {
      return LoginPhoneStatus.phoneRegistered;
    }
    return LoginPhoneStatus.phoneNotRegistered;
  }

  @override
  Future<AuthUserModel?> getUserById(String userId) async {
    await _simulateLatency();
    for (final account in _accountsByPhone.values) {
      if (account.user.id == userId) return account.user;
    }
    return null;
  }

  @override
  Future<AuthUserModel> convertToCaptain() async {
    await _simulateLatency();
    final userId = _activeUserId;
    if (userId == null) {
      throw const UnauthorizedFailure(message: 'يلزم تسجيل الدخول');
    }

    MapEntry<String, _StoredAccount>? match;
    for (final entry in _accountsByPhone.entries) {
      if (entry.value.user.id == userId) {
        match = entry;
        break;
      }
    }
    if (match == null) {
      throw const ServerFailure(message: 'تعذر تحويل الحساب');
    }

    final updatedUser = match.value.user.copyWith(
      accountType: AccountType.captain,
      accountStatus: AccountStatus.pending,
      updatedAt: DateTime.now().toUtc(),
    );
    _accountsByPhone[match.key] = _StoredAccount(
      user: updatedUser,
      secretCodeHash: match.value.secretCodeHash,
    );
    return updatedUser;
  }

  OtpChallengeDto _createChallenge({
    required String phone,
    required OtpPurpose purpose,
    RegisterRequestModel? pendingRegistration,
    String? reuseId,
  }) {
    final challengeId = reuseId ?? _uuid.v4();
    // Random OTP — never a fixed production value like 123456.
    final otp = List.generate(
      AppConfig.otpLength,
      (_) => _random.nextInt(10),
    ).join();
    final expiresAt = DateTime.now().toUtc().add(
      const Duration(seconds: AppConfig.otpExpirySeconds),
    );

    _challenges[challengeId] = _StoredChallenge(
      challengeId: challengeId,
      phone: phone,
      purpose: purpose,
      otpHash: _hashSecret(otp),
      expiresAt: expiresAt,
      pendingRegistration: pendingRegistration,
      debugOtp: otp,
      verified: false,
    );
    _lastOtpRequestAt[phone] = DateTime.now().toUtc();

    return OtpChallengeDto(
      challengeId: challengeId,
      phone: phone,
      purpose: purpose,
      expiresAt: expiresAt,
      debugOtp: otp,
    );
  }

  void _enforceRateLimit(String phone) {
    final last = _lastOtpRequestAt[phone];
    if (last != null && DateTime.now().toUtc().difference(last) < rateLimit) {
      throw const TooManyRequestsFailure();
    }
  }

  AuthSessionModel _issueSession(AuthUserModel user) {
    final now = DateTime.now().toUtc();
    _activeUserId = user.id;
    return AuthSessionModel(
      accessToken: _uuid.v4(),
      refreshToken: _uuid.v4(),
      user: user,
      expiresAt: now.add(const Duration(days: 7)),
    );
  }

  String _hashSecret(String value) {
    // Local fake only — real secret comparison must happen on the server.
    return sha256.convert(utf8.encode(value)).toString();
  }

  Future<void> _simulateLatency() async {
    if (networkDelay > Duration.zero) {
      await Future<void>.delayed(networkDelay);
    }
  }
}

class _StoredAccount {
  const _StoredAccount({required this.user, required this.secretCodeHash});

  final AuthUserModel user;
  final String secretCodeHash;
}

class _StoredChallenge {
  const _StoredChallenge({
    required this.challengeId,
    required this.phone,
    required this.purpose,
    required this.otpHash,
    required this.expiresAt,
    required this.verified,
    this.pendingRegistration,
    this.debugOtp,
  });

  final String challengeId;
  final String phone;
  final OtpPurpose purpose;
  final String otpHash;
  final DateTime expiresAt;
  final bool verified;
  final RegisterRequestModel? pendingRegistration;
  final String? debugOtp;

  _StoredChallenge copyWith({bool? verified}) {
    return _StoredChallenge(
      challengeId: challengeId,
      phone: phone,
      purpose: purpose,
      otpHash: otpHash,
      expiresAt: expiresAt,
      verified: verified ?? this.verified,
      pendingRegistration: pendingRegistration,
      debugOtp: debugOtp,
    );
  }
}
