import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';

enum AccountReactivatedSyncOutcome { success, profileRefreshFailed }

class AccountReactivatedSyncResult {
  const AccountReactivatedSyncResult({
    required this.outcome,
    this.route,
    this.user,
  });

  final AccountReactivatedSyncOutcome outcome;
  final String? route;
  final AuthUser? user;

  bool get isSuccess => outcome == AccountReactivatedSyncOutcome.success;
}

/// Syncs local auth state after admin unblocks or reactivates an account.
abstract final class AccountReactivatedSync {
  static void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('ACCOUNT REACTIVATED: $message');
  }

  static bool isRestrictedRoute(String location) {
    return location == AuthenticatedRoutes.accountBlocked ||
        location == AuthenticatedRoutes.captainDisabled ||
        location == AuthenticatedRoutes.captainSuspended;
  }

  static Future<AccountReactivatedSyncResult> syncAfterReactivation(
    WidgetRef ref,
  ) async {
    _log('notification received');

    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      _log('skipped — no session');
      return const AccountReactivatedSyncResult(
        outcome: AccountReactivatedSyncOutcome.profileRefreshFailed,
      );
    }

    _log('refreshing profile');
    final refreshed =
        await ref.read(authControllerProvider.notifier).refreshProfile();
    if (!refreshed) {
      _log('profile refresh failed');
      return const AccountReactivatedSyncResult(
        outcome: AccountReactivatedSyncOutcome.profileRefreshFailed,
      );
    }

    final user = ref.read(authControllerProvider).user;
    final route = AuthenticatedRoutes.homeFor(user);
    _log('profile refresh success');
    if (user != null) {
      _log(
        'new type=${user.accountType.name} status=${user.accountStatus.name}',
      );
    }
    _log('routing to $route');

    return AccountReactivatedSyncResult(
      outcome: AccountReactivatedSyncOutcome.success,
      route: route,
      user: user,
    );
  }
}
