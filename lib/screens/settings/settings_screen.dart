import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../services/fcm_service.dart';
import '../../utils/constants.dart';
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
            onTap: RevenueCatConstants.isConfigured
                ? () => context.push('/paywall')
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Subscriptions are not available yet.'),
                      ),
                    ),
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
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl('https://chefless-web.onrender.com/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () =>
                _openUrl('https://chefless-web.onrender.com/privacy'),
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
              // Clear FCM token before signing out so the server
              // stops sending push notifications to this device.
              try {
                final apiService =
                    await ref.read(apiServiceProvider.future);
                await FcmService(apiService: apiService).clearToken();
              } catch (_) {
                // Best effort — don't block sign-out if this fails.
              }
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

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Chefless',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset(
        'assets/images/logo.png',
        width: 48,
        height: 48,
      ),
      children: [
        const Text(
          'Your kitchen, your recipes, your way.\n\n'
          'Chefless is a social recipe and meal planning app for families '
          'and food enthusiasts. Organize recipes, plan meals with your '
          'Kitchen group, and discover dishes from the community.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Built by Sahab Solutions.',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
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
              await _executeAccountDeletion(context, ref);
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAccountDeletion(
    BuildContext context,
    WidgetRef ref, {
    String? password,
  }) async {
    final authService = ref.read(authServiceProvider);
    final apiService = await ref.read(apiServiceProvider.future);

    // 1. Delete user data from MongoDB
    final result = await apiService.delete('/users/me');
    if (!result.isSuccess) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to delete account.'),
          ),
        );
      }
      return;
    }

    // 2. Delete from Firebase Auth (re-authenticates automatically)
    final authResult =
        await authService.deleteFirebaseUser(password: password);

    if (!authResult.success) {
      // Email/password users need to enter their password to verify
      if (authResult.error == 'requires-password' && context.mounted) {
        _showPasswordDialog(context, ref);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authResult.error ?? 'Failed to remove sign-in credentials.',
            ),
          ),
        );
      }
    }

    // 3. Navigate to welcome
    if (context.mounted) {
      context.go('/welcome');
    }
  }

  void _showPasswordDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Your Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outlined),
          ),
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
              await _executeAccountDeletion(
                context,
                ref,
                password: controller.text,
              );
            },
            child: const Text('Confirm Delete'),
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
