import 'package:equatable/equatable.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';

class AuthUserModel extends Equatable {
  const AuthUserModel({
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

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      accountType: AccountType.fromWire(json['account_type'] as String),
      accountStatus: AccountStatus.fromWire(json['account_status'] as String),
      phoneVerified: json['phone_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'account_type': accountType.wireValue,
      'account_status': accountStatus.wireValue,
      'phone_verified': phoneVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AuthUser toEntity() {
    return AuthUser(
      id: id,
      fullName: fullName,
      phone: phone,
      accountType: accountType,
      accountStatus: accountStatus,
      phoneVerified: phoneVerified,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory AuthUserModel.fromEntity(AuthUser user) {
    return AuthUserModel(
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      accountType: user.accountType,
      accountStatus: user.accountStatus,
      phoneVerified: user.phoneVerified,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  AuthUserModel copyWith({
    String? id,
    String? fullName,
    String? phone,
    AccountType? accountType,
    AccountStatus? accountStatus,
    bool? phoneVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuthUserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      accountType: accountType ?? this.accountType,
      accountStatus: accountStatus ?? this.accountStatus,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
