import 'package:equatable/equatable.dart';

class OrderTypeOption extends Equatable {
  const OrderTypeOption({
    required this.id,
    required this.nameAr,
  });

  final String id;
  final String nameAr;

  @override
  List<Object?> get props => [id, nameAr];
}

class DeleteDurationOption extends Equatable {
  const DeleteDurationOption({
    required this.id,
    required this.labelAr,
    required this.minutes,
    this.isDefault = false,
  });

  final String id;
  final String labelAr;
  final int minutes;
  final bool isDefault;

  factory DeleteDurationOption.fromJson(Map<String, dynamic> json) {
    return DeleteDurationOption(
      id: json['id'] as String,
      labelAr: (json['label_ar'] as String?) ?? '',
      minutes: (json['minutes'] as num).toInt(),
      isDefault: json['is_default'] == true,
    );
  }

  @override
  List<Object?> get props => [id, labelAr, minutes, isDefault];
}

class DeliveryFeeOption extends Equatable {
  const DeliveryFeeOption({
    required this.id,
    required this.labelAr,
    required this.amountIqd,
    this.isDefault = false,
  });

  final String id;
  final String labelAr;
  final num amountIqd;
  final bool isDefault;

  factory DeliveryFeeOption.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeOption(
      id: json['id'] as String,
      labelAr: (json['label_ar'] as String?) ?? '',
      amountIqd: json['amount_iqd'] as num,
      isDefault: json['is_default'] == true,
    );
  }

  @override
  List<Object?> get props => [id, labelAr, amountIqd, isDefault];
}

class DeliveryOrderSettings extends Equatable {
  const DeliveryOrderSettings({
    required this.durations,
    required this.fees,
    this.defaultDurationId,
    this.defaultFeeId,
  });

  final List<DeleteDurationOption> durations;
  final List<DeliveryFeeOption> fees;
  final String? defaultDurationId;
  final String? defaultFeeId;

  DeleteDurationOption? get defaultDuration {
    if (durations.isEmpty) return null;
    for (final d in durations) {
      if (d.id == defaultDurationId) return d;
    }
    return durations.first;
  }

  DeliveryFeeOption? get defaultFee {
    if (fees.isEmpty) return null;
    for (final f in fees) {
      if (f.id == defaultFeeId) return f;
    }
    return fees.first;
  }

