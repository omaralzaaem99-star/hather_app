import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/utils/phone_auth_identifier.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps Supabase/Auth/network errors to domain [Failure].
/// Never surfaces internal emails, OTP codes, or English provider text.

/// GoTrue may dispatch OTP then throw while parsing the signup response.
bool isSignUpResponseParseFailure(Object error) {
  if (error is FormatException || error is TypeError) {
    return true;
  }
  final raw = error.toString().toLowerCase();
  return raw.contains('malformed') ||
      raw.contains('failed to parse') ||
      raw.contains('unexpected character') ||
      raw.contains('unexpected end of input') ||
      raw.contains('is not a subtype of');
}

Failure mapSupabaseError(Object error, {OtpPurpose? otpPurpose}) {
  if (error is Failure) {
    if (error is PhoneNotFoundFailure &&
        otpPurpose == OtpPurpose.registration) {
      return const InvalidOtpFailure();
    }
    if (error is ServerFailure && error.message != null) {
      final cleaned = PhoneAuthIdentifier.sanitizeUserMessage(error.message!);
      if (cleaned != error.message) {
        return ServerFailure(message: cleaned.isEmpty ? null : cleaned);
      }
    }
    return error;
  }

  if (error is FunctionException) {
    return _mapFunctionException(error, otpPurpose: otpPurpose);
  }

  if (error is AuthException) {
    return _mapAuthException(error, otpPurpose: otpPurpose);
  }

  if (error is PostgrestException) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    if (message.contains('too many login phone checks')) {
      return const TooManyRequestsFailure();
    }
    if (message.contains('could not find the function') &&
        message.contains('resolve_login_phone_status')) {
      return const ServerFailure(
        message: 'تعذر إكمال تسجيل الدخول حالياً. حاول مرة أخرى.',
      );
    }
    if (code == '23505' ||
        message.contains('duplicate') ||
        message.contains('unique')) {
      return const ServerFailure(
        message: 'تعذر إكمال العملية. جرّب تسجيل الدخول أو استعادة الرمز السري.',
      );
    }
    return const ServerFailure();
  }

  final raw = error.toString().toLowerCase();
  if (raw.contains('socket') ||
      raw.contains('network') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection')) {
    return const NetworkFailure();
  }

  return const UnknownFailure();
}

Failure _mapFunctionException(
  FunctionException error, {
  OtpPurpose? otpPurpose,
}) {
  final details = error.details;
  String? message;

  if (details is Map) {
    message = details['message']?.toString();
  } else if (details is String && details.trim().isNotEmpty) {
    message = details.trim();
  }

  final lower = (message ?? error.toString()).toLowerCase();
  final status = error.status;

  if (status == 429 ||
      lower.contains('انتظر') ||
      lower.contains('rate') ||
      lower.contains('too many')) {
    return TooManyRequestsFailure(
      message: message?.trim().isNotEmpty == true ? message!.trim() : null,
    );
  }

  if (status == 410 || lower.contains('لم يعد متاح')) {
    return const ServerFailure(
      message: 'تحديث مطلوب للتطبيق. أعد المحاولة بعد التحديث.',
    );
  }

  final cleaned = PhoneAuthIdentifier.sanitizeUserMessage(
    (message ?? '').trim(),
  );
  if (cleaned.isNotEmpty && !_looksEnglish(cleaned)) {
    return ServerFailure(message: cleaned);
  }

  return const ServerFailure();
}

Failure _mapAuthException(AuthException error, {OtpPurpose? otpPurpose}) {
  final message = error.message.toLowerCase();
  final status = error.statusCode ?? '';

  if (status == '429' || message.contains('rate limit')) {
    return const TooManyRequestsFailure();
  }

  if (_isOtpTokenMismatchMessage(message)) {
    return _mapOtpTokenMismatch(message);
  }
  if (message.contains('otp') &&
      (message.contains('invalid') ||
          message.contains('expired') ||
          message.contains('wrong'))) {
    return _mapOtpTokenMismatch(message);
  }

  if (message.contains('already registered') ||
      message.contains('already exists') ||
      message.contains('user already') ||
      message.contains('phone exists') ||
      message.contains('duplicate')) {
    // Soften enumeration on registration — handled upstream via resend when
    // the account is still pending phone verification.
    if (otpPurpose == OtpPurpose.registration) {
      return const ServerFailure(
        message:
            'تعذر إكمال التسجيل بهذا الرقم. جرّب تسجيل الدخول أو استعادة الرمز السري.',
      );
    }
    return const ServerFailure(
      message: 'تعذر إكمال العملية. جرّب تسجيل الدخول أو استعادة الرمز السري.',
    );
  }

  if (message.contains('signups not allowed') ||
      message.contains('signup is disabled') ||
      message.contains('phone signups are disabled') ||
      message.contains('phone provider is disabled')) {
    return const ServerFailure(
      message: 'تعذر إكمال التسجيل حالياً. حاول مرة أخرى لاحقاً.',
    );
  }

  if (message.contains('user not found') ||
      message.contains('unable to validate') ||
      (message.contains('create_user') && message.contains('false'))) {
    // Password-reset / OTP without creating user — do not confirm existence.
    return const ServerFailure(
      message: 'تعذر إرسال رمز التحقق. تأكد من الرقم أو حاول لاحقاً.',
    );
  }

  if (message.contains('invalid login') ||
      message.contains('invalid credentials') ||
      message.contains('invalid email or password') ||
      (message.contains('invalid') && message.contains('password'))) {
    return const InvalidCredentialsFailure();
  }

  if (message.contains('password') &&
      (message.contains('least') ||
          message.contains('short') ||
          message.contains('6'))) {
    return const ValidationFailure(
      message: 'الرمز السري يجب أن يتكون من 6 خانات على الأقل',
    );
  }

  if ((message.contains('phone') || message.contains('mobile')) &&
      (message.contains('invalid') || message.contains('format'))) {
    return const InvalidPhoneFailure();
  }

  if (message.contains('network') || message.contains('timeout')) {
    return const NetworkFailure();
  }

  return const ServerFailure();
}

bool _looksEnglish(String value) {
  final letters = value.replaceAll(RegExp(r'[^A-Za-z]'), '');
  return letters.length >= 8;
}

bool _isOtpTokenMismatchMessage(String message) {
  return message.contains('token') &&
      (message.contains('expired') || message.contains('invalid'));
}

Failure _mapOtpTokenMismatch(String message) {
  // GoTrue returns "Token has expired or is invalid" for wrong type/code too.
  if (message.contains('expired') && message.contains('invalid')) {
    return const InvalidOtpFailure();
  }
  if (message.contains('expired')) {
    return const OtpExpiredFailure();
  }
  return const InvalidOtpFailure();
}
