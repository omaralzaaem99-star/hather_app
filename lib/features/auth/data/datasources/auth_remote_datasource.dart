import 'package:hather_app/features/auth/data/models/auth_session_model.dart';
import 'package:hather_app/features/auth/data/models/auth_user_model.dart';
import 'package:hather_app/features/auth/data/models/login_request_model.dart';
import 'package:hather_app/features/auth/data/models/otp_request_models.dart';
import 'package:hather_app/features/auth/data/models/register_request_model.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/login_phone_status.dart';
import 'package:hather_app/features/auth/domain/entities/phone_registration_status.dart';
import 'package:hather_app/features/auth/domain/entities/verify_otp_result.dart';

/// Remote auth contract. Swap Fake → Supabase without touching presentation.
abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> signIn(LoginRequestModel request);

  /// Direct registration without OTP (FakeAuth / tests only).
  Future<AuthSessionModel> registerAccount(RegisterRequestModel request);

  /// Starts Phone Auth OTP challenge (Supabase signInWithOtp / signUp).
  Future<OtpChallengeDto> startRegistration(RegisterRequestModel request);

  Future<OtpChallengeDto> sendOtp(SendOtpRequestModel request);

  Future<OtpChallengeDto> resendOtp(String challengeId);

  Future<VerifyOtpResult> verifyOtp(VerifyOtpRequestModel request);

  Future<void> resetPassword(ResetPasswordRequestModel request);

  Future<bool> isPhoneAvailable(String phone);

  /// Post failed login only — rate limited server RPC.
  Future<LoginPhoneStatus> resolveLoginPhoneStatus(String phone);

  /// Pre-registration phone probe — rate limited server RPC.
  Future<PhoneRegistrationStatus> checkPhoneRegistrationStatus(String phone);

  Future<AuthUserModel?> getUserById(String userId);

  Future<AuthUserModel> convertToCaptain();

  Future<void> signOut();

  /// Permanently deletes the authenticated account (Edge Function).
  Future<void> deleteMyAccount({required String password});
}

class OtpChallengeDto {
  const OtpChallengeDto({
    required this.challengeId,
    required this.phone,
    required this.purpose,
    required this.expiresAt,
    this.externalUserId,
    this.debugOtp,
  });

  final String challengeId;
  final String phone;
  final OtpPurpose purpose;
  final DateTime expiresAt;

  /// Unused by Phone Auth; kept for FakeAuth / DTO compatibility.
  final String? externalUserId;

  /// FakeAuth / tests only — never set on production SMS path.
  final String? debugOtp;
}
