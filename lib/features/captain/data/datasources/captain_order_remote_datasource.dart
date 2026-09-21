import 'dart:convert';

import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/features/captain/data/captain_order_error_mapper.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CaptainOrderRemoteDataSource {
  Future<List<CaptainAvailableOrder>> fetchAvailableOrders();
  Future<List<CaptainMyOrder>> fetchMyOrders();
  Future<CaptainActiveOrderCapacity> fetchActiveOrderCapacity();
  Future<CaptainOrderDetail> acceptOrder(String orderId);
  Future<CaptainOrderDetail> completeOrder(String orderId);
  Future<CaptainOrderDetail> fetchMyOrderDetail(String orderId);
  Future<void> reportCustomerNoAnswer(String orderId);
  Future<void> transferOrder({required String orderId, required String reason});
}

class SupabaseCaptainOrderRemoteDataSource
    implements CaptainOrderRemoteDataSource {
  SupabaseCaptainOrderRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<CaptainAvailableOrder>> fetchAvailableOrders() async {
    logCaptainOrderEvent('CAPTAIN_AVAILABLE_ORDERS_LOAD');
    try {
      final raw = await _client.rpc('captain_list_available_orders');
      final list = _decodeJsonList(raw);
      return parseAvailableOrdersJson(list);
    } on Object catch (error) {
      logCaptainOrderEvent(
        'CAPTAIN_AVAILABLE_ORDERS_LOAD',
        detail: 'failed',
      );
      throw mapCaptainOrderError(error);
    }
  }

  @override
  Future<List<CaptainMyOrder>> fetchMyOrders() async {
    try {
      final raw = await _client.rpc('captain_list_my_orders');
      final list = _decodeJsonList(raw);
      return parseMyOrdersJson(list);
    } on Object catch (error) {
      throw mapCaptainOrderError(error);
    }
  }

  @override
  Future<CaptainActiveOrderCapacity> fetchActiveOrderCapacity() async {
    try {
      final raw = await _client.rpc('captain_get_active_order_capacity');
      final map = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
      return CaptainActiveOrderCapacity.fromJson(map);
    } on Object catch (error) {
      throw mapCaptainOrderError(error);
    }
  }

  @override
  Future<CaptainOrderDetail> acceptOrder(String orderId) async {
    logCaptainOrderEvent('CAPTAIN_ACCEPT_ORDER_START');
    try {
      final raw = await _client.rpc(
        'captain_accept_delivery_order',
        params: {'p_order_id': orderId},
      );
      final detail = parseOrderDetailJson(raw);
      logCaptainOrderEvent('CAPTAIN_ACCEPT_ORDER_SUCCESS');
      return detail;
    } on Object catch (error) {
      logCaptainOrderEvent('CAPTAIN_ACCEPT_ORDER_FAILED');
      throw mapCaptainOrderError(error);
    }
  }

  @override
  Future<CaptainOrderDetail> completeOrder(String orderId) async {
    logCaptainOrderEvent('CAPTAIN_COMPLETE_ORDER_START');
    try {
      final raw = await _client.rpc(
        'captain_complete_delivery_order',
        params: {'p_order_id': orderId},
      );
      final detail = parseOrderDetailJson(raw);
      logCaptainOrderEvent('CAPTAIN_COMPLETE_ORDER_SUCCESS');
      return detail;
    } on Object catch (error) {
      logCaptainOrderEvent('CAPTAIN_COMPLETE_ORDER_FAILED');
      throw mapCaptainOrderError(error);
    }
  }

  @override
  Future<CaptainOrderDetail> fetchMyOrderDetail(String orderId) async {
    try {
      final raw = await _client.rpc(
        'captain_get_my_order_detail',
        params: {'p_order_id': orderId},
      );
      return parseOrderDetailJson(raw);
    } on Object catch (error) {
      throw mapCaptainOrderError(error);
    }
  }

  @override
  Future<void> reportCustomerNoAnswer(String orderId) async {
    logCaptainOrderEvent('CAPTAIN_NO_ANSWER_START');
    try {
      await _client.rpc(
        'captain_report_customer_no_answer',
        params: {'p_order_id': orderId},
      );
      logCaptainOrderEvent('CAPTAIN_NO_ANSWER_SUCCESS');
    } on Object catch (error) {
      logCaptainOrderEvent('CAPTAIN_NO_ANSWER_FAILED');
      throw mapCaptainOrderError(error);
    }
  }

  @override
  Future<void> transferOrder({
    required String orderId,
    required String reason,
  }) async {
    logCaptainOrderEvent('CAPTAIN_TRANSFER_START');
    try {
      await _client.rpc(
        'captain_transfer_delivery_order',
        params: {
          'p_order_id': orderId,
          'p_reason': reason,
        },
      );
      logCaptainOrderEvent('CAPTAIN_TRANSFER_SUCCESS');
    } on Object catch (error) {
      logCaptainOrderEvent('CAPTAIN_TRANSFER_FAILED');
      throw mapCaptainOrderError(error);
    }
  }

  List<dynamic> _decodeJsonList(Object? raw) {
    if (raw is List) return raw;
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    }
    return const [];
  }
}

