import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';

void main() {
  AuthUser user({
    AccountType type = AccountType.user,
    AccountStatus status = AccountStatus.active,
  }) {
    final now = DateTime.now().toUtc();
    return AuthUser(
      id: 'u1',
      fullName: 'Test',
      phone: '+9647700000000',
      accountType: type,
      accountStatus: status,
      phoneVerified: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('homeFor routes by account zone', () {
    expect(
      AuthenticatedRoutes.homeFor(
        user(type: AccountType.captain, status: AccountStatus.pending),
      ),
      '/captain-pending',
    );
    expect(
      AuthenticatedRoutes.homeFor(
        user(type: AccountType.captain, status: AccountStatus.active),
      ),
      '/captain/home',
    );
    expect(
      AuthenticatedRoutes.homeFor(
        user(type: AccountType.user, status: AccountStatus.active),
      ),
      '/home',
    );
    expect(
      AuthenticatedRoutes.homeFor(
        user(type: AccountType.captain, status: AccountStatus.suspended),
      ),
      '/captain-suspended',
    );
    expect(
      AuthenticatedRoutes.homeFor(
        user(type: AccountType.captain, status: AccountStatus.disabled),
      ),
      '/captain-disabled',
    );
  });

  test('redirectForAuthenticated isolates captain pending', () {
    final pending = user(
      type: AccountType.captain,
      status: AccountStatus.pending,
    );

    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: pending,
        location: '/home',
      ),
      '/captain-pending',
    );
    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: pending,
        location: '/captain-pending',
      ),
      isNull,
    );
  });

  test('redirectForAuthenticated separates captain active from user shell', () {
    final activeCaptain = user(
      type: AccountType.captain,
      status: AccountStatus.active,
    );
    final activeUser = user();

    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: activeCaptain,
        location: '/captain-pending',
      ),
      '/captain/home',
    );
    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: activeCaptain,
        location: '/splash',
      ),
      '/captain/home',
    );
    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: activeCaptain,
        location: '/home',
      ),
      '/captain/home',
    );
    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: activeCaptain,
        location: '/captain/home',
      ),
      isNull,
    );
    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: activeUser,
        location: '/captain/home',
      ),
      '/home',
    );
  });

  test('redirectForAuthenticated keeps suspended/disabled off user home', () {
    final suspended = user(
      type: AccountType.captain,
      status: AccountStatus.suspended,
    );
    final disabled = user(
      type: AccountType.captain,
      status: AccountStatus.disabled,
    );

    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: suspended,
        location: '/home',
      ),
      '/captain-suspended',
    );
    expect(
      AuthenticatedRoutes.redirectForAuthenticated(
        user: disabled,
        location: '/home',
      ),
      '/captain-disabled',
    );
  });

  test('redirectForAuthenticated allows shared legal routes for user and captain', () {
    final activeCaptain = user(
      type: AccountType.captain,
      status: AccountStatus.active,
    );
    final activeUser = user();

    for (final route in [
      AuthenticatedRoutes.privacyPolicy,
      AuthenticatedRoutes.terms,
      AuthenticatedRoutes.about,
      AuthenticatedRoutes.support,
    ]) {
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: activeCaptain,
          location: route,
        ),
        isNull,
      );
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: activeUser,
          location: route,
        ),
        isNull,
      );
    }
  });

  test('public legal routes stay open for restricted account zones', () {
    final pending = user(
      type: AccountType.captain,
      status: AccountStatus.pending,
    );
    final suspended = user(
      type: AccountType.captain,
      status: AccountStatus.suspended,
    );
    for (final route in [
      AuthenticatedRoutes.privacyPolicy,
      AuthenticatedRoutes.terms,
    ]) {
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: pending,
          location: route,
        ),
        isNull,
      );
      expect(
        AuthenticatedRoutes.redirectForAuthenticated(
          user: suspended,
          location: route,
        ),
        isNull,
      );
      expect(AuthenticatedRoutes.isPublicLegalRoute(route), isTrue);
    }
  });
}
