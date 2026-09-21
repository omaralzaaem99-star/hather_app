import 'package:equatable/equatable.dart';

/// Registration form payload kept while the user is on the OTP screen.
class PendingRegistrationDraft extends Equatable {
  const PendingRegistrationDraft({
    required this.fullName,
    required this.phone,
    required this.secretCode,
  });

  final String fullName;
  final String phone;
  final String secretCode;

  @override
  List<Object?> get props => [fullName, phone, secretCode];

  @override
  String toString() =>
      'PendingRegistrationDraft(fullName: $fullName, phone: $phone, secretCode: ***)';
}
