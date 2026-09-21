import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/notifications/account_reactivated_sync.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';

void main() {
  group('AccountReactivatedSync', () {
    test('isRestrictedRoute detects block and restriction screens', () {
      expect(
        AccountReactivatedSync.isRestrictedRoute(
          AuthenticatedRoutes.accountBlocked,
        ),
        isTrue,
      );
      expect(
        AccountReactivatedSync.isRestrictedRoute(
          AuthenticatedRoutes.captainDisabled,
        ),
        isTrue,
      );
      expect(
        AccountReactivatedSync.isRestrictedRoute(
          AuthenticatedRoutes.captainSuspended,
        ),
        isTrue,
      );
      expect(
        AccountReactivatedSync.isRestrictedRoute(AuthenticatedRoutes.home),
        isFalse,
      );
      expect(
        AccountReactivatedSync.isRestrictedRoute(
          AuthenticatedRoutes.captainHome,
        ),
        isFalse,
      );
    });
  });
}
