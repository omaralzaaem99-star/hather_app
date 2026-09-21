class UserNotification {
  const UserNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.orderId,
    this.supportRequestId,
    this.tapDestination,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? orderId;
  final String? supportRequestId;
  final String? tapDestination;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isExpiredOrder => type == 'delivery_order_expired';
  bool get isAcceptedOrder => type == 'delivery_order_accepted';
  bool get isCompletedOrder => type == 'delivery_order_completed';
  bool get isSearchingCaptain => type == 'delivery_order_searching_captain';
  bool get isAvailableOrder => type == 'delivery_order_available';
  bool get isSupportReply => type == 'support_reply';
  bool get isCaptainApproved => type == 'captain_approved';
  bool get isCaptainRejected => type == 'captain_rejected';
  bool get isCaptainSuspended => type == 'captain_suspended';
  bool get isCaptainDisabled => type == 'captain_disabled';
  bool get isAccountReactivated => type == 'account_reactivated';
  bool get isSubscriptionActivated => type == 'subscription_activated';
  bool get isAdminBroadcast => type == 'admin_broadcast';

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return UserNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      orderId: json['order_id']?.toString(),
      supportRequestId: json['support_request_id']?.toString(),
      tapDestination: json['tap_destination']?.toString(),
      isRead: json['is_read'] == true,
      readAt: parseTs(json['read_at']),
      createdAt: parseTs(json['created_at']) ?? DateTime.now(),
    );
  }
}
