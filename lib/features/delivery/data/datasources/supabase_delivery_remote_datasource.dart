import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/features/delivery/data/datasources/delivery_remote_datasource.dart';
import 'package:hather_app/features/delivery/domain/entities/delivery_entities.dart';

class SupabaseDeliveryRemoteDataSource implements DeliveryRemoteDataSource {
  SupabaseDeliveryRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<OrderTypeOption>> fetchOrderTypes() async {
    final rows = await _client
        .from('order_types')
        .select('id, name_ar')
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List)
        .map(
          (row) => OrderTypeOption(
            id: row['id'] as String,
            nameAr: row['name_ar'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<DeliveryOrderSettings> fetchOrderSettings() async {
    try {
      final raw = await _client.rpc('get_delivery_order_settings');
      return DeliveryOrderSettings.fromJson(_asMap(raw));
    } on PostgrestException catch (error) {
      throw _mapPostgrest(
        error,
        context: BackendErrorContext.deliverySettings,
        debugTag: 'DELIVERY_SETTINGS_LOAD_FAILED',
      );
    }
  }

  @override
  Future<List<HomeAd>> fetchHomeAds() async {
    try {
      final rows = await _client
          .from('home_ads')
          .select(
            'id, title_ar, image_url, action_type, link_url, whatsapp_phone',
          )
          .eq('is_active', true)
          .order('sort_order')
          .order('created_at');
      return (rows as List)
          .map(
            (row) => HomeAd(
              id: row['id'] as String,
              titleAr: row['title_ar'] as String?,
              imageUrl: row['image_url'] as String?,
              actionType: HomeAdActionType.fromWire(
                row['action_type']?.toString(),
              ),
              linkUrl: row['link_url'] as String?,
              whatsappPhone: row['whatsapp_phone'] as String?,
            ),
          )
          .where((ad) {
            final url = ad.imageUrl?.trim();
            return url != null && url.isNotEmpty;
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<CouponValidation> validateCoupon({
    required String code,
    required String feeOptionId,
  }) async {
    try {
      final raw = await _client.rpc(
        'validate_delivery_coupon',
        params: <String, dynamic>{
          'p_code': code.trim(),
          'p_fee_option_id': feeOptionId,
        },
      );
      return CouponValidation.fromJson(_asMap(raw));
    } on PostgrestException catch (error) {
      throw _mapPostgrest(
        error,
        context: BackendErrorContext.deliveryCoupon,
        debugTag: 'DELIVERY_COUPON_VALIDATE_FAILED',
      );
    }
  }

  @override
  Future<DeliveryOrder> createOrder(CreateDeliveryOrderInput input) async {
    try {
      final dest = input.destination;
      if (dest.lat == null || dest.lng == null) {
        throw const ValidationFailure(message: 'موقع التوصيل مطلوب');
      }
      final details = input.details.trim();
      if (details.isEmpty) {
        throw const ValidationFailure(message: 'يرجى كتابة تفاصيل الطلب');
      }

      final raw = await _client.rpc(
        'create_own_delivery_order',
        params: <String, dynamic>{
          'p_details': details,
          'p_duration_option_id': input.deleteDuration.id,
          'p_fee_option_id': input.feeOption.id,
          'p_destination_type':
              dest.type == DestinationType.current ? 'current' : 'map',
          'p_destination_lat': dest.lat,
          'p_destination_lng': dest.lng,
          'p_destination_address': dest.address,
          'p_coupon_code': input.couponCode,
        },
      );

      return DeliveryOrder.fromJson(_asMap(raw));
    } on Failure {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrest(
        error,
        context: BackendErrorContext.deliverySubmit,
        debugTag: 'DELIVERY_ORDER_CREATE_FAILED',
      );
    }
  }

  @override
  Future<List<DeliveryOrder>> fetchMyOrders() async {
    try {
      final rows = await _client
          .from('delivery_orders')
          .select(
            'id, request_number, order_type_name, details, status, created_at, '
            'delivery_fee_iqd, coupon_discount_iqd, delivery_fee_final, '
            'destination_address, destination_type, expires_at, accepted_at, '
            'completed_at',
          )
          .inFilter('status', const [
            'pending',
            'active',
            'completed',
            'cancelled',
          ])
          // Align with captain pool: pending past expires_at must not linger
          // as "بانتظار كابتن" while captains correctly hide it.
          .or(
            'status.neq.pending,expires_at.gt.${DateTime.now().toUtc().toIso8601String()}',
          )
          .order('created_at', ascending: false);

      return (rows as List)
          .map(
            (row) => DeliveryOrder.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (error) {
      throw _mapPostgrest(
        error,
        context: BackendErrorContext.deliveryOrders,
        debugTag: 'DELIVERY_ORDERS_LOAD_FAILED',
      );
    }
  }

  @override
  Future<DeliveryOrder> getOrderDetail(String orderId) async {
    try {
      final raw = await _client.rpc(
        'get_own_delivery_order',
        params: <String, dynamic>{'p_order_id': orderId},
      );
      return DeliveryOrder.fromJson(_asMap(raw));
    } on PostgrestException catch (error) {
      throw _mapPostgrest(
        error,
        context: BackendErrorContext.deliveryDetail,
        debugTag: 'DELIVERY_ORDER_DETAIL_FAILED',
      );
    }
  }

  @override
  Future<DeliveryOrder> cancelOrder(String orderId) async {
    try {
      final raw = await _client.rpc(
        'cancel_own_delivery_order',
        params: <String, dynamic>{'p_order_id': orderId},
      );
      return DeliveryOrder.fromJson(_asMap(raw));
    } on PostgrestException catch (error) {
      throw _mapPostgrest(
        error,
        context: BackendErrorContext.deliveryCancel,
        debugTag: 'DELIVERY_ORDER_CANCEL_FAILED',
      );
    }
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const ServerFailure(message: 'استجابة غير صالحة من الخادم');
  }

  Failure _mapPostgrest(
    PostgrestException error, {
    required BackendErrorContext context,
    required String debugTag,
  }) {
    return mapBackendError(
      error,
      context: context,
      debugTag: debugTag,
    );
  }
}
