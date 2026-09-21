import 'package:equatable/equatable.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';

/// Result of restoring a persisted Supabase session at app startup / resume.
sealed class RestoreSessionOutcome extends Equatable {
  const RestoreSessionOutcome();
}

/// Supabase confirmed there is no persisted session.
class RestoreSessionNoSession extends RestoreSessionOutcome {
  const RestoreSessionNoSession();

  @override
  List<Object?> get props => [];
}

/// Refresh token is invalid or revoked — confirmed logout required.
class RestoreSessionInvalidRefresh extends RestoreSessionOutcome {
  const RestoreSessionInvalidRefresh({this.reason});

  final String? reason;

  @override
  List<Object?> get props => [reason];
}

/// Session restored (possibly with cached profile when offline).
class RestoreSessionSuccess extends RestoreSessionOutcome {
  const RestoreSessionSuccess(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

/// Transient failure — keep cached session, do not logout.
class RestoreSessionKeepCached extends RestoreSessionOutcome {
  const RestoreSessionKeepCached(this.session, {this.reason});

  final AuthSession session;
  final String? reason;

  @override
  List<Object?> get props => [session, reason];
}
