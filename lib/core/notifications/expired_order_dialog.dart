import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/notifications/handled_expired_order_storage.dart';
import 'package:hather_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Shows the expired-order dialog at most once per [orderId].
abstract final class ExpiredOrderDialog {
  static const _eventType = 'delivery_order_expired';

  static final HandledExpiredOrderStorage _storage = HandledExpiredOrderStorage();
  static final Set<String> _handledOrderIds = <String>{};
  static String? _openOrderId;
  static Future<void>? _loadFuture;

  @visibleForTesting
  static void resetForTest() {
    _handledOrderIds.clear();
    _openOrderId = null;
    _loadFuture = null;
  }

  @visibleForTesting
  static Set<String> get handledOrderIds => Set.unmodifiable(_handledOrderIds);

  @visibleForTesting
  static String? get openOrderId => _openOrderId;

  static Future<void> _ensureLoaded() {
    return _loadFuture ??= () async {
      final persisted = await _storage.readAll();
      _handledOrderIds.addAll(persisted);
    }();
  }

  static bool _isValidOrderId(String? orderId) {
    if (orderId == null) return false;
    final trimmed = orderId.trim();
    return trimmed.isNotEmpty && Uuid.isValidUUID(fromString: trimmed);
  }

  /// Dedupe key: order_id + event type.
  static bool shouldShow({required String? orderId}) {
    if (!_isValidOrderId(orderId)) return false;
    final id = orderId!.trim();
    if (_handledOrderIds.contains(id)) return false;
    if (_openOrderId == id) return false;
    return true;
  }

  static Future<void> markHandled(String orderId) async {
    final id = orderId.trim();
    if (!_isValidOrderId(id)) return;
    _handledOrderIds.add(id);
    await _storage.add(id);
  }

  /// Returns `true` when user chose create-order, `false` for OK, `null` when skipped.
  static Future<bool?> showIfNeeded({
    required BuildContext context,
    required String? orderId,
    GoRouter? router,
    WidgetRef? ref,
  }) async {
    await _ensureLoaded();
    if (!shouldShow(orderId: orderId)) {
      if (kDebugMode) {
        debugPrint(
          'Expired order dialog skipped (handled/open/invalid): orderId=$orderId',
        );
      }
      return null;
    }

    final id = orderId!.trim();
    _openOrderId = id;
    try {
      if (!context.mounted) return null;

      final l10n = AppLocalizations.of(context);
      final create = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.notificationExpiredDialogTitle),
          content: Text(l10n.notificationExpiredDialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.okAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.notificationCreateNewOrder),
            ),
          ],
        ),
      );

      await markHandled(id);
      ref?.invalidate(myOrdersProvider);

      if (!context.mounted) return create;
      if (create == true) {
        if (router != null) {
          router.push('/delivery/create-order');
        } else {
          context.push('/delivery/create-order');
        }
      }
      return create;
    } finally {
      if (_openOrderId == id) {
        _openOrderId = null;
      }
    }
  }

  @visibleForTesting
  static String eventKeyFor(String orderId) => '$_eventType:${orderId.trim()}';
}
