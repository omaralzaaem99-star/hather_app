import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/features/notifications/data/notifications_repository.dart';
import 'package:hather_app/features/notifications/domain/entities/user_notification.dart';

const kNotificationsPageSize = 30;

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) {
    return FakeNotificationsRemoteDataSource();
  }
  return SupabaseNotificationsRemoteDataSource();
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(
    remote: ref.watch(notificationsRemoteDataSourceProvider),
  );
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final result = await ref.watch(notificationsRepositoryProvider).getUnreadCount();
  return result.when(
    success: (value) => value,
    onFailure: (_) => 0,
  );
});

class NotificationsListState {
  const NotificationsListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  final List<UserNotification> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  bool get hasUnread => items.any((n) => !n.isRead);

  NotificationsListState copyWith({
    List<UserNotification>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class NotificationsListController extends Notifier<NotificationsListState> {
  @override
  NotificationsListState build() {
    Future.microtask(refresh);
    return const NotificationsListState(isLoading: true);
  }

  NotificationsRepository get _repo =>
      ref.read(notificationsRepositoryProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repo.getMyNotifications(
      limit: kNotificationsPageSize,
      offset: 0,
    );
    result.when(
      success: (items) {
        state = NotificationsListState(
          items: items,
          isLoading: false,
          hasMore: items.length >= kNotificationsPageSize,
        );
        ref.invalidate(unreadNotificationCountProvider);
      },
      onFailure: (error) {
        if (kDebugMode) {
          debugPrint('NOTIFICATIONS_LOAD_ERROR: $error');
        }
        // Never surface raw Failure.message / RPC / HTTP text to the user.
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'تعذر تحميل الإشعارات. حاول مرة أخرى.',
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    final result = await _repo.getMyNotifications(
      limit: kNotificationsPageSize,
      offset: state.items.length,
    );
    result.when(
      success: (items) {
        state = state.copyWith(
          items: [...state.items, ...items],
          isLoadingMore: false,
          hasMore: items.length >= kNotificationsPageSize,
        );
      },
      onFailure: (_) {
        state = state.copyWith(isLoadingMore: false);
      },
    );
  }

  Future<void> markRead(String notificationId) async {
    final result = await _repo.markRead(notificationId);
    if (!result.isSuccess) return;
    state = state.copyWith(
      items: state.items
          .map(
            (n) => n.id == notificationId
                ? UserNotification(
                    id: n.id,
                    type: n.type,
                    title: n.title,
                    body: n.body,
                    orderId: n.orderId,
                    supportRequestId: n.supportRequestId,
                    tapDestination: n.tapDestination,
                    isRead: true,
                    readAt: n.readAt ?? DateTime.now(),
                    createdAt: n.createdAt,
                  )
                : n,
          )
          .toList(),
    );
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markAllRead() async {
    final result = await _repo.markAllRead();
    if (!result.isSuccess) return;
    final now = DateTime.now();
    state = state.copyWith(
      items: state.items
          .map(
            (n) => n.isRead
                ? n
                : UserNotification(
                    id: n.id,
                    type: n.type,
                    title: n.title,
                    body: n.body,
                    orderId: n.orderId,
                    supportRequestId: n.supportRequestId,
                    tapDestination: n.tapDestination,
                    isRead: true,
                    readAt: now,
                    createdAt: n.createdAt,
                  ),
          )
          .toList(),
    );
    ref.invalidate(unreadNotificationCountProvider);
  }
}

final notificationsListControllerProvider =
    NotifierProvider<NotificationsListController, NotificationsListState>(
  NotificationsListController.new,
);
