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
/// type-specific icons, and optimistic mark-as-read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
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
    if (_isLoadingMore) return;

    final notifier = ref.read(notificationListProvider.notifier);
    if (!notifier.hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    await ref.read(notificationListProvider.notifier).loadMore();

    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _refresh() async {
    ref.invalidate(notificationListProvider);
    ref.invalidate(unreadCountProvider);
  }

  void _onTap(AppNotification notification) {
    if (!notification.isRead) {
      ref.read(notificationListProvider.notifier).markAsRead(notification.id);
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
          context.push('/recipe/${notification.recipeId}');
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
    ref.listen(notificationListProvider, (_, next) {
      next.whenData((notifications) {
        if (notifications.isEmpty ||
            notifications.every((notification) => notification.isRead)) {
          return;
        }

        Future.microtask(() {
          if (!mounted) return;
          ref.read(notificationListProvider.notifier).markAllAsRead();
        });
      });
    });

    final listAsync = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text(
          'Notifications',
          style: AppTheme.displayTitleMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear all notifications?'),
                  content: const Text(
                    'This will permanently delete all your notifications.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref
                    .read(notificationListProvider.notifier)
                    .clearNotifications();
              }
            },
            child: Text(
              'Clear notifications',
              style: context.textTheme.bodySmall?.copyWith(
                color: AppTheme.accentPlayful,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: listAsync.when(
        // On refresh (e.g. app resume, foreground push), keep showing the
        // existing list instead of flashing shimmer. Shimmer only shows on
        // the very first load when there is no cached data.
        skipLoadingOnRefresh: true,
        loading: () => const NotificationListShimmer(),
        error: (error, _) => _ErrorBody(
          message: error.toString(),
          onRetry: _refresh,
        ),
        data: (notifications) {
          if (notifications.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.accentPlayful,
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppTheme.spacingLg),
              itemCount: notifications.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacing16 + 48 + AppTheme.spacing12,
                  right: AppTheme.spacing16,
                ),
                child: Container(height: 1, color: AppTheme.gray100),
              ),
              itemBuilder: (context, index) {
                if (index == notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _NotificationTile(
                  notification: notifications[index],
                  onTap: () => _onTap(notifications[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Notification tile ────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// Returns a color for the type badge based on notification type.
  Color _badgeColor() {
    switch (notification.type) {
      case 'new_follower':
      case 'follow_request':
      case 'follow_accepted':
        return AppTheme.primaryColor;
      case 'recipe_liked':
        return AppTheme.likeColor;
      case 'recipe_forked':
      case 'recipe_shared':
        return AppTheme.success;
      case 'schedule_suggestion':
      case 'suggestion_approved':
      case 'suggestion_denied':
        return AppTheme.warning;
      case 'kitchen_joined':
      case 'kitchen_removed':
        return AppTheme.info;
      default:
        return AppTheme.gray400;
    }
  }

  /// Returns an icon for the type badge based on notification type.
  IconData _badgeIcon() {
    switch (notification.type) {
      case 'new_follower':
      case 'follow_accepted':
        return Icons.person_add_rounded;
      case 'follow_request':
        return Icons.person_outline_rounded;
      case 'recipe_liked':
        return Icons.favorite_rounded;
      case 'recipe_forked':
        return Icons.autorenew_rounded;
      case 'recipe_shared':
        return Icons.share_rounded;
      case 'schedule_suggestion':
      case 'suggestion_approved':
      case 'suggestion_denied':
        return Icons.calendar_today_rounded;
      case 'kitchen_joined':
      case 'kitchen_removed':
        return Icons.people_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _badgeColor();

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? null
            : AppTheme.primaryLight.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with type badge overlay
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    fullName: notification.actorName ?? '?',
                    profilePictureUrl: notification.actorPhoto,
                    size: 44,
                  ),
                  // Type icon badge (bottom-right of avatar)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: notification.isRead
                              ? Colors.white
                              : AppTheme.primaryLight.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _badgeIcon(),
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            // Message and timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    _buildMessageSpan(context),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.shareMessage?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: AppTheme.spacing6),
                    Text(
                      '"${notification.shareMessage!.trim()}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppTheme.gray500,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    timeAgo(notification.createdAt),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: AppTheme.gray400,
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.isRead)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.spacing6,
                  left: AppTheme.spacing8,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a rich text span with the actor name in bold.
  TextSpan _buildMessageSpan(BuildContext context) {
    final style = context.textTheme.bodyMedium?.copyWith(
      fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w500,
      color: AppTheme.gray800,
    );
    final boldStyle = style?.copyWith(fontWeight: FontWeight.w700);

    final actor = notification.actorName;
    final message = notification.displayMessage;

    // If we have an actor name, bold it within the message.
    if (actor != null && message.startsWith(actor)) {
      return TextSpan(
        children: [
          TextSpan(text: actor, style: boldStyle),
          TextSpan(text: message.substring(actor.length), style: style),
        ],
      );
    }

    return TextSpan(text: message, style: style);
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 36,
                color: AppTheme.gray300,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              'No notifications yet',
              style: context.textTheme.titleMedium?.copyWith(
                color: AppTheme.gray900,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              'When someone follows you, likes your recipes, or\ninteracts with your kitchen, it will show up here.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ──────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.all(AppTheme.spacing48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Something went wrong',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
