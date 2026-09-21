import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_state.dart';

void main() {
  AuthSession sessionWith({
    AccountType type = AccountType.user,
    AccountStatus status = AccountStatus.active,
  }) {
    final now = DateTime.now().toUtc();
    return AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      expiresAt: now.add(const Duration(hours: 1)),
      user: AuthUser(
        id: 'u1',
        fullName: 'Test',
        phone: '+9647700000000',
        accountType: type,
        accountStatus: status,
        phoneVerified: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('isAuthenticated stays true while loading with a valid session', () {
    final state = AuthState(
      status: AuthStatus.loading,
      session: sessionWith(),
    );
    expect(state.isAuthenticated, isTrue);
  });

  test('isAuthenticated false when loading without session', () {
    const state = AuthState(status: AuthStatus.loading);
    expect(state.isAuthenticated, isFalse);
  });

  test('isAuthResolving is true during initializing', () {
    const state = AuthState(status: AuthStatus.initializing);
    expect(state.isAuthResolving, isTrue);
    expect(state.isAuthenticated, isFalse);
  });

  test('session valid with expired access when refresh token exists', () {
    final now = DateTime.now().toUtc();
    final session = AuthSession(
      accessToken: 'a',
      refreshToken: 'refresh',
      expiresAt: now.subtract(const Duration(hours: 1)),
      user: AuthUser(
        id: 'u1',
        fullName: 'Test',
        phone: '+9647700000000',
        accountType: AccountType.user,
        accountStatus: AccountStatus.active,
        phoneVerified: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(session.isValid, isTrue);
  });

  test('isAuthenticated false after explicit unauthenticated', () {
    final state = AuthState(
      status: AuthStatus.unauthenticated,
      session: sessionWith(),
    );
    expect(state.isAuthenticated, isFalse);
  });

  test('five consecutive user→captain/pending session updates stay authenticated', () {
    for (var i = 0; i < 5; i++) {
      final active = AuthState(
        status: AuthStatus.authenticated,
        session: sessionWith(),
      );
      expect(active.isAuthenticated, isTrue);

      // Mimic old bug: brief loading during convert must NOT drop auth.
      final midConvert = AuthState(
        status: AuthStatus.loading,
        session: active.session,
      );
      expect(midConvert.isAuthenticated, isTrue);

      final pending = AuthState(
        status: AuthStatus.authenticated,
        session: sessionWith(
          type: AccountType.captain,
          status: AccountStatus.pending,
        ),
      );
      expect(pending.isAuthenticated, isTrue);
      expect(pending.user?.accountType, AccountType.captain);
      expect(pending.user?.accountStatus, AccountStatus.pending);
    }
  });
}
