import 'package:equatable/equatable.dart';

/// Privacy-safe preview shown before acceptance (from list RPC).
class CaptainAvailableOrder extends Equatable {
  const CaptainAvailableOrder({
    required this.id,
    required this.orderTypeName,
    required this.details,
    required this.destinationLabel,
    required this.deliveryFeeIqd,
    required this.createdAt,
    required this.expiresAt,
    this.requestNumber,
  });

  final String id;
  final int? requestNumber;
  final String orderTypeName;
  final String details;
  final String destinationLabel;
  final num deliveryFeeIqd;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory CaptainAvailableOrder.fromJson(Map<String, dynamic> json) {
    DateTime parseRequiredTs(Object? raw, String field) {
      final parsed = DateTime.tryParse(raw?.toString() ?? '');
      if (parsed == null) {
        throw FormatException('missing $field');
      }
      return parsed;
    }

    num parseFee(Object? raw) {
      if (raw is num) return raw;
      return num.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return CaptainAvailableOrder(
      id: json['id']?.toString() ?? '',
      requestNumber: _parseRequestNumber(json['request_number']),
      orderTypeName: json['order_type_name']?.toString() ?? 'طلب توصيل',
      details: json['details']?.toString() ?? '',
      destinationLabel: json['destination_label']?.toString() ?? '—',
      deliveryFeeIqd: parseFee(json['delivery_fee_iqd']),
      createdAt: parseRequiredTs(json['created_at'], 'created_at'),
      expiresAt: parseRequiredTs(json['expires_at'], 'expires_at'),
    );
  }

  @override
  List<Object?> get props => [
        id,
        requestNumber,
        orderTypeName,
        details,
        destinationLabel,
        deliveryFeeIqd,
        createdAt,
        expiresAt,
      ];
}

/// Captain-owned order summary (my orders tab).
class CaptainMyOrder extends Equatable {
  const CaptainMyOrder({
    required this.id,
    required this.orderTypeName,
    required this.details,
    required this.destinationLabel,
    required this.deliveryFeeIqd,
    required this.status,
    required this.createdAt,
    this.requestNumber,
    this.acceptedAt,
    this.completedAt,
    this.expiresAt,
  });

  final String id;
  final int? requestNumber;
  final String orderTypeName;
  final String details;
  final String destinationLabel;
  final num deliveryFeeIqd;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  factory CaptainMyOrder.fromJson(Map<String, dynamic> json) {
    return CaptainMyOrder(
      id: json['id'] as String,
      requestNumber: _parseRequestNumber(json['request_number']),
      orderTypeName: json['order_type_name'] as String,
      details: json['details'] as String,
      destinationLabel: json['destination_label'] as String? ?? '—',
      deliveryFeeIqd: json['delivery_fee_iqd'] as num,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        requestNumber,
        orderTypeName,
        details,
        destinationLabel,
        deliveryFeeIqd,
        status,
        createdAt,
        acceptedAt,
        completedAt,
        expiresAt,
      ];
}

/// Full detail after acceptance (includes customer contact + GPS).
class CaptainOrderDetail extends Equatable {
  const CaptainOrderDetail({
    required this.id,
    required this.orderTypeName,
    required this.details,
    required this.status,
    required this.deliveryFeeIqd,
    required this.couponDiscountIqd,
    required this.destinationType,
    required this.destinationLabel,
    required this.createdAt,
    this.requestNumber,
    this.deliveryFeeFinal,
    this.destinationLat,
    this.destinationLng,
    this.destinationAddress,
    this.acceptedAt,
    this.completedAt,
    this.expiresAt,
    this.customerName,
    this.customerPhone,
  });

  final String id;
  final int? requestNumber;
  final String orderTypeName;
  final String details;
  final String status;
  final num deliveryFeeIqd;
  final num couponDiscountIqd;
  final num? deliveryFeeFinal;
  final String destinationType;
  final String destinationLabel;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationAddress;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final String? customerName;
  final String? customerPhone;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  bool get hasGps => destinationLat != null && destinationLng != null;

  /// Server snapshot final fee when present; otherwise computed from base − discount.
  num get effectiveDeliveryFee {
    if (deliveryFeeFinal != null) return deliveryFeeFinal!;
    final computed = deliveryFeeIqd - couponDiscountIqd;
    return computed < 0 ? 0 : computed;
  }

  factory CaptainOrderDetail.fromJson(Map<String, dynamic> json) {
    return CaptainOrderDetail(
      id: json['id'] as String,
      requestNumber: _parseRequestNumber(json['request_number']),
      orderTypeName: json['order_type_name'] as String,
      details: json['details'] as String,
      status: json['status'] as String,
      deliveryFeeIqd: json['delivery_fee_iqd'] as num,
      couponDiscountIqd: (json['coupon_discount_iqd'] as num?) ?? 0,
      deliveryFeeFinal: json['delivery_fee_final'] as num?,
      destinationType: json['destination_type'] as String? ?? 'current',
      destinationLabel: json['destination_label'] as String? ?? '—',
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      destinationAddress: json['destination_address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        requestNumber,
        orderTypeName,
        details,
        status,
        deliveryFeeIqd,
        couponDiscountIqd,
        deliveryFeeFinal,
        destinationType,
        destinationLabel,
        destinationLat,
        destinationLng,
        destinationAddress,
        createdAt,
        acceptedAt,
        completedAt,
        expiresAt,
        customerName,
        customerPhone,
      ];
}

/// Captain concurrent active-order capacity from server settings.
class CaptainActiveOrderCapacity extends Equatable {
  const CaptainActiveOrderCapacity({
    required this.activeCount,
    required this.maxActiveOrders,
    required this.atCapacity,
  });

  final int activeCount;
  final int maxActiveOrders;
  final bool atCapacity;

  factory CaptainActiveOrderCapacity.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? raw, {int fallback = 0}) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    final active = parseInt(json['active_count']);
    final max = parseInt(json['max_active_orders'], fallback: 1);
    return CaptainActiveOrderCapacity(
      activeCount: active,
      maxActiveOrders: max,
      atCapacity: json['at_capacity'] == true || active >= max,
    );
  }

  @override
  List<Object?> get props => [activeCount, maxActiveOrders, atCapacity];
}

int? _parseRequestNumber(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

List<CaptainAvailableOrder> parseAvailableOrdersJson(Object? raw) {
  if (raw is! List) return const [];
  final out = <CaptainAvailableOrder>[];
  for (final item in raw) {
    if (item is! Map) continue;
    try {
      final order = CaptainAvailableOrder.fromJson(
        Map<String, dynamic>.from(item),
      );
      if (order.id.isEmpty) continue;
      out.add(order);
    } on Object {
      // Skip malformed rows; do not fail the whole list.
      continue;
    }
  }
  return out;
}

List<CaptainMyOrder> parseMyOrdersJson(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => CaptainMyOrder.fromJson(
            Map<String, dynamic>.from(item),
          ))
      .toList();
}

CaptainOrderDetail parseOrderDetailJson(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return CaptainOrderDetail.fromJson(raw);
  }
  if (raw is Map) {
    return CaptainOrderDetail.fromJson(Map<String, dynamic>.from(raw));
  }
  throw const FormatException('invalid order detail payload');
}
