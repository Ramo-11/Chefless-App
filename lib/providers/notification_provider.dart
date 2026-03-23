import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import 'auth_provider.dart';

/// Fetches a paginated list of notifications for the current user.
///
/// The [int] parameter is the page number (1-based).
final notificationsProvider = FutureProvider.family<List<AppNotification>, int>(
  (ref, page) async {
    final apiService = await ref.watch(apiServiceProvider.future);
    final result = await apiService.get(
      '/notifications',
      queryParameters: {'page': page, 'limit': 20},
    );

    if (result.isFailure || result.data == null) {
      throw Exception(result.error ?? 'Failed to load notifications.');
    }

    final notifications = result.data!['data'] as List<dynamic>? ?? [];
    return notifications
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();
  },
);

/// The total unread notification count for the current user.
///
/// Used by the bell badge in [AppTopBar].
final unreadCountProvider = FutureProvider<int>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/notifications/unread-count');

  if (result.isFailure || result.data == null) {
    return 0;
  }

  return result.data!['count'] as int? ?? 0;
});

/// Manages notification actions: marking individual or all notifications
/// as read.
class NotificationActionNotifier extends StateNotifier<AsyncValue<void>> {
  NotificationActionNotifier(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  /// Marks a single notification as read via POST /notifications/read.
  Future<void> markAsRead(String notificationId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/notifications/read',
        data: {
          'ids': [notificationId],
        },
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to mark as read.');
      }
      _ref.invalidate(unreadCountProvider);
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  /// Marks all notifications as read via POST /notifications/read-all.
  Future<void> markAllAsRead() async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/notifications/read-all');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to mark all as read.');
      }
      _ref.invalidate(unreadCountProvider);
      // Invalidate all cached notification pages so they reflect the read
      // state on next fetch.
      _ref.invalidate(notificationsProvider);
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }
}

final notificationActionProvider =
    StateNotifierProvider<NotificationActionNotifier, AsyncValue<void>>((ref) {
  return NotificationActionNotifier(ref);
});
