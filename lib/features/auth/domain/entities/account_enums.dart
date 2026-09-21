/// Future account roles. Registration is unified today; all new accounts are user.
enum AccountType {
  user,
  captain;

  String get wireValue => name;

  static AccountType fromWire(String value) {
    return AccountType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AccountType.user,
    );
  }
}

/// Lifecycle status for profiles (captains may start as pending later).
enum AccountStatus {
  active,
  pending,
  suspended,
  disabled;

  String get wireValue => name;

  static AccountStatus fromWire(String value) {
    return AccountStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AccountStatus.active,
    );
  }
}

/// Why an OTP was issued.
enum OtpPurpose {
  registration,
  passwordReset;

  String get wireValue => name;

  static OtpPurpose fromWire(String value) {
    return OtpPurpose.values.firstWhere(
      (item) => item.name == value,
      orElse: () => OtpPurpose.registration,
    );
  }
}
