import 'package:equatable/equatable.dart';
import 'package:hather_app/features/auth/data/models/auth_user_model.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';

class AuthSessionModel extends Equatable {
  const AuthSessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUserModel user;
  final DateTime expiresAt;

  /// Valid while a refresh token exists or the access token is still active.
  bool get isValid =>
      refreshToken.trim().isNotEmpty ||
      expiresAt.isAfter(DateTime.now().toUtc());

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': user.toJson(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  AuthSession toEntity() {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user.toEntity(),
      expiresAt: expiresAt,
    );
  }

  factory AuthSessionModel.fromEntity(AuthSession session) {
    return AuthSessionModel(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: AuthUserModel.fromEntity(session.user),
      expiresAt: session.expiresAt,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, user, expiresAt];
}
