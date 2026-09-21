import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/notifications/notification_navigation.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';

AuthUser _user({
  AccountType type = AccountType.user,
  AccountStatus status = AccountStatus.active,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return AuthUser(
    id: 'user-1',
    fullName: 'Test User',
    phone: '+9647000000000',
    accountType: type,
    accountStatus: status,
    phoneVerified: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Captain rejection routing', () {
    test('TEST A/D: user+active routes to /home after rejection sync', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.user, status: AccountStatus.active),
        type: 'captain_rejected',
      );
      expect(location, AuthenticatedRoutes.home);
    });

    test('TEST F: captain+active routes to captain home (approval unchanged)', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'captain_approved',
      );
      expect(location, AuthenticatedRoutes.captainHome);
    });

    test('TEST G: captain suspended routes to suspended screen', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.suspended),
        type: 'captain_suspended',
      );
      expect(location, AuthenticatedRoutes.captainSuspended);
    });

    test('TEST G: captain disabled routes to disabled screen', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.disabled),
        type: 'captain_disabled',
      );
      expect(location, AuthenticatedRoutes.captainDisabled);
    });

    test('homeFor after rejection: user+active → /home', () {
      expect(
        AuthenticatedRoutes.homeFor(
          _user(type: AccountType.user, status: AccountStatus.active),
        ),
        AuthenticatedRoutes.home,
      );
    });

    test('homeFor pending captain still on pending route before refresh', () {
      expect(
        AuthenticatedRoutes.homeFor(
          _user(type: AccountType.captain, status: AccountStatus.pending),
        ),
        AuthenticatedRoutes.captainPending,
      );
    });

    test('zone leaves captainPending when profile becomes user+active', () {
      final before = AuthenticatedRoutes.zoneFor(
        _user(type: AccountType.captain, status: AccountStatus.pending),
      );
      final after = AuthenticatedRoutes.zoneFor(
        _user(type: AccountType.user, status: AccountStatus.active),
      );
      expect(before, AccountRouteZone.captainPending);
      expect(after, AccountRouteZone.user);
      expect(
        AuthenticatedRoutes.homeFor(
          _user(type: AccountType.user, status: AccountStatus.active),
        ),
        AuthenticatedRoutes.home,
      );
    });
  });
}
