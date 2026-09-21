import 'package:hather_app/core/routing/account_access.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';

enum AccountRouteZone {
  user,
  userDisabled,
  captainPending,
  captainActive,
  captainSuspended,
  captainDisabled,
  unknown,
}

/// Post-auth navigation targets based on profile state.
class AuthenticatedRoutes {
  const AuthenticatedRoutes._();

  static const captainPending = '/captain-pending';
  static const captainHome = '/captain/home';
  static const captainOrders = '/captain/orders';
  static const captainAccount = '/captain/account';
  static const captainAvailableOrderBase = '/captain/available-orders';
  static const captainSuspended = '/captain-suspended';
  static const captainDisabled = '/captain-disabled';
  static const accountBlocked = '/account-blocked';

  static String captainAvailableOrderPath(String orderId) =>
      '$captainAvailableOrderBase/$orderId';
  static const home = '/home';
  static const privacyPolicy = '/privacy-policy';
  static const terms = '/terms';
  static const about = '/about';
  static const support = '/support';
  static const supportFormBase = '/support/forms';
  static const supportRequestBase = '/support/requests';

  static String supportFormPath(String formId) => '$supportFormBase/$formId';
  static String supportRequestPath(String requestId) =>
      '$supportRequestBase/$requestId';

  /// Readable without login (and for future register consent links).
  static bool isPublicLegalRoute(String location) {
    return location == privacyPolicy || location == terms;
  }

  static bool isSharedInfoRoute(String location) {
    return location == about ||
        location == support ||
        location.startsWith('$supportFormBase/') ||
        location.startsWith('$supportRequestBase/');
  }

  static AccountRouteZone zoneFor(AuthUser? user) {
    if (user == null) return AccountRouteZone.unknown;
    if (user.accountType == AccountType.user) {
      if (AccountAccess.isUserBlocked(user)) {
        return AccountRouteZone.userDisabled;
      }
      return AccountRouteZone.user;
    }
    return switch (user.accountStatus) {
      AccountStatus.pending => AccountRouteZone.captainPending,
      AccountStatus.active => AccountRouteZone.captainActive,
      AccountStatus.suspended => AccountRouteZone.captainSuspended,
      AccountStatus.disabled => AccountRouteZone.captainDisabled,
    };
  }

  static bool isCaptainPending(AuthUser? user) {
    return zoneFor(user) == AccountRouteZone.captainPending;
  }

  static bool isCaptainActive(AuthUser? user) {
    return zoneFor(user) == AccountRouteZone.captainActive;
  }

  static String homeFor(AuthUser? user) {
    return switch (zoneFor(user)) {
      AccountRouteZone.captainPending => captainPending,
      AccountRouteZone.captainActive => captainHome,
      AccountRouteZone.captainSuspended => captainSuspended,
      AccountRouteZone.captainDisabled => captainDisabled,
      AccountRouteZone.userDisabled => accountBlocked,
      _ => home,
    };
  }

  static bool isUserShellRoute(String location) {
    return location == home ||
        location == '/orders' ||
        location == '/account' ||
        location == '/notifications' ||
        location.startsWith('/delivery');
  }

  static bool isCaptainShellRoute(String location) {
    return location == captainHome ||
        location == captainOrders ||
        location == captainAccount;
  }

  static bool isAccountRestrictedRoute(String location) {
    return location == accountBlocked ||
        location == captainSuspended ||
        location == captainDisabled;
  }

  static bool isCaptainRestrictedRoute(String location) {
    return isCaptainShellRoute(location) ||
        location.startsWith('$captainAvailableOrderBase/') ||
        location == captainPending ||
        isAccountRestrictedRoute(location);
  }

  static bool isAuthRoute(String location) {
    return location == '/login' ||
        location == '/register' ||
        location == '/otp-verification' ||
        location == '/forgot-password' ||
        location == '/reset-password';
  }

  /// Redirect target for an authenticated user, or `null` to stay put.
  static String? redirectForAuthenticated({
    required AuthUser? user,
    required String location,
  }) {
    // Privacy / Terms stay reachable in every account zone (and when logged out).
    if (isPublicLegalRoute(location)) return null;

    final zone = zoneFor(user);
    final onSplash = location == '/splash';
    final onAuth = isAuthRoute(location);

    switch (zone) {
      case AccountRouteZone.captainPending:
        if (location == captainPending) return null;
        return captainPending;

      case AccountRouteZone.captainActive:
        if (location == captainPending ||
            location == captainSuspended ||
            location == captainDisabled) {
          return captainHome;
        }
        if (isUserShellRoute(location) && location != '/notifications') {
          return captainHome;
        }
        if (isCaptainShellRoute(location) ||
            isSharedInfoRoute(location) ||
            location.startsWith('$captainAvailableOrderBase/')) {
          return null;
        }
        if (onSplash || onAuth) return captainHome;
        return null;

      case AccountRouteZone.captainSuspended:
        if (location == captainSuspended) return null;
        return captainSuspended;

      case AccountRouteZone.captainDisabled:
        if (location == captainDisabled) return null;
        return captainDisabled;

      case AccountRouteZone.userDisabled:
        if (location == accountBlocked) return null;
        return accountBlocked;

      case AccountRouteZone.user:
        if (isCaptainRestrictedRoute(location)) return home;
        if (location == accountBlocked) return home;
        if (isUserShellRoute(location) || isSharedInfoRoute(location)) {
          return null;
        }
        if (onSplash || onAuth) return home;
        return null;

      case AccountRouteZone.unknown:
        if (onSplash || onAuth) return home;
        return null;
    }
  }
}
