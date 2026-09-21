import 'package:uuid/uuid.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/features/delivery/data/datasources/delivery_remote_datasource.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';

class FakeDeliveryRemoteDataSource implements DeliveryRemoteDataSource {
  final _uuid = const Uuid();
  final List<DeliveryOrder> _orders = [];
  DateTime? _lastCreateAt;
  String? _lastDetails;
  int _nextRequestNumber = 100001;

  static const _types = [
    OrderTypeOption(id: 't1', nameAr: 'طعام'),
    OrderTypeOption(id: 't2', nameAr: 'مشتريات'),
  ];

  static const _settings = DeliveryOrderSettings(
    durations: [
      DeleteDurationOption(id: 'd1', labelAr: 'ساعة واحدة', minutes: 60),
      DeleteDurationOption(
        id: 'd5',
        labelAr: '24 ساعة',
        minutes: 1440,
        isDefault: true,
      ),
    ],
    fees: [
      DeliveryFeeOption(id: 'f2', labelAr: '3,000 د.ع', amountIqd: 3000),
      DeliveryFeeOption(
        id: 'f3',
        labelAr: '5,000 د.ع',
        amountIqd: 5000,
        isDefault: true,
      ),
    ],
    defaultDurationId: 'd5',
    defaultFeeId: 'f3',
  );

  @override
  Future<List<OrderTypeOption>> fetchOrderTypes() async => _types;

  @override
  Future<DeliveryOrderSettings> fetchOrderSettings() async => _settings;

  @override
  Future<List<HomeAd>> fetchHomeAds() async => const [];

  @override
  Future<CouponValidation> validateCoupon({
    required String code,
    required String feeOptionId,
  }) async {
    final fee = _settings.fees.where((f) => f.id == feeOptionId).firstOrNull;
    if (fee == null) {
      throw const ValidationFailure(message: 'أجرة التوصيل غير صالحة');
    }
    final normalized = code.trim().toUpperCase();
    if (normalized != 'HATHER10') {
      throw const ValidationFailure(message: 'كود الخصم غير صالح');
    }
    final discount = (fee.amountIqd * 0.10).round();
    return CouponValidation(
      code: normalized,
      discountType: 'percent',
      discountValue: 10,
      discountIqd: discount,
      deliveryFeeIqd: fee.amountIqd,
      deliveryFeeFinal: fee.amountIqd - discount,
    );
  }

  @override
  Future<DeliveryOrder> createOrder(CreateDeliveryOrderInput input) async {
    final details = input.details.trim();
    if (details.isEmpty) {
      throw const ValidationFailure(message: 'يرجى كتابة تفاصيل الطلب');
    }
    if (input.destination.lat == null || input.destination.lng == null) {
      throw const ValidationFailure(message: 'موقع التوصيل مطلوب');
    }
    final now = DateTime.now().toUtc();
    if (_lastCreateAt != null &&
        _lastDetails == details &&
        now.difference(_lastCreateAt!) < const Duration(seconds: 15)) {
      throw const ServerFailure(message: 'طلب مشابه قيد الإرسال، انتظر قليلاً');
    }

    num discount = 0;
    if (input.couponCode?.toUpperCase() == 'HATHER10') {
      discount = (input.feeOption.amountIqd * 0.10).round();
    }

    final order = DeliveryOrder(
      id: _uuid.v4(),
      requestNumber: _nextRequestNumber++,
      orderTypeName: 'طلب توصيل',
      details: details,
      status: 'pending',
      createdAt: now,
      deliveryFeeIqd: input.feeOption.amountIqd,
      couponDiscountIqd: discount,
      deliveryFeeFinal: input.feeOption.amountIqd - discount,
      destinationType:
          input.destination.type == DestinationType.current ? 'current' : 'map',
      destinationLat: input.destination.lat,
      destinationLng: input.destination.lng,
      destinationAddress: input.destination.address,
      expiresAt: now.add(Duration(minutes: input.deleteDuration.minutes)),
    );
    _orders.insert(0, order);
    _lastCreateAt = now;
    _lastDetails = details;
    return order;
  }

  @override
  Future<List<DeliveryOrder>> fetchMyOrders() async => List.unmodifiable(
        _orders.where((o) => !o.isExpired).toList(),
      );

  @override
  Future<DeliveryOrder> getOrderDetail(String orderId) async {
    final match = _orders.where((o) => o.id == orderId).firstOrNull;
    if (match == null) {
      throw const ServerFailure(message: 'الطلب غير موجود');
    }
    return match;
  }

  @override
  Future<DeliveryOrder> cancelOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw const ServerFailure(message: 'الطلب غير موجود');
    }
    final existing = _orders[index];
    if (existing.status != 'pending') {
      throw const ServerFailure(message: 'لا يمكن إلغاء هذا الطلب حالياً');
    }
    final cancelled = DeliveryOrder(
      id: existing.id,
      requestNumber: existing.requestNumber,
      orderTypeName: existing.orderTypeName,
      details: existing.details,
      status: 'cancelled',
      createdAt: existing.createdAt,
      deliveryFeeIqd: existing.deliveryFeeIqd,
      couponDiscountIqd: existing.couponDiscountIqd,
      deliveryFeeFinal: existing.deliveryFeeFinal,
      destinationType: existing.destinationType,
      destinationLat: existing.destinationLat,
      destinationLng: existing.destinationLng,
      destinationAddress: existing.destinationAddress,
      expiresAt: existing.expiresAt,
    );
    _orders[index] = cancelled;
    return cancelled;
  }
}
