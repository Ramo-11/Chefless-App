import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../utils/extensions.dart';

/// Main settings screen with sections for account, notifications,
/// subscription, kitchen, about, delete, and sign-out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account Settings
          const _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon.')),
              );
            },
          ),
          const Divider(),

          // Notifications
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification Preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/notifications'),
          ),
          const Divider(),

          // Subscription
          const _SectionHeader(title: 'Subscription'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Subscription Management'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/paywall'),
          ),
          const Divider(),

          // Kitchen
          const _SectionHeader(title: 'Kitchen'),
          _KitchenSettingsSection(),
          const Divider(),

          // About
          const _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Chefless'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon.')),
              );
            },
          ),
          const Divider(),

          // Danger zone
          const _SectionHeader(title: 'Danger Zone'),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: context.colorScheme.error,
            ),
            title: Text(
              'Delete Account',
              style: TextStyle(color: context.colorScheme.error),
            ),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: context.colorScheme.error,
            ),
            title: Text(
              'Sign Out',
              style: TextStyle(color: context.colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: AppTheme.spacingXl),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is permanent and cannot be undone. All your recipes, '
          'followers, and data will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final apiService =
                  await ref.read(apiServiceProvider.future);
              final result = await apiService.delete('/users/me');
              if (result.isSuccess) {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.error ?? 'Failed to delete account.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}

class _KitchenSettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenAsync = ref.watch(myKitchenProvider);

    return kitchenAsync.when(
      data: (detail) {
        if (detail == null) {
          // Not in a kitchen — show create/join options.
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create Kitchen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/kitchen/create'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('Join Kitchen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/kitchen/join'),
              ),
            ],
          );
        }

        // Already in a kitchen — show kitchen name and link.
        return ListTile(
          leading: const Icon(Icons.kitchen_outlined),
          title: Text(detail.kitchen.name),
          subtitle: Text(
            '${detail.kitchen.memberCount} member${detail.kitchen.memberCount == 1 ? '' : 's'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/kitchen'),
        );
      },
      loading: () => const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Loading kitchen...'),
      ),
      error: (_, _) => ListTile(
        leading: const Icon(Icons.kitchen_outlined),
        title: const Text('Kitchen'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/kitchen'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingMd,
        right: AppTheme.spacingMd,
        top: AppTheme.spacingLg,
        bottom: AppTheme.spacingSm,
      ),
      child: Text(
        title,
        style: context.textTheme.labelLarge?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
