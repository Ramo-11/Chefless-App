import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';
import '../utils/navigator_keys.dart';

/// Wraps the app's root widget and shows an animated in-app banner whenever
/// a push notification arrives while the app is in the foreground.
///
/// Place this inside [MaterialApp.router]'s `builder` so it renders above
/// all routes but below the system status bar.
class NotificationBannerOverlay extends ConsumerStatefulWidget {
  const NotificationBannerOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationBannerOverlay> createState() =>
      _NotificationBannerOverlayState();
}

class _NotificationBannerOverlayState
    extends ConsumerState<NotificationBannerOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _notificationRefreshInterval = Duration(seconds: 12);

  RemoteMessage? _currentMessage;
  Timer? _autoDismissTimer;
  Timer? _refreshTimer;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _refreshNotifications();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoDismissTimer?.cancel();
    _refreshTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// When the app returns from background, re-fetch the unread count and
  /// notification list. Notifications that arrived while backgrounded won't
  /// trigger [foregroundNotificationStream], so we need this to stay current.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotifications();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      _notificationRefreshInterval,
      (_) => _refreshNotifications(),
    );
  }

  void _refreshNotifications() {
    if (!mounted) return;
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationListProvider);
  }

  void _showBanner(RemoteMessage message) {
    _autoDismissTimer?.cancel();
    setState(() => _currentMessage = message);
    _animController.forward(from: 0);
    _autoDismissTimer = Timer(const Duration(seconds: 4), _hideBanner);
  }

  void _hideBanner() {
    _autoDismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) setState(() => _currentMessage = null);
    });
  }

  void _onTap() {
    final data = _currentMessage?.data;
    _hideBanner();

    if (data == null) return;

    // Use the explicit route from the push payload, or fall back to
    // the notifications screen.
    final route = data['route'] as String? ?? '/notifications';

    // The banner sits above the Router in the widget tree, so we use
    // the root navigator key to get a context inside the GoRouter tree.
    final navContext = rootNavigatorKey.currentContext;
    if (navContext != null) {
      GoRouter.of(navContext).push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for foreground push notifications.
    ref.listen(foregroundNotificationStream, (_, next) {
      next.whenData(_showBanner);
    });

    return Stack(
      children: [
        widget.child,
        if (_currentMessage != null) _buildBanner(context),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    final message = _currentMessage!;
    final title = message.notification?.title ?? 'New notification';
    final body = message.notification?.body ?? '';
    final type = message.data['type'] as String? ?? '';
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _onTap,
            // Swipe up to dismiss.
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -100) _hideBanner();
            },
            child: Container(
              margin: EdgeInsets.only(
                top: topPadding + AppTheme.spacing8,
                left: AppTheme.spacing12,
                right: AppTheme.spacing12,
              ),
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.borderRadiusMedium,
                border: Border.all(color: AppTheme.gray200),
                boxShadow: AppTheme.shadowMd,
              ),
              child: Row(
                children: [
                  // Type icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _colorForType(type).withValues(alpha: 0.10),
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    child: Icon(
                      _iconForType(type),
                      size: 18,
                      color: _colorForType(type),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.gray900,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            body,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.gray500,
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  // Close button
                  GestureDetector(
                    onTap: _hideBanner,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppTheme.gray400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers (mirror AppNotification.icon / iconColor) ────────────────────────

IconData _iconForType(String type) {
  switch (type) {
    case 'new_follower':
      return Icons.person_add_rounded;
    case 'follow_request':
      return Icons.person_add_alt_1_rounded;
    case 'follow_accepted':
      return Icons.how_to_reg_rounded;
    case 'recipe_liked':
      return Icons.favorite_rounded;
    case 'recipe_forked':
      return Icons.autorenew_rounded;
    case 'recipe_shared':
      return Icons.share_rounded;
    case 'schedule_suggestion':
      return Icons.restaurant_menu_rounded;
    case 'suggestion_approved':
      return Icons.check_circle_rounded;
    case 'suggestion_denied':
      return Icons.cancel_rounded;
    case 'kitchen_joined':
      return Icons.group_add_rounded;
    case 'kitchen_removed':
      return Icons.group_remove_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

Color _colorForType(String type) {
  switch (type) {
    case 'new_follower':
    case 'follow_request':
    case 'follow_accepted':
      return AppTheme.primaryColor;
    case 'recipe_liked':
      return AppTheme.likeColor;
    case 'recipe_forked':
      return AppTheme.primaryDark;
    case 'recipe_shared':
      return const Color(0xFF009688);
    case 'schedule_suggestion':
      return AppTheme.warning;
    case 'suggestion_approved':
      return AppTheme.success;
    case 'suggestion_denied':
      return AppTheme.error;
    case 'kitchen_joined':
      return AppTheme.info;
    case 'kitchen_removed':
      return AppTheme.error;
    default:
      return AppTheme.gray500;
  }
}
