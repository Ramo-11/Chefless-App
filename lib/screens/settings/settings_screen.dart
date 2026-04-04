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
        padding: const EdgeInsets.only(bottom: AppTheme.spacing48),
        children: [
          // ── Account Section ──────────────────────────────────
          const _SectionHeader(title: 'ACCOUNT'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Account Settings',
                onTap: () => context.push('/settings/account'),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notification Preferences',
                onTap: () => context.push('/settings/notifications'),
              ),
            ],
          ),

          // ── Subscription Section ────────────────────────────
          const _SectionHeader(title: 'SUBSCRIPTION'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.workspace_premium_outlined,
                iconColor: AppTheme.primaryColor,
                title: 'Subscription Management',
                onTap: RevenueCatConstants.isConfigured
                    ? () => context.push('/paywall')
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Subscriptions are not available yet.'),
                          ),
                        ),
              ),
            ],
          ),

          // ── Kitchen Section ─────────────────────────────────
          const _SectionHeader(title: 'KITCHEN'),
          _KitchenSettingsSection(),

          // ── About Section ───────────────────────────────────
          const _SectionHeader(title: 'ABOUT'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About Chefless',
                onTap: () => _showAboutDialog(context),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                trailingIcon: Icons.open_in_new,
                trailingIconSize: 16,
                onTap: () =>
                    _openUrl('https://chefless-web.onrender.com/terms'),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                trailingIcon: Icons.open_in_new,
                trailingIconSize: 16,
                onTap: () =>
                    _openUrl('https://chefless-web.onrender.com/privacy'),
              ),
            ],
          ),

          // ── Danger Zone ─────────────────────────────────────
          const _SectionHeader(title: 'DANGER ZONE'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                iconColor: AppTheme.error,
                title: 'Delete Account',
                titleColor: AppTheme.error,
                showChevron: false,
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.logout,
                iconColor: AppTheme.error,
                title: 'Sign Out',
                titleColor: AppTheme.error,
                showChevron: false,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
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
                final apiService = await ref.read(apiServiceProvider.future);
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

// ── Kitchen Settings Section ─────────────────────────────────────────────────

class _KitchenSettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenAsync = ref.watch(myKitchenProvider);

    return kitchenAsync.when(
      data: (detail) {
        if (detail == null) {
          // Not in a kitchen — show create/join options.
          return _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.add,
                title: 'Create Kitchen',
                onTap: () => context.push('/kitchen/create'),
              ),
              const _TileDivider(),
              _SettingsTile(
                icon: Icons.group_add_outlined,
                title: 'Join Kitchen',
                onTap: () => context.push('/kitchen/join'),
              ),
            ],
          );
        }

        // Already in a kitchen — show kitchen name and link.
        return _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.kitchen_outlined,
              title: detail.kitchen.name,
              subtitle:
                  '${detail.kitchen.memberCount} member${detail.kitchen.memberCount == 1 ? '' : 's'}',
              onTap: () => context.push('/kitchen'),
            ),
          ],
        );
      },
      loading: () => _SettingsGroup(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing16,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.gray400,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Text(
                  'Loading kitchen...',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      error: (_, _) => _SettingsGroup(
        children: [
          _SettingsTile(
            icon: Icons.kitchen_outlined,
            title: 'Kitchen',
            onTap: () => context.push('/kitchen'),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacing20,
        right: AppTheme.spacing20,
        top: AppTheme.spacing32,
        bottom: AppTheme.spacing8,
      ),
      child: Text(
        title,
        style: context.textTheme.labelSmall?.copyWith(
          color: AppTheme.gray400,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Settings Group (iOS-style rounded card) ──────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(color: AppTheme.gray200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// ── Settings Tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.trailingIcon,
    this.trailingIconSize,
    this.showChevron = true,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final IconData? trailingIcon;
  final double? trailingIconSize;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.gray600).withValues(alpha: 0.08),
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? AppTheme.gray600,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? AppTheme.gray900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  trailingIcon ?? Icons.chevron_right_rounded,
                  size: trailingIconSize ?? 20,
                  color: AppTheme.gray300,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tile Divider ─────────────────────────────────────────────────────────────

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacing16 + 32 + AppTheme.spacing12),
      child: Container(
        height: 1,
        color: AppTheme.gray100,
      ),
    );
  }
}
