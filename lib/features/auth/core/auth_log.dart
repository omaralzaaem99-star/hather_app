import 'package:flutter/foundation.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:hather_app/features/auth/domain/entities/phone_registration_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Safe auth diagnostics — never log secrets, tokens, or OTP.
abstract final class AuthLog {
  static void loginAttemptStart(String e164) =>
      _log('LOGIN_ATTEMPT_START', e164);

  static void loginPhoneNotRegistered(String e164) =>
      _log('LOGIN_PHONE_NOT_REGISTERED', e164);

  static void loginInvalidPassword(String e164) =>
      _log('LOGIN_INVALID_PASSWORD', e164);

  static void loginSuccess(String e164) => _log('LOGIN_SUCCESS', e164);

  static void loginResolveSkipped(String e164, {required String reason}) {
    if (!kDebugMode) return;
    debugPrint('LOGIN_RESOLVE_SKIPPED phone=${_mask(e164)} reason=$reason');
  }

  static void loginResolveRpcError(Object error) {
    if (!kDebugMode) return;
    debugPrint('LOGIN_RESOLVE_RPC_ERROR type=${error.runtimeType}');
  }

  static void otpVerifyFail(Object error) {
    if (!kDebugMode) return;
    if (error is AuthException) {
      debugPrint(
        'OTP_VERIFY_FAIL status=${error.statusCode} message=${error.message}',
      );
      return;
    }
    debugPrint('OTP_VERIFY_FAIL type=${error.runtimeType}');
  }

  static void registerStarting(String e164) {
    if (!kDebugMode) return;
    debugPrint('REGISTER: starting phone=${_mask(e164)}');
  }

