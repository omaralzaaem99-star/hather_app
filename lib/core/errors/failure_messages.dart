import 'package:flutter/widgets.dart';
import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/utils/phone_auth_identifier.dart';
import 'package:hather_app/l10n/app_localizations.dart';

/// Maps domain failures to localized Arabic messages.
String mapFailureToMessage(BuildContext context, Failure failure) {
  final l10n = AppLocalizations.of(context);

  final raw = switch (failure) {
    InvalidCredentialsFailure() => l10n.errorInvalidCredentials,
    InvalidPasswordFailure() => l10n.errorInvalidPassword,
    PhoneAlreadyExistsFailure() => l10n.errorPhoneAlreadyExists,
    PhoneNotFoundFailure() => l10n.errorPhoneNotFound,
    PhoneNotRegisteredFailure() => l10n.registerUnregisteredPhoneHint,
    InvalidOtpFailure() => l10n.errorInvalidOtp,
    OtpExpiredFailure() => l10n.errorOtpExpired,
    NetworkFailure() => sanitizeFailureMessage(
        failure.message,
        context: BackendErrorContext.generic,
        isNetwork: true,
      ),
    TooManyRequestsFailure() => l10n.errorTooManyRequests,
    InvalidPhoneFailure() => l10n.errorPhoneInvalid,
    ServerFailure() => sanitizeFailureMessage(
        failure.message,
        context: BackendErrorContext.generic,
      ),
    ValidationFailure() => sanitizeFailureMessage(
        failure.message,
        context: BackendErrorContext.generic,
      ),
    UnauthorizedFailure() => sanitizeFailureMessage(
        failure.message,
        context: BackendErrorContext.generic,
      ),
    UnknownFailure() => sanitizeFailureMessage(
        failure.message,
        context: BackendErrorContext.generic,
      ),
  };

  return PhoneAuthIdentifier.sanitizeUserMessage(raw);
}
