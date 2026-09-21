import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/features/auth/domain/entities/account_enums.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/features/captain/presentation/providers/captain_order_providers.dart';

/// Push types that add or return an order to the captain available pool.
const captainAvailableOrderPushTypes = <String>{
  'delivery_order_available',
  'delivery_order_released',
};

bool shouldRefreshCaptainAvailableOrdersFromPush(String? type) {
  if (type == null || type.isEmpty) return false;
  return captainAvailableOrderPushTypes.contains(type);
}

/// Debounced server refetch — avoids duplicate RPC bursts from rapid pushes.
void scheduleCaptainAvailableOrdersPushRefresh(
  ProviderContainer container, {
  required String? notificationType,
}) {
  if (!shouldRefreshCaptainAvailableOrdersFromPush(notificationType)) return;

  final user = container.read(authControllerProvider).user;
  if (user?.accountType != AccountType.captain) return;

  _CaptainAvailableOrdersPushRefreshScheduler.instance.schedule(container);
}

final class _CaptainAvailableOrdersPushRefreshScheduler {
  _CaptainAvailableOrdersPushRefreshScheduler._();

  static final _CaptainAvailableOrdersPushRefreshScheduler instance =
      _CaptainAvailableOrdersPushRefreshScheduler._();

  Timer? _timer;
  static const _debounce = Duration(milliseconds: 750);

  void schedule(ProviderContainer container) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      container.invalidate(captainAvailableOrdersProvider);
      container.invalidate(captainActiveOrderCapacityProvider);
      if (kDebugMode) {
        debugPrint(
          'CAPTAIN_AVAILABLE_ORDERS: push refresh (debounced, server refetch)',
        );
      }
    });
  }
}
