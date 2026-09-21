import 'package:equatable/equatable.dart';
import 'package:hather_app/features/auth/data/models/register_request_model.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';

class SendOtpRequestModel extends Equatable {
  const SendOtpRequestModel({required this.phone, required this.purpose});

  final String phone;
  final OtpPurpose purpose;

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'purpose': purpose.wireValue,
  };

  @override
  List<Object?> get props => [phone, purpose];
}

class VerifyOtpRequestModel extends Equatable {
  const VerifyOtpRequestModel({
    required this.challengeId,
    required this.otp,
    required this.purpose,
    this.pendingRegistration,
    this.externalUserId,
  });

  final String challengeId;
  final String otp;
  final OtpPurpose purpose;

  /// Required for [OtpPurpose.registration] so Auth+Profile can be created
  /// even if in-memory datasource state was cleared.
  final RegisterRequestModel? pendingRegistration;

  /// Unused by Phone Auth; kept for FakeAuth / DTO compatibility.
  final String? externalUserId;

  Map<String, dynamic> toJson() => {
    'challenge_id': challengeId,
    'otp': otp,
    'purpose': purpose.wireValue,
  };

  @override
  List<Object?> get props => [
    challengeId,
    otp,
    purpose,
    pendingRegistration,
    externalUserId,
  ];

  @override
  String toString() =>
      'VerifyOtpRequestModel(challengeId: $challengeId, purpose: $purpose, otp: ***)';
}

class ResetPasswordRequestModel extends Equatable {
  const ResetPasswordRequestModel({
    required this.challengeId,
    required this.newSecretCode,
  });

  final String challengeId;
  final String newSecretCode;

  Map<String, dynamic> toJson() => {
    'challenge_id': challengeId,
    'new_secret_code': newSecretCode,
  };

  @override
  List<Object?> get props => [challengeId, newSecretCode];

  @override
  String toString() =>
      'ResetPasswordRequestModel(challengeId: $challengeId, newSecretCode: ***)';
}
