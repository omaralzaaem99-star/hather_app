import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/auth/domain/entities/verify_otp_result.dart';

/// Auth contract — screens never talk to Supabase/API directly.
abstract class AuthRepository {
  Future<Result<AuthSession>> signInWithPhoneAndPassword({
    required String phone,
    required String secretCode,
  });

  /// Registers account + profile without OTP (current phase).
  /// Returns an authenticated session only when Auth user + profile succeed.
  Future<Result<AuthSession>> registerAccount({
    required String fullName,
    required String phone,
    required String secretCode,
  });

  /// Starts OTP registration challenge (future phase / fake OTP tests).
  Future<Result<PendingAuthChallenge>> startRegistration({
    required String fullName,
    required String phone,
    required String secretCode,
  });

  Future<Result<PendingAuthChallenge>> sendOtp({
    required String phone,
    required OtpPurpose purpose,
  });

  Future<Result<PendingAuthChallenge>> resendOtp({required String challengeId});

  Future<Result<VerifyOtpResult>> verifyOtp({
    required String challengeId,
    required String otp,
    required OtpPurpose purpose,
    String? fullName,
    String? phone,
    String? secretCode,
    String? externalUserId,
  });

  /// Completes registration after OTP when provider needs an extra step.
  Future<Result<AuthSession>> completeRegistration({
    required String challengeId,
  });

  Future<Result<PendingAuthChallenge>> requestPasswordReset({
    required String phone,
  });

  Future<Result<void>> resetPassword({
    required String challengeId,
    required String newSecretCode,
  });

  Future<Result<bool>> checkPhoneAvailability(String phone);

  Future<Result<AuthUser?>> getCurrentUser();

  Future<Result<AuthSession?>> restoreSession();

  /// Soft refresh for app resume — never clears session on transient errors.
  Future<Result<AuthSession?>> refreshPersistedSession();

  Future<Result<AuthUser>> convertToCaptain();

  /// Reloads profile from backend while keeping the current auth session.
  Future<Result<AuthUser>> refreshProfile();

  Future<Result<void>> signOut();

  /// Permanently deletes the current authenticated account.
  Future<Result<void>> deleteMyAccount({required String password});
}
