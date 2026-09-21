import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/notifications/notification_navigation.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/domain/entities/auth_user.dart';
import 'package:hather_app/features/notifications/domain/entities/user_notification.dart';

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

UserNotification _notification({
  String type = 'admin_broadcast',
  String? orderId,
  String? supportRequestId,
  String? tapDestination,
}) {
  return UserNotification(
    id: 'n-1',
    type: type,
    title: 'Test',
    body: 'Body',
    isRead: false,
    createdAt: DateTime.utc(2026, 1, 1),
    orderId: orderId,
    supportRequestId: supportRequestId,
    tapDestination: tapDestination,
  );
}

void main() {
  group('NotificationNavigation.resolveLocation', () {
    test('TEST A: delivery_order_available routes active captain to available detail', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'delivery_order_available',
        orderId: 'order-abc',
      );

      expect(
        location,
        AuthenticatedRoutes.captainAvailableOrderPath('order-abc'),
      );
    });

    test('TEST B: delivery_order_assigned routes active captain to order detail', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'delivery_order_assigned',
        orderId: 'order-abc',
      );

      expect(
        location,
        AuthenticatedRoutes.captainAvailableOrderPath('order-abc'),
      );
    });

    test('TEST C: delivery_order_completed routes active captain to order detail', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'delivery_order_completed',
        orderId: 'order-abc',
      );

      expect(
        location,
        AuthenticatedRoutes.captainAvailableOrderPath('order-abc'),
      );
    });

    test('TEST D: delivery_order_released + order_id routes captain home', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'delivery_order_released',
        orderId: 'order-abc',
      );

      expect(location, AuthenticatedRoutes.captainHome);
      expect(
        location,
        isNot(AuthenticatedRoutes.captainAvailableOrderPath('order-abc')),
      );
    });

    test('TEST E: delivery_order_cancelled + order_id routes captain to detail', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'delivery_order_cancelled',
        orderId: 'order-abc',
        notification: _notification(
          type: 'delivery_order_cancelled',
          orderId: 'order-abc',
        ),
      );

      expect(location, NotificationNavigation.detailRoute);
      expect(
        location,
        isNot(AuthenticatedRoutes.captainAvailableOrderPath('order-abc')),
      );
    });

    test('TEST F: released/cancelled without order_id use safe captain destinations', () {
      expect(
        NotificationNavigation.resolveLocation(
          user: _user(type: AccountType.captain, status: AccountStatus.active),
          type: 'delivery_order_released',
        ),
        AuthenticatedRoutes.captainHome,
      );
      expect(
        NotificationNavigation.resolveLocation(
          user: _user(type: AccountType.captain, status: AccountStatus.active),
          type: 'delivery_order_cancelled',
          notification: _notification(type: 'delivery_order_cancelled'),
        ),
        NotificationNavigation.detailRoute,
      );
    });

    test('delivery_order_cancelled routes user to delivery order detail', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(),
        type: 'delivery_order_cancelled',
        orderId: 'order-xyz',
      );

      expect(location, '/delivery/orders/order-xyz');
    });

    test('delivery_order_available routes user to order detail when order_id present', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(),
        type: 'delivery_order_available',
        orderId: 'order-abc',
      );

      expect(location, '/delivery/orders/order-abc');
    });

    test('delivery_order_available opens detail when order_id missing', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'delivery_order_available',
        notification: _notification(type: 'delivery_order_available'),
      );

      expect(location, NotificationNavigation.detailRoute);
    });

    test('user order types route to delivery order detail', () {
      for (final type in [
        'delivery_order_accepted',
        'delivery_order_completed',
        'delivery_order_searching_captain',
      ]) {
        final location = NotificationNavigation.resolveLocation(
          user: _user(),
          type: type,
          orderId: 'order-xyz',
        );
        expect(location, '/delivery/orders/order-xyz', reason: type);
      }
    });

    test('user order types open detail for captain without order route', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'delivery_order_accepted',
        orderId: 'order-xyz',
      );

      expect(
        location,
        AuthenticatedRoutes.captainAvailableOrderPath('order-xyz'),
      );
    });

    test('support_reply routes to support request detail', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(),
        type: 'support_reply',
        supportRequestId: 'req-1',
      );

      expect(location, AuthenticatedRoutes.supportRequestPath('req-1'));
    });

    test('captain_approved routes to captain home', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.pending),
        type: 'captain_approved',
      );

      expect(location, AuthenticatedRoutes.captainHome);
    });

    test('captain_suspended routes to suspended screen', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.suspended),
        type: 'captain_suspended',
      );

      expect(location, AuthenticatedRoutes.captainSuspended);
    });

    test('captain_disabled routes to disabled screen', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.disabled),
        type: 'captain_disabled',
      );

      expect(location, AuthenticatedRoutes.captainDisabled);
    });

    test('account_reactivated routes user to home', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(),
        type: 'account_reactivated',
        tapDestination: 'home',
      );

      expect(location, AuthenticatedRoutes.home);
    });

    test('account_reactivated routes active captain to captain home', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'account_reactivated',
        tapDestination: 'home',
      );

      expect(location, AuthenticatedRoutes.captainHome);
    });

    test('subscription_activated routes active captain to account', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(type: AccountType.captain, status: AccountStatus.active),
        type: 'subscription_activated',
      );

      expect(location, AuthenticatedRoutes.captainAccount);
    });

    test('admin_broadcast respects tap_destination whitelist', () {
      expect(
        NotificationNavigation.resolveLocation(
          user: _user(),
          type: 'admin_broadcast',
          tapDestination: 'notifications',
        ),
        NotificationNavigation.detailRoute,
      );
      expect(
        NotificationNavigation.resolveLocation(
          user: _user(),
          type: 'admin_broadcast',
          tapDestination: 'home',
        ),
        AuthenticatedRoutes.home,
      );
      expect(
        NotificationNavigation.resolveLocation(
          user: _user(type: AccountType.captain, status: AccountStatus.active),
          type: 'admin_broadcast',
          tapDestination: 'home',
        ),
        AuthenticatedRoutes.captainHome,
      );
      expect(
        NotificationNavigation.resolveLocation(
          user: _user(),
          type: 'admin_broadcast',
          tapDestination: 'none',
          notification: _notification(tapDestination: 'none'),
        ),
        NotificationNavigation.detailRoute,
      );
      expect(
        NotificationNavigation.resolveLocation(
          user: _user(),
          type: 'admin_broadcast',
          tapDestination: 'https://evil.com',
        ),
        NotificationNavigation.detailRoute,
      );
    });

    test('unknown general notification opens detail screen', () {
      final location = NotificationNavigation.resolveLocation(
        user: _user(),
        type: 'custom_announcement',
        notification: _notification(type: 'custom_announcement'),
      );

      expect(location, NotificationNavigation.detailRoute);
    });
  });
}
