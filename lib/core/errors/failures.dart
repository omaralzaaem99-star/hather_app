import 'package:equatable/equatable.dart';

/// Base failure type returned by repositories instead of throwing raw exceptions.
sealed class Failure extends Equatable {
  const Failure({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message});
}

class InvalidPhoneFailure extends Failure {
  const InvalidPhoneFailure({super.message});
}

class PhoneAlreadyExistsFailure extends Failure {
  const PhoneAlreadyExistsFailure({this.phoneE164, super.message});

  final String? phoneE164;
}

class PhoneNotFoundFailure extends Failure {
  const PhoneNotFoundFailure({super.message});
}

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure({super.message});
}

class InvalidPasswordFailure extends Failure {
  const InvalidPasswordFailure({super.message});
}

class PhoneNotRegisteredFailure extends Failure {
  const PhoneNotRegisteredFailure({this.phoneE164, super.message});

  final String? phoneE164;
}

class InvalidOtpFailure extends Failure {
  const InvalidOtpFailure({super.message});
}

class OtpExpiredFailure extends Failure {
  const OtpExpiredFailure({super.message});
}

class TooManyRequestsFailure extends Failure {
  const TooManyRequestsFailure({super.message});
}

class ServerFailure extends Failure {
  const ServerFailure({super.message});
}

class ValidationFailure extends Failure {
  const ValidationFailure({super.message});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message});
}