  static void registerPhoneStatusChecked(
    String e164,
    PhoneRegistrationStatus status,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      'REGISTER: phone status=${status.name} phone=${_mask(e164)}',
    );
  }

  static void registerPhoneStatusRechecked(
    String e164,
    PhoneRegistrationStatus status,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      'REGISTER: phone status recheck=${status.name} phone=${_mask(e164)}',
    );
  }

  static void registerPendingVerificationResend(String e164) {
    if (!kDebugMode) return;
    debugPrint(
      'REGISTER: pending verification resend phone=${_mask(e164)}',
    );
  }

  static void registerBlockedExistingPhone(String e164) {
    if (!kDebugMode) return;
    debugPrint('REGISTER: blocked existing phone=${_mask(e164)}');
  }

  static void registerPhoneStatusRpcError(Object error) {
    if (!kDebugMode) return;
    debugPrint('REGISTER_PHONE_STATUS_RPC_ERROR type=${error.runtimeType}');
  }

  static void registerSignUpRequest(String e164) {
    if (!kDebugMode) return;
    debugPrint('REGISTER: signUp request phone=${_mask(e164)}');
  }

  static void registerSignUpSuccess(String e164) {
    if (!kDebugMode) return;
    debugPrint('REGISTER: signUp success phone=${_mask(e164)}');
  }

  static void registerSignUpAuthRecoveryRequired(Object error) {
    if (!kDebugMode) return;
    _logError('REGISTER: signUp auth recovery required', error);
  }

  static void registerSignUpParseFailure(Object error) {
    if (!kDebugMode) return;
    _logError('REGISTER: signUp parse failure', error);
  }

  static void registerAttemptingResendRecovery(String e164) {
    if (!kDebugMode) return;
    debugPrint(
      'REGISTER: attempting resend recovery phone=${_mask(e164)}',
    );
  }

  static void registerResendRecoverySuccess(String e164) {
    if (!kDebugMode) return;
    debugPrint(
      'REGISTER: resend recovery success phone=${_mask(e164)}',
    );
  }

  static void registerResendRecoveryFailed(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (!kDebugMode) return;
    _logError('REGISTER: resend recovery failed', error, stackTrace);
  }

  static void registerOtpRequiredEmitted(String e164) {
    if (!kDebugMode) return;
    debugPrint('REGISTER: otpRequired emitted phone=${_mask(e164)}');
  }

  static void registerOtpDispatched(String e164) {
    if (!kDebugMode) return;
    debugPrint('REGISTER: OTP requested/sent phone=${_mask(e164)}');
  }

  static void registerNavigatingToOtp(String e164) {
    if (!kDebugMode) return;
    debugPrint('REGISTER: navigating to OTP phone=${_mask(e164)}');
  }

  static void registerFailed(Object error, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    _logError('REGISTER: failed', error, stackTrace);
  }

  static void otpVerificationStarting(String e164) {
    if (!kDebugMode) return;
    debugPrint('OTP: verification starting phone=${_mask(e164)}');
  }

  static void otpVerificationSuccess(String e164) {
    if (!kDebugMode) return;
    debugPrint('OTP: verification success phone=${_mask(e164)}');
  }

  static void profileEnsureStarting() {
    if (!kDebugMode) return;
    debugPrint('PROFILE: ensure profile starting');
  }

  static void profileEnsureSuccess() {
    if (!kDebugMode) return;
    debugPrint('PROFILE: ensure profile success');
  }

  static void profileEnsureFailed(Object error, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    _logError('PROFILE: ensure profile failed', error, stackTrace);
  }

  static void profileLoadFailedKeepingSession() {
    if (!kDebugMode) return;
    debugPrint('PROFILE: load failed - keeping session');
  }

  static void startupStarting() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: starting');
  }

  static void startupReadingPersistedSession() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: reading persisted session');
  }

  static void startupPersistedSessionFound() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: persisted session found');
  }

  static void startupPersistedSessionMissing() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: persisted session missing');
  }

  static void startupAccessTokenExpired() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: access token expired');
  }

  static void startupRefreshingSession() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: refreshing session');
  }

  static void startupRefreshSuccess() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: refresh success');
  }

  static void startupRefreshFailed(Object error) {
    if (!kDebugMode) return;
    _logError('AUTH STARTUP: refresh failed', error);
  }

  static void startupAuthenticated() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: authenticated');
  }

  static void startupUnauthenticatedConfirmed() {
    if (!kDebugMode) return;
    debugPrint('AUTH STARTUP: unauthenticated confirmed');
  }

  static void startupKeepingCachedSession({String? reason}) {
    if (!kDebugMode) return;
    debugPrint(
      'AUTH STARTUP: keeping cached session'
      '${reason == null ? '' : ' reason=$reason'}',
    );
  }

  static void authEvent(String event) {
    if (!kDebugMode) return;
    debugPrint('AUTH EVENT: $event');
  }

  static void appResumeCheckingAuth() {
    if (!kDebugMode) return;
    debugPrint('APP RESUME: checking auth');
  }

  static void appResumeSessionValid() {
    if (!kDebugMode) return;
    debugPrint('APP RESUME: session valid');
  }

  static void appResumeRefreshRequired() {
    if (!kDebugMode) return;
    debugPrint('APP RESUME: refresh required');
  }

  static void authLogout({
    required String reason,
    required String source,
    required bool explicitUserInitiated,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'AUTH LOGOUT: reason=$reason source=$source '
      'explicit/user initiated=$explicitUserInitiated',
    );
  }

  static void _logError(String label, Object error, [StackTrace? stackTrace]) {
    debugPrint('$label type=${error.runtimeType}');
    if (error is AuthException) {
      debugPrint('message=${error.message} status=${error.statusCode}');
    } else {
      debugPrint('message=$error');
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static void _log(String event, String e164) {
    if (!kDebugMode) return;
    debugPrint('$event phone=${_mask(e164)}');
  }

  static String _mask(String e164) {
    final local = PhoneNumberFormatter.toLocalDisplay(e164) ?? e164;
    if (local.length < 7) return '***';
    return '${local.substring(0, 3)}***${local.substring(local.length - 4)}';
  }

  /// Public alias for OTP diagnostics.
  static String maskPhone(String e164) => _mask(e164);
}
