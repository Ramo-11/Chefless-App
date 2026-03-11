import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/time_utils.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/user_avatar.dart';

/// Full-screen notification feed with pagination, pull-to-refresh,
/// and tap-to-navigate.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<AppNotification> _notifications = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Trigger load when within 200px of the bottom.
    if (currentScroll >= maxScroll - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final result =
        await ref.read(notificationsProvider(nextPage).future);

    if (!mounted) return;

    setState(() {
      _isLoadingMore = false;
      if (result.isEmpty) {
        _hasMore = false;
      } else {
        _currentPage = nextPage;
        _notifications.addAll(result);
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _notifications.clear();
    });
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  void _onNotificationTap(AppNotification notification) {
    // Mark as read if unread.
    if (!notification.isRead) {
      ref
          .read(notificationActionProvider.notifier)
          .markAsRead(notification.id);
    }

    switch (notification.type) {
      case 'new_follower':
      case 'follow_request':
      case 'follow_accepted':
        if (notification.actorId != null) {
          context.push('/user/${notification.actorId}');
        }
      case 'recipe_liked':
      case 'recipe_forked':
      case 'recipe_shared':
        if (notification.recipeId != null) {
          context.push('/recipes/${notification.recipeId}');
        }
      case 'schedule_suggestion':
      case 'suggestion_approved':
      case 'suggestion_denied':
        context.go('/schedule');
      case 'kitchen_joined':
      case 'kitchen_removed':
        context.push('/kitchen');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstPageAsync = ref.watch(notificationsProvider(1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(notificationActionProvider.notifier)
                  .markAllAsRead();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: firstPageAsync.when(
        loading: () => const NotificationListShimmer(),
        error: (error, _) => _ErrorBody(
          message: error.toString(),
          onRetry: _refresh,
        ),
        data: (firstPage) {
          // Merge first page into local list on initial load.
          if (_notifications.isEmpty && firstPage.isNotEmpty) {
            // Use addAll in post-frame to avoid setState during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _notifications.isEmpty) {
                setState(() => _notifications.addAll(firstPage));
              }
            });
            // Render first page directly while waiting for setState.
            return _buildList(firstPage);
          }

          if (_notifications.isEmpty && firstPage.isEmpty) {
            return const _EmptyState();
          }

          return _buildList(_notifications);
        },
      ),
    );
  }

  Widget _buildList(List<AppNotification> items) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _NotificationTile(
            notification: items[index],
            onTap: () => _onNotificationTap(items[index]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? null
            : colorScheme.primaryContainer.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm + 4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              fullName: notification.actorName ?? '?',
              profilePictureUrl: notification.actorPhoto,
              size: 44,
            ),
            const SizedBox(width: AppTheme.spacingSm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.displayMessage,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: notification.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    timeAgo(notification.createdAt),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.spacingXs + 2,
                  left: AppTheme.spacingSm,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'No notifications yet',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'When someone interacts with you, it will show up here.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Something went wrong',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
