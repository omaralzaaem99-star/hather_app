import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/utils/result.dart';
import 'package:hather_app/features/notifications/domain/entities/user_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<UserNotification>> fetchMyNotifications({
    required int limit,
    required int offset,
  });
  Future<int> fetchUnreadCount();
  Future<bool> markRead(String notificationId);
  Future<int> markAllRead();
}

List<UserNotification> _parseList(Object? raw) {
  if (raw is! List) return const [];
  final items = <UserNotification>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      items.add(UserNotification.fromJson(item));
    } else if (item is Map) {
      items.add(UserNotification.fromJson(Map<String, dynamic>.from(item)));
    }
  }
  return items;
}

class SupabaseNotificationsRemoteDataSource
    implements NotificationsRemoteDataSource {
  SupabaseNotificationsRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<UserNotification>> fetchMyNotifications({
    required int limit,
    required int offset,
  }) async {
    try {
      final raw = await _client.rpc(
        'get_my_notifications',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return _parseList(raw);
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.notifications,
        debugTag: 'NOTIFICATIONS_LOAD_FAILED',
      );
    }
  }

  @override
  Future<int> fetchUnreadCount() async {
    try {
      final raw = await _client.rpc('get_my_unread_notification_count');
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString()) ?? 0;
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.notifications,
        debugTag: 'NOTIFICATIONS_UNREAD_COUNT_FAILED',
      );
    }
  }

  @override
  Future<bool> markRead(String notificationId) async {
    try {
      final raw = await _client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
      return raw == true;
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.notifications,
        debugTag: 'NOTIFICATION_MARK_READ_FAILED',
      );
    }
  }

  @override
  Future<int> markAllRead() async {
    try {
      final raw = await _client.rpc('mark_all_notifications_read');
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString()) ?? 0;
    } on Object catch (error) {
      throw mapBackendError(
        error,
        context: BackendErrorContext.notifications,
        debugTag: 'NOTIFICATIONS_MARK_ALL_READ_FAILED',
      );
    }
  }
}

class FakeNotificationsRemoteDataSource
    implements NotificationsRemoteDataSource {
  final List<UserNotification> _items = [];

  @override
  Future<List<UserNotification>> fetchMyNotifications({
    required int limit,
    required int offset,
  }) async {
    final slice = _items.skip(offset).take(limit).toList();
    return List.unmodifiable(slice);
  }

  @override
  Future<int> fetchUnreadCount() async =>
      _items.where((n) => !n.isRead).length;

  @override
  Future<bool> markRead(String notificationId) async {
    final index = _items.indexWhere((n) => n.id == notificationId);
    if (index < 0) return false;
    final existing = _items[index];
    if (existing.isRead) return true;
    _items[index] = UserNotification(
      id: existing.id,
      type: existing.type,
      title: existing.title,
      body: existing.body,
      orderId: existing.orderId,
      supportRequestId: existing.supportRequestId,
      isRead: true,
      readAt: DateTime.now(),
      createdAt: existing.createdAt,
    );
    return true;
  }

  @override
  Future<int> markAllRead() async {
    var count = 0;
    for (var i = 0; i < _items.length; i++) {
      final existing = _items[i];
      if (existing.isRead) continue;
      count++;
      _items[i] = UserNotification(
        id: existing.id,
        type: existing.type,
        title: existing.title,
        body: existing.body,
        orderId: existing.orderId,
        supportRequestId: existing.supportRequestId,
        isRead: true,
        readAt: DateTime.now(),
        createdAt: existing.createdAt,
      );
    }
    return count;
  }
}

class NotificationsRepository {
  NotificationsRepository({required NotificationsRemoteDataSource remote})
      : _remote = remote;

  final NotificationsRemoteDataSource _remote;

  Future<Result<List<UserNotification>>> getMyNotifications({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final items = await _remote.fetchMyNotifications(
        limit: limit,
        offset: offset,
      );
      return Success(items);
    } on Object catch (error) {
      return Err(error);
    }
  }

  Future<Result<int>> getUnreadCount() async {
    try {
      final count = await _remote.fetchUnreadCount();
      return Success(count);
    } on Object catch (error) {
      return Err(error);
    }
  }

  Future<Result<bool>> markRead(String notificationId) async {
    try {
      final ok = await _remote.markRead(notificationId);
      return Success(ok);
    } on Object catch (error) {
      return Err(error);
    }
  }

  Future<Result<int>> markAllRead() async {
    try {
      final n = await _remote.markAllRead();
      return Success(n);
    } on Object catch (error) {
      return Err(error);
    }
  }
}
