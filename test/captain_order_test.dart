import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/features/captain/data/captain_order_error_mapper.dart';
import 'package:hather_app/features/captain/data/datasources/captain_order_remote_datasource.dart';
import 'package:hather_app/features/captain/domain/entities/captain_order.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('parseAvailableOrdersJson maps RPC payload', () {
    final orders = parseAvailableOrdersJson([
      {
        'id': 'o1',
        'request_number': 100001,
        'order_type_name': 'طعام',
        'details': 'وجبة',
        'destination_label': 'الكرادة',
        'delivery_fee_iqd': 3000,
        'created_at': '2026-01-01T10:00:00Z',
        'expires_at': '2026-01-01T11:00:00Z',
      },
    ]);

    expect(orders, hasLength(1));
    expect(orders.first.orderTypeName, 'طعام');
    expect(orders.first.requestNumber, 100001);
    expect(orders.first.destinationLabel, 'الكرادة');
  });

  test('parseMyOrdersJson includes status', () {
    final orders = parseMyOrdersJson([
      {
        'id': 'o2',
        'request_number': 100002,
        'order_type_name': 'مشتريات',
        'details': 'بقالة',
        'destination_label': 'موقع على الخريطة',
        'delivery_fee_iqd': 5000,
        'status': 'active',
        'created_at': '2026-01-01T10:00:00Z',
        'accepted_at': '2026-01-01T10:05:00Z',
        'expires_at': '2026-01-01T11:00:00Z',
      },
    ]);

    expect(orders.first.status, 'active');
    expect(orders.first.isActive, isTrue);
  });

  test('mapCaptainOrderError maps race condition message', () {
    final failure = mapCaptainOrderError(
      const PostgrestException(
        message: 'تم قبول هذا الطلب من كابتن آخر',
        code: 'P0001',
      ),
    );

    expect(failure, isA<ServerFailure>());
    expect(
      (failure as ServerFailure).message,
      contains('كابتن آخر'),
    );
  });

  test('mapCaptainOrderError maps subscription message', () {
    final failure = mapCaptainOrderError(
      const PostgrestException(
        message: 'اشتراكك غير فعال. فعّل الاشتراك لتتمكن من قبول الطلبات.',
        code: 'P0001',
      ),
    );
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).message, contains('اشتراكك غير فعال'));
  });

  test('parseMyOrdersJson includes completed_at', () {
    final orders = parseMyOrdersJson([
      {
        'id': 'o3',
        'request_number': 100003,
        'order_type_name': 'طلب دلفري',
        'details': 'تم',
        'destination_label': 'الكرادة',
        'delivery_fee_iqd': 3000,
        'status': 'completed',
        'created_at': '2026-01-01T10:00:00Z',
        'accepted_at': '2026-01-01T10:05:00Z',
        'completed_at': '2026-01-01T10:40:00Z',
        'expires_at': '2026-01-01T11:00:00Z',
      },
    ]);

    expect(orders.first.isCompleted, isTrue);
    expect(orders.first.completedAt, isNotNull);
  });

  test('mapCaptainOrderError maps complete denial messages', () {
    expect(
      (mapCaptainOrderError(
        const PostgrestException(
          message: 'لا يمكنك إكمال هذا الطلب',
          code: 'P0001',
        ),
      ) as ServerFailure)
          .message,
      'لا يمكنك إكمال هذا الطلب',
    );
    expect(
      (mapCaptainOrderError(
        const PostgrestException(
          message: 'تم إكمال الطلب مسبقاً',
          code: 'P0001',
        ),
      ) as ServerFailure)
          .message,
      'تم إكمال الطلب مسبقاً',
    );
    expect(
      (mapCaptainOrderError(
        const PostgrestException(
          message: 'هذا الطلب لم يعد جارياً',
          code: 'P0001',
        ),
      ) as ServerFailure)
          .message,
      'هذا الطلب لم يعد جارياً',
    );
    expect(
      (mapCaptainOrderError(
        const PostgrestException(
          message: 'captain only',
          code: 'P0001',
        ),
      ) as ServerFailure)
          .message,
      'لا يمكنك إكمال هذا الطلب',
    );
  });

  test('fake completeOrder marks active order completed', () async {
    final remote = FakeCaptainOrderRemoteDataSource(
      myOrders: [
        CaptainMyOrder(
          id: 'a1',
          requestNumber: 100010,
          orderTypeName: 'طلب دلفري',
          details: 'اختبار',
          destinationLabel: 'الكرادة',
          deliveryFeeIqd: 3000,
          status: 'active',
          createdAt: DateTime.utc(2026, 1, 1),
          acceptedAt: DateTime.utc(2026, 1, 1, 10),
        ),
      ],
    );

    final detail = await remote.completeOrder('a1');
    expect(detail.status, 'completed');
    expect(detail.completedAt, isNotNull);
    expect(detail.requestNumber, 100010);
  });

  test('parseOrderDetailJson uses delivery_fee_final snapshot', () {
    final detail = parseOrderDetailJson({
      'id': 'd1',
      'request_number': 100006,
      'order_type_name': 'طلب دلفري',
      'details': 'دجاج',
      'status': 'active',
      'delivery_fee_iqd': 5000,
      'coupon_discount_iqd': 1000,
      'delivery_fee_final': 4000,
      'destination_type': 'map',
      'destination_label': 'جمعية',
      'destination_lat': 32.01,
      'destination_lng': 44.4,
      'destination_address': 'جمعية قرب مكتب الأخضر',
      'created_at': '2026-01-01T10:00:00Z',
      'accepted_at': '2026-01-01T10:05:00Z',
      'customer_name': 'أبو أحمد مبرمج',
      'customer_phone': '+9647756888722',
    });

    expect(detail.effectiveDeliveryFee, 4000);
    expect(detail.hasGps, isTrue);
    expect(detail.customerName, 'أبو أحمد مبرمج');
  });

  test('mapCaptainOrderError maps transfer denial messages', () {
    expect(
      (mapCaptainOrderError(
        const PostgrestException(
          message: 'لا يمكنك تحويل هذا الطلب',
          code: 'P0001',
        ),
      ) as ServerFailure)
          .message,
      contains('تحويل'),
    );
    expect(
      (mapCaptainOrderError(
        const PostgrestException(
          message: 'انتهت صلاحية هذا الطلب ولا يمكن تحويله',
          code: 'P0001',
        ),
      ) as ServerFailure)
          .message,
      contains('ولا يمكن تحويله'),
    );
    expect(
      (mapCaptainOrderError(
        const PostgrestException(
          message: 'لا يمكن تحويل طلب مكتمل',
          code: 'P0001',
        ),
      ) as ServerFailure)
          .message,
      'لا يمكن تحويل طلب مكتمل',
    );
  });

  test('fake transfer removes order from myOrders', () async {
    final remote = FakeCaptainOrderRemoteDataSource(
      myOrders: [
        CaptainMyOrder(
          id: 't1',
          requestNumber: 100011,
          orderTypeName: 'طلب دلفري',
          details: 'اختبار',
          destinationLabel: 'الكرادة',
          deliveryFeeIqd: 3000,
          status: 'active',
          createdAt: DateTime.utc(2026, 1, 1),
          acceptedAt: DateTime.utc(2026, 1, 1, 10),
        ),
      ],
    );

    await remote.reportCustomerNoAnswer('t1');
    expect(remote.lastNoAnswerOrderId, 't1');

    await remote.transferOrder(orderId: 't1', reason: 'مشكلة في المركبة');
    expect(remote.lastTransferredOrderId, 't1');
    expect(remote.lastTransferReason, 'مشكلة في المركبة');
    expect(remote.myOrders, isEmpty);
  });
}
