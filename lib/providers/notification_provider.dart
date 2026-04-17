import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/fcm_service.dart';
import 'auth_provider.dart';

// ── Real-time refresh trigger ────────────────────────────────────────────────

/// Emits each time a push notification arrives while the app is in the
/// foreground. Providers that watch this automatically re-fetch when a new
/// notification lands.
final foregroundNotificationStream = StreamProvider<RemoteMessage>((ref) {
  return FcmService.foregroundMessages;
});

final _unreadCountOverrideProvider = StateProvider<int?>((ref) => null);

void refreshNotificationProviders(
  WidgetRef ref, {
  required String reason,
}) {
  developer.log(
    'Refreshing notification providers ($reason)',
    name: 'Notifications',
  );
  ref.invalidate(unreadCountProvider);
  ref.invalidate(notificationListProvider);
}

// ── Unread badge count ───────────────────────────────────────────────────────

/// Total unread notification count for the bell badge in [AppTopBar].
///
/// Re-fetches when explicitly invalidated (e.g. after markAsRead or
/// via [refreshNotificationProviders] called by the notification banner).
final unreadCountProvider = FutureProvider<int>((ref) async {
  final override = ref.watch(_unreadCountOverrideProvider);
  if (override != null) return override;

  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/notifications/unread-count');

  if (result.isFailure || result.data == null) return 0;
  final count = result.data!['count'] as int? ?? 0;
  developer.log(
    'Fetched unread notification count: $count',
    name: 'Notifications',
  );
  return count;
});

// ── Notification list with pagination ────────────────────────────────────────

/// Manages the notification list with pagination and real-time updates.
///
/// Both read and unread notifications are shown. Opening the screen marks
/// unread items as read, but they remain visible until the user explicitly
/// clears them.
final notificationListProvider =
    AsyncNotifierProvider<NotificationListNotifier, List<AppNotification>>(
  NotificationListNotifier.new,
);

class NotificationListNotifier extends AsyncNotifier<List<AppNotification>> {
  int _currentPage = 1;
  bool _hasMore = true;

  /// Whether more pages are available for infinite scroll.
  bool get hasMore => _hasMore;

  @override
  Future<List<AppNotification>> build() async {
    _currentPage = 1;
    _hasMore = true;
    return _fetchPage(1);
  }

  Future<List<AppNotification>> _fetchPage(int page) async {
    final apiService = await ref.read(apiServiceProvider.future);
    final result = await apiService.get(
      '/notifications',
      queryParameters: {'page': page, 'limit': 20},
    );

    if (result.isFailure || result.data == null) {
      throw Exception(result.error ?? 'Failed to load notifications.');
    }

    final rawItems = (result.data!['data'] as List<dynamic>? ?? [])
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();

    developer.log(
      'Fetched notifications page $page: ${rawItems.length} total, '
      '${rawItems.where((n) => !n.isRead).length} unread',
      name: 'Notifications',
    );

    if (rawItems.length < 20) _hasMore = false;
    return rawItems;
  }

  /// Loads the next page and appends to the current list.
  ///
  /// Guards against running while [build] is refreshing — if the state is
  /// loading (e.g. a foreground push triggered a rebuild), we skip to avoid
  /// appending stale pages to a list that is about to be replaced.
  Future<void> loadMore() async {
    if (!_hasMore || state is AsyncLoading) return;

    final current = state.valueOrNull ?? [];
    final nextPage = _currentPage + 1;

    try {
      final newItems = await _fetchPage(nextPage);
      _currentPage = nextPage;
      state = AsyncData([...current, ...newItems]);
    } catch (error) {
      developer.log(
        'Failed to load more notifications: $error',
        name: 'Notifications',
      );
      // Don't replace the whole list with an error — the user can retry
      // by scrolling again.
    }
  }

  /// Marks a single notification as read and keeps it visible.
  Future<void> markAsRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final previous = List<AppNotification>.from(current);
    final currentUnread = ref.read(unreadCountProvider).valueOrNull ??
        previous.where((notification) => !notification.isRead).length;

    final target = previous.cast<AppNotification?>().firstWhere(
          (notification) => notification?.id == id,
          orElse: () => null,
        );
    if (target == null || target.isRead) return;

    state = AsyncData([
      for (final notification in previous)
        if (notification.id == id)
          notification.copyWith(isRead: true)
        else
          notification,
    ]);
    ref.read(_unreadCountOverrideProvider.notifier).state =
        (currentUnread - 1).clamp(0, currentUnread);

    try {
      final api = await ref.read(apiServiceProvider.future);
      await api.post('/notifications/read', data: {'ids': [id]});
      developer.log('Marked notification as read: $id', name: 'Notifications');
    } catch (error) {
      developer.log(
        'Failed to mark notification as read: $error',
        name: 'Notifications',
      );
      state = AsyncData(previous);
    } finally {
      ref.read(_unreadCountOverrideProvider.notifier).state = null;
      ref.invalidate(unreadCountProvider);
    }
  }

  /// Marks all visible notifications as read while keeping them in the list.
  Future<void> markAllAsRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final previous = List<AppNotification>.from(current);
    if (previous.every((notification) => notification.isRead)) {
      ref.read(_unreadCountOverrideProvider.notifier).state = 0;
      ref.invalidate(unreadCountProvider);
      return;
    }

    state = AsyncData([
      for (final notification in previous) notification.copyWith(isRead: true),
    ]);
    ref.read(_unreadCountOverrideProvider.notifier).state = 0;

    try {
      final api = await ref.read(apiServiceProvider.future);
      await api.post('/notifications/read-all');
      developer.log('Marked all notifications as read', name: 'Notifications');
    } catch (error) {
      developer.log(
        'Failed to mark all notifications as read: $error',
        name: 'Notifications',
      );
      state = AsyncData(previous);
    } finally {
      ref.read(_unreadCountOverrideProvider.notifier).state = null;
      ref.invalidate(unreadCountProvider);
    }
  }

  /// Clears all notifications for the current user.
  Future<void> clearNotifications() async {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    final previous = List<AppNotification>.from(current);
    final hadUnread = previous.any((notification) => !notification.isRead);
    state = const AsyncData([]);
    if (hadUnread) {
      ref.read(_unreadCountOverrideProvider.notifier).state = 0;
    }

    try {
      final api = await ref.read(apiServiceProvider.future);
      await api.post('/notifications/clear');
    } catch (error) {
      developer.log('Failed to clear notifications: $error', name: 'Notifications');
      state = AsyncData(previous);
    } finally {
      if (hadUnread) {
        ref.read(_unreadCountOverrideProvider.notifier).state = null;
        ref.invalidate(unreadCountProvider);
      }
    }
  }
}
