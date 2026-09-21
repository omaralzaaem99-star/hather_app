import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/routing/account_access.dart';
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
  group('AccountAccess', () {
    test('active user is not restricted', () {
      expect(AccountAccess.isRestricted(_user()), isFalse);
    });

    test('disabled user is restricted', () {
      expect(
        AccountAccess.isUserBlocked(
          _user(status: AccountStatus.disabled),
        ),
        isTrue,
      );
    });

    test('suspended captain is restricted', () {
      expect(
        AccountAccess.isCaptainSuspended(
          _user(type: AccountType.captain, status: AccountStatus.suspended),
        ),
        isTrue,
      );
    });
  });

  group('AuthenticatedRoutes blocked account routing', () {
    test('TEST A: active user home route is /home', () {
      expect(AuthenticatedRoutes.homeFor(_user()), AuthenticatedRoutes.home);
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: _user(),
          location: '/splash',
        ),
        AuthenticatedRoutes.home,
      );
    });

    test('TEST B: blocked user with session routes to account blocked screen', () {
      final blocked = _user(status: AccountStatus.disabled);
      expect(
        AuthenticatedRoutes.homeFor(blocked),
        AuthenticatedRoutes.accountBlocked,
      );
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: blocked,
          location: '/home',
        ),
        AuthenticatedRoutes.accountBlocked,
      );
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: blocked,
          location: '/delivery/create-order',
        ),
        AuthenticatedRoutes.accountBlocked,
      );
    });

    test('TEST C: blocked user login destination is not home', () {
      final blocked = _user(status: AccountStatus.disabled);
      expect(
        AuthenticatedRoutes.homeFor(blocked),
        isNot(AuthenticatedRoutes.home),
      );
    });

    test('TEST D: disabled captain routes to captain disabled screen', () {
      final captain = _user(
        type: AccountType.captain,
        status: AccountStatus.disabled,
      );
      expect(
        AuthenticatedRoutes.homeFor(captain),
        AuthenticatedRoutes.captainDisabled,
      );
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: captain,
          location: AuthenticatedRoutes.captainHome,
        ),
        AuthenticatedRoutes.captainDisabled,
      );
    });

    test('TEST E: re-enabled user routes to home', () {
      final active = _user(status: AccountStatus.active);
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: active,
          location: AuthenticatedRoutes.accountBlocked,
        ),
        AuthenticatedRoutes.home,
      );
    });

    test('TEST H: suspended captain cannot access captain home', () {
      final captain = _user(
        type: AccountType.captain,
        status: AccountStatus.suspended,
      );
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: captain,
          location: AuthenticatedRoutes.captainHome,
        ),
        AuthenticatedRoutes.captainSuspended,
      );
    });
  });
}
