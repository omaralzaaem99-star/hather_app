import 'package:equatable/equatable.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';

/// Result of OTP verification — registration completes session; reset needs new code.
sealed class VerifyOtpResult extends Equatable {
  const VerifyOtpResult();
}

class RegistrationVerified extends VerifyOtpResult {
  const RegistrationVerified(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

class PasswordResetOtpVerified extends VerifyOtpResult {
  const PasswordResetOtpVerified({
    required this.challengeId,
    required this.phone,
  });

  final String challengeId;
  final String phone;

  @override
  List<Object?> get props => [challengeId, phone];
}
