import 'package:equatable/equatable.dart';

class LoginRequestModel extends Equatable {
  const LoginRequestModel({required this.phone, required this.secretCode});

  final String phone;
  final String secretCode;

  Map<String, dynamic> toJson() => {'phone': phone, 'secret_code': secretCode};

  @override
  List<Object?> get props => [phone, secretCode];

  @override
  String toString() => 'LoginRequestModel(phone: $phone, secretCode: ***)';
}