  factory DeliveryOrderSettings.fromJson(Map<String, dynamic> json) {
    final durationsRaw = json['durations'];
    final feesRaw = json['fees'];
    return DeliveryOrderSettings(
      durations: durationsRaw is List
          ? durationsRaw
              .map(
                (e) => DeleteDurationOption.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
      fees: feesRaw is List
          ? feesRaw
              .map(
                (e) => DeliveryFeeOption.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
      defaultDurationId: json['default_duration_id'] as String?,
      defaultFeeId: json['default_fee_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [durations, fees, defaultDurationId, defaultFeeId];
}

class CouponValidation extends Equatable {
  const CouponValidation({
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountIqd,
    this.deliveryFeeIqd,
    this.deliveryFeeFinal,
  });

  final String code;
  final String discountType;
  final num discountValue;
  final num discountIqd;
  final num? deliveryFeeIqd;
  final num? deliveryFeeFinal;

  factory CouponValidation.fromJson(Map<String, dynamic> json) {
    return CouponValidation(
      code: (json['code'] as String?) ?? '',
      discountType: (json['discount_type'] as String?) ?? '',
      discountValue: json['discount_value'] as num? ?? 0,
      discountIqd: json['discount_iqd'] as num? ?? 0,
      deliveryFeeIqd: json['delivery_fee_iqd'] as num?,
      deliveryFeeFinal: json['delivery_fee_final'] as num?,
    );
  }

  @override
  List<Object?> get props => [
        code,
        discountType,
        discountValue,
        discountIqd,
        deliveryFeeIqd,
        deliveryFeeFinal,
      ];
}

enum DestinationType { current, map }

class DestinationChoice extends Equatable {
  const DestinationChoice({
    required this.type,
    this.lat,
    this.lng,
    this.address,
  });

  final DestinationType type;
  final double? lat;
  final double? lng;
  final String? address;

  DestinationChoice copyWith({
    DestinationType? type,
    double? lat,
    double? lng,
    String? address,
  }) {
    return DestinationChoice(
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
    );
  }

  @override
  List<Object?> get props => [type, lat, lng, address];
}

class CreateDeliveryOrderInput extends Equatable {
  const CreateDeliveryOrderInput({
    required this.details,
    required this.deleteDuration,
    required this.feeOption,
    required this.destination,
    this.couponCode,
  });

  final String details;
  final DeleteDurationOption deleteDuration;
  final DeliveryFeeOption feeOption;
  final DestinationChoice destination;
  final String? couponCode;

  @override
  List<Object?> get props => [
        details,
        deleteDuration,
        feeOption,
        destination,
        couponCode,
      ];
}

class DeliveryOrder extends Equatable {
  const DeliveryOrder({
    required this.id,
    required this.orderTypeName,
    required this.details,
    required this.status,
    required this.createdAt,
    this.requestNumber,
    this.deliveryFeeIqd,
    this.couponDiscountIqd,
    this.deliveryFeeFinal,
    this.destinationType,
    this.destinationLat,
    this.destinationLng,
    this.destinationAddress,
    this.destinationLabel,
    this.expiresAt,
    this.acceptedAt,
    this.completedAt,
    this.captainName,
    this.captainPhone,
  });

  final String id;
  final int? requestNumber;
  final String orderTypeName;
  final String details;
  final String status;
  final DateTime createdAt;
  final num? deliveryFeeIqd;
  final num? couponDiscountIqd;
  final num? deliveryFeeFinal;
  final String? destinationType;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationAddress;
  final String? destinationLabel;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? captainName;
  final String? captainPhone;

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';
  bool get isOngoing => status == 'pending' || status == 'active';
  bool get isPrevious => status == 'cancelled';
  bool get isPast =>
      status == 'completed' || status == 'cancelled' || status == 'expired';

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parseTs(Object? raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    int? parseRequestNumber(Object? raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString());
    }

    return DeliveryOrder(
      id: json['id'] as String,
      requestNumber: parseRequestNumber(json['request_number']),
      orderTypeName: (json['order_type_name'] as String?) ?? '',
      details: (json['details'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      createdAt: parseTs(json['created_at']) ?? DateTime.now().toUtc(),
      deliveryFeeIqd: json['delivery_fee_iqd'] as num?,
      couponDiscountIqd: json['coupon_discount_iqd'] as num?,
      deliveryFeeFinal: json['delivery_fee_final'] as num?,
      destinationType: json['destination_type'] as String?,
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      destinationAddress: json['destination_address'] as String?,
      destinationLabel: json['destination_label'] as String?,
      expiresAt: parseTs(json['expires_at']),
      acceptedAt: parseTs(json['accepted_at']),
      completedAt: parseTs(json['completed_at']),
      captainName: json['captain_name'] as String?,
      captainPhone: json['captain_phone'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        requestNumber,
        orderTypeName,
        details,
        status,
        createdAt,
        deliveryFeeIqd,
        couponDiscountIqd,
        deliveryFeeFinal,
        destinationType,
        destinationLat,
        destinationLng,
        destinationAddress,
        destinationLabel,
        expiresAt,
        acceptedAt,
        completedAt,
        captainName,
        captainPhone,
      ];
}

class HomeAd extends Equatable {
  const HomeAd({
    required this.id,
    this.titleAr,
    this.imageUrl,
    this.actionType = HomeAdActionType.none,
    this.linkUrl,
    this.whatsappPhone,
  });

  final String id;
  final String? titleAr;
  final String? imageUrl;
  final HomeAdActionType actionType;
  final String? linkUrl;
  final String? whatsappPhone;

  bool get isTappable => switch (actionType) {
        HomeAdActionType.link => linkUrl != null && linkUrl!.trim().isNotEmpty,
        HomeAdActionType.whatsapp =>
          whatsappPhone != null && whatsappPhone!.trim().isNotEmpty,
        HomeAdActionType.none => false,
      };

  @override
  List<Object?> get props => [
        id,
        titleAr,
        imageUrl,
        actionType,
        linkUrl,
        whatsappPhone,
      ];
}

enum HomeAdActionType {
  none,
  link,
  whatsapp;

  static HomeAdActionType fromWire(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'link' => HomeAdActionType.link,
      'whatsapp' => HomeAdActionType.whatsapp,
      _ => HomeAdActionType.none,
    };
  }
}
