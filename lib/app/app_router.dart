import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_state.dart';
import 'package:hather_app/features/auth/presentation/screens/account_blocked_screen.dart';
import 'package:hather_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:hather_app/features/auth/presentation/screens/login_screen.dart';
import 'package:hather_app/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:hather_app/features/auth/presentation/screens/register_screen.dart';
import 'package:hather_app/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:hather_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:hather_app/features/captain/presentation/screens/captain_account_screen.dart';
import 'package:hather_app/features/captain/presentation/screens/captain_available_order_detail_screen.dart';
import 'package:hather_app/features/captain/presentation/screens/captain_disabled_screen.dart';
import 'package:hather_app/features/captain/presentation/screens/captain_home_screen.dart';
import 'package:hather_app/features/captain/presentation/screens/captain_orders_screen.dart';
import 'package:hather_app/features/captain/presentation/screens/captain_pending_screen.dart';
import 'package:hather_app/features/captain/presentation/screens/captain_suspended_screen.dart';
import 'package:hather_app/features/captain/presentation/widgets/captain_main_shell.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:hather_app/features/delivery/presentation/screens/create_delivery_order_screen.dart';
import 'package:hather_app/features/delivery/presentation/screens/map_picker_screen.dart';
import 'package:hather_app/features/delivery/presentation/screens/user_order_detail_screen.dart';
import 'package:hather_app/features/home/presentation/screens/account_screen.dart';
import 'package:hather_app/features/home/presentation/screens/home_screen.dart';
import 'package:hather_app/features/home/presentation/screens/orders_screen.dart';
import 'package:hather_app/features/home/presentation/widgets/main_shell.dart';
import 'package:hather_app/features/legal/presentation/screens/legal_screens.dart';
import 'package:hather_app/features/notifications/presentation/screens/notification_detail_screen.dart';
import 'package:hather_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:hather_app/features/notifications/domain/entities/user_notification.dart';
import 'package:hather_app/features/support/presentation/screens/support_form_screen.dart';
import 'package:hather_app/features/support/presentation/screens/support_request_detail_screen.dart';
import 'package:hather_app/features/support/presentation/screens/support_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    refresh.tick();
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isProtected =
          !AuthenticatedRoutes.isPublicLegalRoute(location) &&
          (AuthenticatedRoutes.isUserShellRoute(location) ||
              AuthenticatedRoutes.isCaptainRestrictedRoute(location) ||
              AuthenticatedRoutes.isSharedInfoRoute(location));

      if (auth.isAuthResolving) {
        return isSplash ? null : '/splash';
      }

      if (auth.isAuthenticated) {
        return AuthenticatedRoutes.redirectForAuthenticated(
          user: auth.user,
          location: location,
        );
      }

      if (isProtected) return '/login';

      if (location == '/otp-verification' && auth.pendingChallenge == null) {
        return '/login';
      }

      if (location == '/reset-password') {
        final challengeId = state.extra as String?;
        if (challengeId == null || challengeId.isEmpty) {
          return '/forgot-password';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final challengeId = state.extra as String? ?? '';
          return ResetPasswordScreen(challengeId: challengeId);
        },
      ),
      GoRoute(
        path: AuthenticatedRoutes.accountBlocked,
        builder: (context, state) => const AccountBlockedScreen(),
      ),
      GoRoute(
        path: AuthenticatedRoutes.captainPending,
        builder: (context, state) => const CaptainPendingScreen(),
      ),
      GoRoute(
        path: AuthenticatedRoutes.captainSuspended,
        builder: (context, state) => const CaptainSuspendedScreen(),
      ),
      GoRoute(
        path: AuthenticatedRoutes.captainDisabled,
        builder: (context, state) => const CaptainDisabledScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CaptainMainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthenticatedRoutes.captainOrders,
                builder: (context, state) => const CaptainOrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthenticatedRoutes.captainHome,
                builder: (context, state) => const CaptainHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthenticatedRoutes.captainAccount,
                builder: (context, state) => const CaptainAccountScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/delivery/create-order',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateDeliveryOrderScreen(),
      ),
      GoRoute(
        path: '/captain/available-orders/:orderId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          final preview = state.extra is CaptainAvailableOrder
              ? state.extra as CaptainAvailableOrder
              : null;
          return CaptainAvailableOrderDetailScreen(
            orderId: orderId,
            preview: preview,
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
        routes: [
          GoRoute(
            path: 'detail',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final notification = state.extra;
              if (notification is! UserNotification) {
                return const NotificationsScreen();
              }
              return NotificationDetailScreen(notification: notification);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/delivery/orders/:orderId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return UserOrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/delivery/map-picker',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MapPickerScreen(),
      ),
      GoRoute(
        path: AuthenticatedRoutes.privacyPolicy,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AuthenticatedRoutes.terms,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: AuthenticatedRoutes.about,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: AuthenticatedRoutes.support,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SupportScreen(),
        routes: [
          GoRoute(
            path: 'forms/:formId',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final formId = state.pathParameters['formId'] ?? '';
              return SupportFormScreen(formId: formId);
            },
          ),
          GoRoute(
            path: 'requests/:requestId',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final requestId = state.pathParameters['requestId'] ?? '';
              return SupportRequestDetailScreen(requestId: requestId);
            },
          ),
        ],
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  void tick() => notifyListeners();
}
