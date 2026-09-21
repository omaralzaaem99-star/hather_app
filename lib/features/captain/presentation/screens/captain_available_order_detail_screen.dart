import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';
import 'package:hather_app/core/widgets/primary_button.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:hather_app/features/captain/presentation/providers/captain_order_providers.dart';
import 'package:hather_app/features/captain/presentation/utils/captain_order_launcher.dart';
import 'package:hather_app/features/delivery/presentation/utils/delivery_request_number.dart';
import 'package:hather_app/features/delivery/presentation/utils/order_remaining_time.dart';
import 'package:hather_app/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:hather_app/l10n/app_localizations.dart';

Color _captainCardBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? AppColors.border
        : AppColors.icon.withValues(alpha: 0.4);

Color _captainAccentAmount(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? AppColors.primary
        : AppColors.icon;

/// Full-screen available-order detail: preview → accept → owned active detail.
class CaptainAvailableOrderDetailScreen extends ConsumerStatefulWidget {
  const CaptainAvailableOrderDetailScreen({
    required this.orderId,
    this.preview,
    super.key,
  });

  final String orderId;
  final CaptainAvailableOrder? preview;

  @override
  ConsumerState<CaptainAvailableOrderDetailScreen> createState() =>
      _CaptainAvailableOrderDetailScreenState();
}

class _CaptainAvailableOrderDetailScreenState
    extends ConsumerState<CaptainAvailableOrderDetailScreen> {
  CaptainAvailableOrder? _preview;
  CaptainOrderDetail? _accepted;
  bool _accepting = false;
  bool _completing = false;
  bool _reportingNoAnswer = false;
  bool _transferring = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _preview = widget.preview;
    if (_preview == null || _preview!.id != widget.orderId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolvePreview());
    }
  }

  Future<void> _resolvePreview() async {
    final owned = await ref
        .read(captainOrderRepositoryProvider)
        .getMyOrderDetail(widget.orderId);
    if (!mounted) return;
    final ownedOk = owned.when(
      success: (detail) {
        setState(() {
          _accepted = detail;
          _loadError = null;
        });
        return true;
      },
      onFailure: (_) => false,
    );
    if (ownedOk) return;

    final list = await ref.read(captainAvailableOrdersProvider.future);
    if (!mounted) return;
    final match = list.where((o) => o.id == widget.orderId).firstOrNull;
    if (match != null) {
      setState(() {
        _preview = match;
        _loadError = null;
      });
      return;
    }
    ref.invalidate(captainAvailableOrdersProvider);
    setState(() {
      _loadError = AppLocalizations.of(context).captainOrderNoLongerAvailable;
    });
  }

  Future<void> _acceptOrder() async {
    if (_accepting || _accepted != null) return;
    final l10n = AppLocalizations.of(context);
    final preview = _preview;
    if (preview != null &&
        OrderRemainingTime.isExpired(preview.expiresAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainOrderExpiredLabel)),
      );
      return;
    }

    final subscription = ref.read(myCaptainSubscriptionProvider).value;
    if (subscription == null || !subscription.hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainSubscriptionRequiredAccept)),
      );
      return;
    }

    setState(() => _accepting = true);
    final result = await ref
        .read(captainOrderRepositoryProvider)
        .acceptOrder(widget.orderId);
    if (!mounted) return;
    setState(() => _accepting = false);

    result.when(
      success: (detail) {
        refreshCaptainOrders(ref);
        setState(() => _accepted = detail);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.captainAcceptOrderSuccess)),
        );
      },
      onFailure: (failure) {
        final message = failure is Failure
            ? mapFailureToMessage(context, failure)
            : l10n.errorUnknown;
        refreshCaptainOrders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        if (message.contains('كابتن آخر') ||
            message.contains('انتهت صلاحية') ||
            message.contains('الحد الأقصى من الطلبات قيد التنفيذ')) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AuthenticatedRoutes.captainHome);
          }
        }
      },
    );
  }

  Future<void> _completeOrder() async {
    final detail = _accepted;
    if (_completing || detail == null || !detail.isActive) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _completing = true);
    final result = await ref
        .read(captainOrderRepositoryProvider)
        .completeOrder(detail.id);
    if (!mounted) return;
    setState(() => _completing = false);

    result.when(
      success: (updated) {
        setState(() => _accepted = updated);
        refreshCaptainOrders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.captainCompleteOrderSuccess)),
        );
      },
      onFailure: (failure) {
        final message = failure is Failure
            ? mapFailureToMessage(context, failure)
            : l10n.errorUnknown;
        refreshCaptainOrders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  Future<void> _callCustomer(String? phone) async {
    final l10n = AppLocalizations.of(context);
    final uri = CaptainOrderLauncher.telUri(phone);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainCallLaunchFailed)),
      );
      return;
    }
    final ok = await CaptainOrderLauncher.tryLaunch(uri);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainCallLaunchFailed)),
      );
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    final l10n = AppLocalizations.of(context);
    final uris = CaptainOrderLauncher.whatsAppLaunchUris(phone);
    if (uris.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainWhatsAppLaunchFailed)),
      );
      return;
    }
    final ok = await CaptainOrderLauncher.launchFirst(uris);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainWhatsAppLaunchFailed)),
      );
    }
  }

  Future<void> _openWaze(CaptainOrderDetail detail) async {
    final l10n = AppLocalizations.of(context);
    final lat = detail.destinationLat;
    final lng = detail.destinationLng;
    if (lat == null || lng == null) return;
    final ok = await CaptainOrderLauncher.launchFirst(
      CaptainOrderLauncher.wazeLaunchUris(lat, lng),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainWazeLaunchFailed)),
      );
    }
  }

  Future<void> _openGoogleMaps(CaptainOrderDetail detail) async {
    final l10n = AppLocalizations.of(context);
    final lat = detail.destinationLat;
    final lng = detail.destinationLng;
    if (lat == null || lng == null) return;
    final ok = await CaptainOrderLauncher.launchFirst(
      CaptainOrderLauncher.googleMapsLaunchUris(lat, lng),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.captainGoogleMapsLaunchFailed)),
      );
    }
  }

  Future<void> _reportNoAnswer() async {
    final detail = _accepted;
    if (_reportingNoAnswer || detail == null || !detail.isActive) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _reportingNoAnswer = true);
    final result = await ref
        .read(captainOrderRepositoryProvider)
        .reportCustomerNoAnswer(detail.id);
    if (!mounted) return;
    setState(() => _reportingNoAnswer = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.captainCustomerNoAnswerSuccess)),
        );
      },
      onFailure: (failure) {
        final message = failure is Failure
            ? mapFailureToMessage(context, failure)
            : l10n.errorUnknown;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  Future<void> _transferOrder() async {
    final detail = _accepted;
    if (_transferring || detail == null || !detail.isActive) return;
    final l10n = AppLocalizations.of(context);

    final reasons = <String>[
      l10n.captainTransferReasonCannotComplete,
      l10n.captainTransferReasonVehicle,
      l10n.captainTransferReasonFar,
      l10n.captainTransferReasonOther,
    ];
    String? selected = reasons.first;
    final otherCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final isOther = selected == l10n.captainTransferReasonOther;
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                l10n.captainTransferOrderTitle,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.error,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.captainTransferReasonTitle,
                      style: AppTextStyles.bodyStrong,
                    ),
                    const SizedBox(height: 8),
                    ...reasons.map(
                      (r) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected == r
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: AppColors.icon,
                        ),
                        title: Text(r, style: AppTextStyles.body),
                        onTap: () => setLocal(() => selected = r),
                      ),
                    ),
                    if (isOther) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherCtrl,
                        maxLines: 3,
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: l10n.captainTransferReasonOtherHint,
                          filled: true,
                          fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.cancelOrderBack),
                ),
                TextButton(
                  onPressed: () {
                    if (selected == null) return;
                    if (selected == l10n.captainTransferReasonOther &&
                        otherCtrl.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: Text(
                    l10n.captainTransferOrderTitle,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    final reasonLabel = selected;
    final otherText = otherCtrl.text.trim();
    otherCtrl.dispose();
    if (confirmed != true || !mounted || reasonLabel == null) return;

    final reason = reasonLabel == l10n.captainTransferReasonOther
        ? '${l10n.captainTransferReasonOther}: $otherText'
        : reasonLabel;

    setState(() => _transferring = true);
    final result = await ref
        .read(captainOrderRepositoryProvider)
        .transferOrder(orderId: detail.id, reason: reason);
    if (!mounted) return;
    setState(() => _transferring = false);

    result.when(
      success: (_) {
        refreshCaptainOrders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.captainTransferSuccess)),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AuthenticatedRoutes.captainHome);
        }
      },
      onFailure: (failure) {
        final message = failure is Failure
            ? mapFailureToMessage(context, failure)
            : l10n.errorUnknown;
        refreshCaptainOrders(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accepted = _accepted;
    final preview = _preview;
    final busy = _completing || _reportingNoAnswer || _transferring;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          l10n.captainViewOrderDetails,
          style: AppTextStyles.bodyStrong,
        ),
      ),
      body: accepted != null
          ? _AcceptedBody(
              detail: accepted,
              completing: _completing,
              reportingNoAnswer: _reportingNoAnswer,
              transferring: _transferring,
              actionsEnabled: !busy,
              onComplete: _completeOrder,
              onCall: () => _callCustomer(accepted.customerPhone),
              onWhatsApp: () => _openWhatsApp(accepted.customerPhone),
              onWaze: () => _openWaze(accepted),
              onGoogleMaps: () => _openGoogleMaps(accepted),
              onNoAnswer: _reportNoAnswer,
              onTransfer: _transferOrder,
            )
          : preview == null
              ? Center(
                  child: _loadError != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 48,
                                color: AppColors.textMuted.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _loadError!,
                                style: AppTextStyles.body,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              PrimaryButton(
                                label: l10n.retryAction,
                                onPressed: () {
                                  setState(() => _loadError = null);
                                  ref.invalidate(captainAvailableOrdersProvider);
                                  unawaited(_resolvePreview());
                                },
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => context.pop(),
                                child: Text(
                                  l10n.okAction,
                                  style: AppTextStyles.link,
                                ),
                              ),
                            ],
                          ),
                        )
                      : CircularProgressIndicator(color: AppColors.icon),
                )
              : _PreviewBody(
                  order: preview,
                  accepting: _accepting,
                  onAccept: _acceptOrder,
                ),
    );
  }
}

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({
    required this.order,
    required this.accepting,
    required this.onAccept,
  });

  final CaptainAvailableOrder order;
  final bool accepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canSubscribe = ref.watch(myCaptainSubscriptionProvider).maybeWhen(
          data: (info) => info.hasActiveSubscription,
          orElse: () => false,
        );

    return OrderRemainingTimeText(
      expiresAt: order.expiresAt,
      compact: false,
      builder: (context, remainingLabel, expired) {
        final canAccept = canSubscribe && !expired && !accepting;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: AppDimensions.scrollPadding(context, top: 8),
                children: [
                  _OrderHeader(
                    requestNumber: order.requestNumber,
                    statusLabel: l10n.captainOrderAvailableBadge,
                    statusColor: AppColors.pendingOrder,
                  ),
                  const SizedBox(height: 16),
                  _ExpandingDetailsCard(details: order.details),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: l10n.captainOrderDestinationLabel,
                    child: Text(
                      order.destinationLabel,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 18,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: l10n.captainOrderRemainingTimeLabel,
                    child: Text(
                      expired
                          ? l10n.captainOrderExpiredLabel
                          : '⏱ $remainingLabel',
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 20,
                        height: 1.4,
                        color: expired ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!canSubscribe) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.captainSubscriptionRequiredAccept,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.error,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  if (expired) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.captainOrderExpiredLabel,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.error,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(
                  label: '✅ ${l10n.captainAcceptOrderAction}',
                  isLoading: accepting,
                  enabled: canAccept,
                  onPressed: canAccept ? onAccept : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AcceptedBody extends StatelessWidget {
  const _AcceptedBody({
    required this.detail,
    required this.completing,
    required this.reportingNoAnswer,
    required this.transferring,
    required this.actionsEnabled,
    required this.onComplete,
    required this.onCall,
    required this.onWhatsApp,
    required this.onWaze,
    required this.onGoogleMaps,
    required this.onNoAnswer,
    required this.onTransfer,
  });

  final CaptainOrderDetail detail;
  final bool completing;
  final bool reportingNoAnswer;
  final bool transferring;
  final bool actionsEnabled;
  final VoidCallback onComplete;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onWaze;
  final VoidCallback onGoogleMaps;
  final VoidCallback onNoAnswer;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = CaptainOrderLauncher.localPhone(detail.customerPhone) ?? '—';
    final locationText =
        (detail.destinationAddress?.trim().isNotEmpty ?? false)
            ? detail.destinationAddress!.trim()
            : detail.destinationLabel;
    final feeText = CaptainOrderLauncher.formatIqd(detail.effectiveDeliveryFee);
    final showDiscount = detail.couponDiscountIqd > 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppDimensions.scrollPadding(context, top: 8),
            children: [
              _OrderHeader(
                requestNumber: detail.requestNumber,
                statusLabel: detail.isCompleted
                    ? l10n.captainOrderCompletedBadge
                    : l10n.captainOrderStatusActive,
                statusColor:
                    detail.isCompleted ? AppColors.success : AppColors.icon,
              ),
              const SizedBox(height: 16),
              _ExpandingDetailsCard(details: detail.details),
              const SizedBox(height: 16),
              _CustomerInfoCard(
                name: detail.customerName?.trim().isNotEmpty == true
                    ? detail.customerName!.trim()
                    : l10n.valueNotAvailable,
                phone: phone,
                actionsEnabled: actionsEnabled,
                onCall: onCall,
                onWhatsApp: onWhatsApp,
              ),
              if (detail.hasGps || locationText.isNotEmpty) ...[
                const SizedBox(height: 16),
                _NavigationCard(
                  location: locationText,
                  hasGps: detail.hasGps,
                  actionsEnabled: actionsEnabled,
                  onWaze: onWaze,
                  onGoogleMaps: onGoogleMaps,
                ),
              ],
              const SizedBox(height: 16),
              _FeeCard(
                title: l10n.captainDeliveryFeeTitle,
                amountLabel: l10n.captainDeliveryFeeAmount(feeText),
                discountLabel: showDiscount
                    ? '${l10n.captainCouponDiscountLabel}: ${l10n.captainDeliveryFeeAmount(CaptainOrderLauncher.formatIqd(detail.couponDiscountIqd))}'
                    : null,
              ),
              if (detail.acceptedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${l10n.captainOrderAcceptedAtLabel}: ${AppDateTimeFormat.dateTime(detail.acceptedAt!)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 14),
                ),
              ],
              if (detail.completedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${l10n.captainOrderCompletedAtLabel}: ${AppDateTimeFormat.dateTime(detail.completedAt!)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 14),
                ),
              ],
              if (detail.isActive) ...[
                const SizedBox(height: 16),
                _ActionsCard(
                  reportingNoAnswer: reportingNoAnswer,
                  transferring: transferring,
                  actionsEnabled: actionsEnabled,
                  onNoAnswer: onNoAnswer,
                  onTransfer: onTransfer,
                ),
              ],
            ],
          ),
        ),
        if (detail.isActive)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: '✅ ${l10n.captainCompleteOrderAction}',
                isLoading: completing,
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.onPrimary,
                onPressed: actionsEnabled ? onComplete : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({
    required this.requestNumber,
    required this.statusLabel,
    required this.statusColor,
  });

  final int? requestNumber;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            DeliveryRequestNumber.display(requestNumber),
            style: AppTextStyles.bodyStrong.copyWith(
              color: _captainAccentAmount(context),
              fontSize: 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _StatusChip(label: statusLabel, color: statusColor),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: _captainCardBorder(context),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.icon,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({
    required this.name,
    required this.phone,
    required this.actionsEnabled,
    required this.onCall,
    required this.onWhatsApp,
  });

  final String name;
  final String phone;
  final bool actionsEnabled;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canContact = actionsEnabled && phone != '—';

    return _InfoCard(
      title: l10n.captainCustomerInfoTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.captainCustomerNameLabel,
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: AppTextStyles.bodyStrong.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.captainCustomerPhoneLabel,
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 6),
          SelectableText(
            phone,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 300;
              final callBtn = _ContactActionButton(
                label: l10n.captainCallAction,
                onPressed: canContact ? onCall : null,
                icon: Icons.phone,
                iconColor: AppColors.icon,
              );
              final waBtn = _ContactActionButton(
                label: l10n.captainWhatsAppAction,
                onPressed: canContact ? onWhatsApp : null,
                icon: Icons.chat,
                iconColor: AppColors.whatsApp,
              );
              if (stacked) {
                return Column(
                  children: [
                    callBtn,
                    const SizedBox(height: 10),
                    waBtn,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: callBtn),
                  const SizedBox(width: 10),
                  Expanded(child: waBtn),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.location,
    required this.hasGps,
    required this.actionsEnabled,
    required this.onWaze,
    required this.onGoogleMaps,
  });

  final String location;
  final bool hasGps;
  final bool actionsEnabled;
  final VoidCallback onWaze;
  final VoidCallback onGoogleMaps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _InfoCard(
      title: l10n.captainCustomerLocationTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            location,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 18,
              height: 1.45,
            ),
          ),
          if (hasGps) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 300;
                final wazeBtn = _ContactActionButton(
                  label: l10n.captainWazeAction,
                  icon: Icons.navigation_outlined,
                  iconColor: AppColors.icon,
                  onPressed: actionsEnabled ? onWaze : null,
                );
                final mapsBtn = _ContactActionButton(
                  label: l10n.captainGoogleMapsAction,
                  icon: Icons.map_outlined,
                  iconColor: AppColors.icon,
                  onPressed: actionsEnabled ? onGoogleMaps : null,
                );
                if (stacked) {
                  return Column(
                    children: [
                      wazeBtn,
                      const SizedBox(height: 10),
                      mapsBtn,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: wazeBtn),
                    const SizedBox(width: 10),
                    Expanded(child: mapsBtn),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.reportingNoAnswer,
    required this.transferring,
    required this.actionsEnabled,
    required this.onNoAnswer,
    required this.onTransfer,
  });

  final bool reportingNoAnswer;
  final bool transferring;
  final bool actionsEnabled;
  final VoidCallback onNoAnswer;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _InfoCard(
      title: l10n.captainOrderActionsTitle,
      child: Column(
        children: [
          _ActionTile(
            label: '📵 ${l10n.captainCustomerNoAnswerAction}',
            isLoading: reportingNoAnswer,
            onPressed: actionsEnabled ? onNoAnswer : null,
          ),
          _ActionTile(
            label: '🔄 ${l10n.captainTransferOrderAction}',
            isLoading: transferring,
            danger: true,
            onPressed: actionsEnabled ? onTransfer : null,
          ),
        ],
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            side: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({
    required this.title,
    required this.amountLabel,
    this.discountLabel,
  });

  final String title;
  final String amountLabel;
  final String? discountLabel;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            amountLabel,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 22,
              color: _captainAccentAmount(context),
            ),
          ),
          if (discountLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              discountLabel!,
              style: AppTextStyles.caption.copyWith(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: danger ? AppColors.error : AppColors.textPrimary,
            side: BorderSide(
              color: danger
                  ? AppColors.error.withValues(alpha: 0.7)
                  : AppColors.icon.withValues(alpha: 0.45),
            ),
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.icon,
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                ),
        ),
      ),
    );
  }
}

class _ExpandingDetailsCard extends StatelessWidget {
  const _ExpandingDetailsCard({required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: _captainCardBorder(context),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.captainOrderDetailsLabel,
            style: AppTextStyles.bodyStrong.copyWith(
              color: AppColors.icon,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            details,
            softWrap: true,
            textAlign: TextAlign.start,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 19,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
