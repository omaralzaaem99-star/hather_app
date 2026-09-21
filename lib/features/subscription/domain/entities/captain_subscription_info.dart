import 'package:equatable/equatable.dart';

enum CaptainSubscriptionType { trial, paid, none }

enum CaptainSubscriptionStatus { active, expired, none }

class CaptainSubscriptionInfo extends Equatable {
  const CaptainSubscriptionInfo({
    required this.isCaptain,
    required this.hasActiveSubscription,
    required this.subscriptionType,
    required this.status,
    required this.remainingDays,
    this.accountStatus,
    this.startsAt,
    this.endsAt,
  });

  final bool isCaptain;
  final bool hasActiveSubscription;
  final CaptainSubscriptionType subscriptionType;
  final CaptainSubscriptionStatus status;
  final int remainingDays;
  final String? accountStatus;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory CaptainSubscriptionInfo.none() {
    return const CaptainSubscriptionInfo(
      isCaptain: false,
      hasActiveSubscription: false,
      subscriptionType: CaptainSubscriptionType.none,
      status: CaptainSubscriptionStatus.none,
      remainingDays: 0,
    );
  }

  factory CaptainSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final typeWire = json['subscription_type']?.toString();
    final statusWire = json['status']?.toString();

    return CaptainSubscriptionInfo(
      isCaptain: json['is_captain'] == true,
      hasActiveSubscription: json['has_active_subscription'] == true,
      subscriptionType: switch (typeWire) {
        'trial' => CaptainSubscriptionType.trial,
        'paid' => CaptainSubscriptionType.paid,
        _ => CaptainSubscriptionType.none,
      },
      status: switch (statusWire) {
        'active' => CaptainSubscriptionStatus.active,
        'expired' => CaptainSubscriptionStatus.expired,
        _ => CaptainSubscriptionStatus.none,
      },
      remainingDays: (json['remaining_days'] as num?)?.toInt() ?? 0,
      accountStatus: json['account_status']?.toString(),
      startsAt: _parseDate(json['starts_at']),
      endsAt: _parseDate(json['ends_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  @override
  List<Object?> get props => [
        isCaptain,
        hasActiveSubscription,
        subscriptionType,
        status,
        remainingDays,
        accountStatus,
        startsAt,
        endsAt,
      ];
}