class FakeCaptainOrderRemoteDataSource implements CaptainOrderRemoteDataSource {
  FakeCaptainOrderRemoteDataSource({
    this.available = const [],
    List<CaptainMyOrder> myOrders = const [],
  }) : myOrders = List<CaptainMyOrder>.from(myOrders);

  final List<CaptainAvailableOrder> available;
  List<CaptainMyOrder> myOrders;
  String? lastAcceptedOrderId;
  String? lastNoAnswerOrderId;
  String? lastTransferredOrderId;
  String? lastTransferReason;

  @override
  Future<List<CaptainAvailableOrder>> fetchAvailableOrders() async {
    return available;
  }

  @override
  Future<List<CaptainMyOrder>> fetchMyOrders() async {
    return myOrders;
  }

  @override
  Future<CaptainActiveOrderCapacity> fetchActiveOrderCapacity() async {
    final active = myOrders.where((o) => o.status == 'active').length;
    const max = 99;
    return CaptainActiveOrderCapacity(
      activeCount: active,
      maxActiveOrders: max,
      atCapacity: active >= max,
    );
  }

  @override
  Future<CaptainOrderDetail> acceptOrder(String orderId) async {
    lastAcceptedOrderId = orderId;
    final match = myOrders.where((o) => o.id == orderId).firstOrNull;
    return CaptainOrderDetail(
      id: orderId,
      requestNumber: match?.requestNumber,
      orderTypeName: match?.orderTypeName ?? 'طلب',
      details: match?.details ?? '',
      status: 'active',
      deliveryFeeIqd: match?.deliveryFeeIqd ?? 0,
      couponDiscountIqd: 0,
      destinationType: 'map',
      destinationLabel: match?.destinationLabel ?? '—',
      createdAt: match?.createdAt ?? DateTime.now().toUtc(),
      acceptedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<CaptainOrderDetail> completeOrder(String orderId) async {
    final match = myOrders.where((o) => o.id == orderId).firstOrNull;
    if (match != null && match.status != 'active') {
      throw const ServerFailure(message: 'هذا الطلب لم يعد جارياً');
    }
    return CaptainOrderDetail(
      id: orderId,
      requestNumber: match?.requestNumber,
      orderTypeName: match?.orderTypeName ?? 'طلب',
      details: match?.details ?? '',
      status: 'completed',
      deliveryFeeIqd: match?.deliveryFeeIqd ?? 0,
      couponDiscountIqd: 0,
      destinationType: 'map',
      destinationLabel: match?.destinationLabel ?? '—',
      createdAt: match?.createdAt ?? DateTime.now().toUtc(),
      acceptedAt: match?.acceptedAt ?? DateTime.now().toUtc(),
      completedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<CaptainOrderDetail> fetchMyOrderDetail(String orderId) async {
    final match = myOrders.where((o) => o.id == orderId).firstOrNull;
    return CaptainOrderDetail(
      id: orderId,
      requestNumber: match?.requestNumber,
      orderTypeName: match?.orderTypeName ?? 'طلب',
      details: match?.details ?? '',
      status: match?.status ?? 'active',
      deliveryFeeIqd: match?.deliveryFeeIqd ?? 0,
      couponDiscountIqd: 0,
      deliveryFeeFinal: match?.deliveryFeeIqd ?? 0,
      destinationType: 'map',
      destinationLabel: match?.destinationLabel ?? '—',
      createdAt: match?.createdAt ?? DateTime.now().toUtc(),
      acceptedAt: match?.acceptedAt,
      completedAt: match?.completedAt,
    );
  }

  @override
  Future<void> reportCustomerNoAnswer(String orderId) async {
    lastNoAnswerOrderId = orderId;
  }

  @override
  Future<void> transferOrder({
    required String orderId,
    required String reason,
  }) async {
    lastTransferredOrderId = orderId;
    lastTransferReason = reason;
    myOrders = myOrders.where((o) => o.id != orderId).toList();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
