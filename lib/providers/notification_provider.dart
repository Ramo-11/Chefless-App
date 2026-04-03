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

// ── Unread badge count ───────────────────────────────────────────────────────

/// Total unread notification count for the bell badge in [AppTopBar].
///
/// Re-fetches automatically when:
/// - A foreground push arrives (via [foregroundNotificationStream]).
/// - The provider is explicitly invalidated (e.g. after markAsRead).
final unreadCountProvider = FutureProvider<int>((ref) async {
  // Re-evaluate whenever a foreground notification arrives.
  ref.watch(foregroundNotificationStream);

  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/notifications/unread-count');

  if (result.isFailure || result.data == null) return 0;
  return result.data!['count'] as int? ?? 0;
});

// ── Notification list with pagination ────────────────────────────────────────

/// Manages the unread notification list with pagination and real-time updates.
///
/// Only unread notifications are shown. When a notification is marked as read
/// (individually or via "mark all"), it is immediately removed from the list.
/// This keeps the list as a true "unread" inbox — it empties as you read.
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
    // Watch the foreground stream — re-runs build() (fetches page 1) whenever
    // a new push arrives, keeping the list fresh.
    ref.watch(foregroundNotificationStream);

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

    // Pagination uses the raw count so we don't miss unread items on later pages.
    if (rawItems.length < 20) _hasMore = false;

    // Only surface unread notifications — the list is an "inbox" view.
    return rawItems.where((n) => !n.isRead).toList();
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
    } catch (_) {
      // Don't replace the whole list with an error — the user can retry
      // by scrolling again.
    }
  }

  /// Marks a single notification as read and removes it from the list.
  ///
  /// The item disappears immediately (optimistic). The server is updated
  /// fire-and-forget in the background.
  void markAsRead(String id) {
    final current = state.valueOrNull;
    if (current == null) return;

    // Remove from list — it has been read.
    state = AsyncData(current.where((n) => n.id != id).toList());

    // Fire-and-forget server sync.
    ref.read(apiServiceProvider.future).then((api) {
      api.post('/notifications/read', data: {'ids': [id]});
    });
    ref.invalidate(unreadCountProvider);
  }

  /// Marks all notifications as read and clears the list immediately.
  ///
  /// The list empties on the spot (optimistic). The server is updated
  /// fire-and-forget; if the call fails the server will remain consistent
  /// with the unread state but the local view stays cleared.
  void markAllAsRead() {
    final current = state.valueOrNull;
    if (current == null) return;

    // Clear the list — all notifications have been read.
    state = const AsyncData([]);

    // Fire-and-forget server sync.
    ref.read(apiServiceProvider.future).then((api) {
      api.post('/notifications/read-all');
    });
    ref.invalidate(unreadCountProvider);
  }
}
