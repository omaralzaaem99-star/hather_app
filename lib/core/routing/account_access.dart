import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';

/// Server-backed account access rules for routing and guards.
class AccountAccess {
  const AccountAccess._();

  /// Regular user blocked by admin (`profiles.account_status = disabled`).
  static bool isUserBlocked(AuthUser? user) {
    if (user == null || user.accountType != AccountType.user) return false;
    return user.accountStatus == AccountStatus.disabled;
  }

  /// Captain temporarily suspended (`account_status = suspended`).
  static bool isCaptainSuspended(AuthUser? user) {
    if (user == null || user.accountType != AccountType.captain) return false;
    return user.accountStatus == AccountStatus.suspended;
  }

  /// Captain permanently disabled (`account_status = disabled`).
  static bool isCaptainDisabled(AuthUser? user) {
    if (user == null || user.accountType != AccountType.captain) return false;
    return user.accountStatus == AccountStatus.disabled;
  }

  /// Any authenticated account that must not use app features.
  static bool isRestricted(AuthUser? user) {
    return isUserBlocked(user) ||
        isCaptainSuspended(user) ||
        isCaptainDisabled(user);
  }
}
