import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';
import '../utils/app_help_content.dart';

/// Notification bell icon button with an unread-count badge.
///
/// Drop this into any AppBar's `actions` list to give users access
/// to the notification feed from that screen.
class NotificationBellIcon extends ConsumerWidget {
  const NotificationBellIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return IconButton(
      icon: unreadCount > 0
          ? Badge(
              label: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppTheme.likeColor,
              child: const Icon(Icons.notifications_outlined),
            )
          : const Icon(Icons.notifications_outlined),
      onPressed: () => context.push('/notifications'),
      tooltip: 'Notifications',
    );
  }
}

enum _MainTabMenuAction {
  aboutTab,
  faqs,
  customPrimary,
}

class ProfileShortcutIcon extends StatelessWidget {
  const ProfileShortcutIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.person_outline_rounded),
      onPressed: () => context.push(_profileRouteForCurrentBranch(context)),
      tooltip: 'Profile',
    );
  }
}

String _profileRouteForCurrentBranch(BuildContext context) {
  final location = GoRouterState.of(context).uri.toString();
  const branchRoots = [
    '/home',
    '/schedule',
    '/recipes',
    '/shopping',
    '/kitchen',
  ];

  for (final root in branchRoots) {
    if (location.startsWith(root)) {
      return '$root/profile';
    }
  }

  return '/home/profile';
}

class MainTabMoreButton extends StatelessWidget {
  const MainTabMoreButton({
    super.key,
    required this.topic,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onPrimaryAction,
  });

  final AppHelpTopic topic;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MainTabMenuAction>(
      icon: const Icon(Icons.more_horiz_rounded),
      tooltip: 'More',
      onSelected: (value) {
        switch (value) {
          case _MainTabMenuAction.aboutTab:
            _showTabHelpSheet(context, topic);
          case _MainTabMenuAction.faqs:
            context.push('/help/faqs');
          case _MainTabMenuAction.customPrimary:
            onPrimaryAction?.call();
        }
      },
      itemBuilder: (context) => [
        if (onPrimaryAction != null && primaryActionLabel != null)
          PopupMenuItem(
            value: _MainTabMenuAction.customPrimary,
            child: Row(
              children: [
                Icon(primaryActionIcon ?? Icons.open_in_new_rounded, size: 18),
                const SizedBox(width: AppTheme.spacing12),
                Text(primaryActionLabel!),
              ],
            ),
          ),
        const PopupMenuItem(
          value: _MainTabMenuAction.aboutTab,
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18),
              SizedBox(width: AppTheme.spacing12),
              Text('About this tab'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: _MainTabMenuAction.faqs,
          child: Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 18),
              SizedBox(width: AppTheme.spacing12),
              Text('Help & FAQs'),
            ],
          ),
        ),
      ],
    );
  }
}

void _showTabHelpSheet(BuildContext context, AppHelpTopic topic) {
  final help = appHelpForTopic(topic);

  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing20,
          AppTheme.spacing12,
          AppTheme.spacing20,
          AppTheme.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentPlayfulLight,
                    borderRadius: AppTheme.borderRadiusMedium,
                  ),
                  child: Icon(
                    help.icon,
                    color: AppTheme.accentPlayful,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        help.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        help.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.gray500,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing20),
            ...help.bullets.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: AppTheme.accentPlayful,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        bullet,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.gray700,
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/help/faqs');
                },
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: const Text('Open Help & FAQs'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class TabInfoButton extends StatelessWidget {
  const TabInfoButton({
    super.key,
    required this.topic,
  });

  final AppHelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded),
      onPressed: () => _showTabHelpSheet(context, topic),
      tooltip: 'What is this tab?',
    );
  }
}
