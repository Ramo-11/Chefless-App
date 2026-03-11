import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notification_provider.dart';

/// Persistent top bar shown on all main tab screens.
///
/// Left: search icon -> navigates to /search.
/// Center: "Chefless" app title.
/// Right: notification bell with unread count badge -> navigates to
/// /notifications.
class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.search),
        onPressed: () => context.push('/search'),
        tooltip: 'Search',
      ),
      title: const Text('Chefless'),
      centerTitle: true,
      actions: [
        IconButton(
          icon: unreadCount > 0
              ? Badge(
                  label: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_outlined),
                )
              : const Icon(Icons.notifications_outlined),
          onPressed: () => context.push('/notifications'),
          tooltip: 'Notifications',
        ),
      ],
    );
  }
}
