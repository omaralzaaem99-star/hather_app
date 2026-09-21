import 'package:equatable/equatable.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/auth/domain/entities/pending_registration_draft.dart';

enum AuthStatus {
  initial,
  initializing,
  loading,
  success,
  failure,
  otpRequired,
  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.pendingChallenge,
    this.pendingRegistration,
    this.failure,
    this.message,
    this.registerPrefillPhoneLocal,
    this.showRegisterFromLoginHint = false,
    this.loginPrefillPhoneLocal,
    this.redirectToLoginFromRegistration = false,
  });

  final AuthStatus status;
  final AuthSession? session;
  final PendingAuthChallenge? pendingChallenge;

  /// Kept across OTP navigation for registration completion.
  final PendingRegistrationDraft? pendingRegistration;
  final Failure? failure;
  final String? message;

  /// Local-display phone prefilled when redirected from login.
  final String? registerPrefillPhoneLocal;

  /// Info banner on register when user came from unregistered login attempt.
  final bool showRegisterFromLoginHint;

  /// Local-display phone prefilled when redirected from registration.
  final String? loginPrefillPhoneLocal;

  /// Navigate to login after blocked duplicate registration.
  final bool redirectToLoginFromRegistration;

  AuthUser? get user => session?.user;

  /// True while startup session restore has not finished.
  bool get isAuthResolving =>
      status == AuthStatus.initial || status == AuthStatus.initializing;

  /// True when a valid session exists and the user has not been signed out.
  ///
  /// In-session ops may briefly set [AuthStatus.loading]; treating that as
  /// logged-out would make GoRouter tear down [MainShell] mid-frame.
  bool get isAuthenticated {
    final current = session;
    if (current == null || !current.isValid) return false;
    return switch (status) {
      AuthStatus.authenticated ||
      AuthStatus.loading ||
      AuthStatus.success ||
      AuthStatus.failure =>
        true,
      AuthStatus.initial ||
      AuthStatus.initializing ||
      AuthStatus.unauthenticated ||
      AuthStatus.otpRequired =>
        false,
    };
  }

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    PendingAuthChallenge? pendingChallenge,
    PendingRegistrationDraft? pendingRegistration,
    Failure? failure,
    String? message,
    String? registerPrefillPhoneLocal,
    bool? showRegisterFromLoginHint,
    String? loginPrefillPhoneLocal,
    bool? redirectToLoginFromRegistration,
    bool clearFailure = false,
    bool clearChallenge = false,
    bool clearPendingRegistration = false,
    bool clearSession = false,
    bool clearMessage = false,
    bool clearRegisterRedirect = false,
    bool clearLoginRedirect = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : session ?? this.session,
      pendingChallenge: clearChallenge
          ? null
          : pendingChallenge ?? this.pendingChallenge,
      pendingRegistration: clearPendingRegistration
          ? null
          : pendingRegistration ?? this.pendingRegistration,
      failure: clearFailure ? null : failure ?? this.failure,
      message: clearMessage ? null : message ?? this.message,
      registerPrefillPhoneLocal: clearRegisterRedirect
          ? null
          : registerPrefillPhoneLocal ?? this.registerPrefillPhoneLocal,
      showRegisterFromLoginHint: clearRegisterRedirect
          ? false
          : showRegisterFromLoginHint ?? this.showRegisterFromLoginHint,
      loginPrefillPhoneLocal: clearLoginRedirect
          ? null
          : loginPrefillPhoneLocal ?? this.loginPrefillPhoneLocal,
      redirectToLoginFromRegistration: clearLoginRedirect
          ? false
          : redirectToLoginFromRegistration ??
              this.redirectToLoginFromRegistration,
    );
  }

  @override
  List<Object?> get props => [
    status,
    session,
    pendingChallenge,
    pendingRegistration,
    failure,
    message,
    registerPrefillPhoneLocal,
    showRegisterFromLoginHint,
    loginPrefillPhoneLocal,
    redirectToLoginFromRegistration,
  ];
}
