import 'package:equatable/equatable.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';

class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.accountType,
    required this.accountStatus,
    required this.phoneVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fullName;
  final String phone;
  final AccountType accountType;
  final AccountStatus accountStatus;
  final bool phoneVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    fullName,
    phone,
    accountType,
    accountStatus,
    phoneVerified,
    createdAt,
    updatedAt,
  ];
}

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final DateTime expiresAt;

  /// Valid while a refresh token exists or the access token is still active.
  /// Expired access alone must not force logout — Supabase can refresh.
  bool get isValid =>
      refreshToken.trim().isNotEmpty ||
      expiresAt.isAfter(DateTime.now().toUtc());

  @override
  List<Object?> get props => [accessToken, refreshToken, user, expiresAt];
}

/// Pending registration / reset flow before OTP succeeds.
class PendingAuthChallenge extends Equatable {
  const PendingAuthChallenge({
    required this.challengeId,
    required this.phone,
    required this.purpose,
    required this.expiresAt,
    this.maskedPhone,
    this.externalUserId,
    this.debugOtp,
  });

  final String challengeId;
  final String phone;
  final OtpPurpose purpose;
  final DateTime expiresAt;

  /// Local display form for UI.
  final String? maskedPhone;

  /// Unused by Phone Auth; kept for FakeAuth / DTO compatibility.
  final String? externalUserId;

  /// FakeAuth / tests only — never set on production SMS path.
  final String? debugOtp;

  @override
  List<Object?> get props => [
    challengeId,
    phone,
    purpose,
    expiresAt,
    maskedPhone,
    externalUserId,
    debugOtp,
  ];
}
