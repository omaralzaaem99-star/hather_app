import 'package:equatable/equatable.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';

class RegisterRequestModel extends Equatable {
  const RegisterRequestModel({
    required this.fullName,
    required this.phone,
    required this.secretCode,
    this.accountType = AccountType.user,
  });

  final String fullName;
  final String phone;
  final String secretCode;

  /// Defaults to user role when no explicit role is selected in the UI.
  final AccountType accountType;

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'phone': phone,
    'secret_code': secretCode,
    'account_type': accountType.wireValue,
  };

  @override
  List<Object?> get props => [fullName, phone, secretCode, accountType];

  @override
  String toString() =>
      'RegisterRequestModel(fullName: $fullName, phone: $phone, secretCode: ***)';
}
