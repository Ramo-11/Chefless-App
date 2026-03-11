import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/kitchen.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/user_avatar.dart';
import '../paywall/paywall_bottom_sheet.dart';

/// Shows kitchen details, members, invite code, and management actions.
class KitchenDetailScreen extends ConsumerWidget {
  const KitchenDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenAsync = ref.watch(myKitchenProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Kitchen')),
      body: kitchenAsync.when(
        data: (detail) {
          if (detail == null) {
            return _NoKitchenView(onRefresh: () => ref.invalidate(myKitchenProvider));
          }
          final userId = currentUser.valueOrNull?.id;
          final isLead = userId == detail.kitchen.leadId;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myKitchenProvider),
            child: _KitchenContent(
              detail: detail,
              isLead: isLead,
              currentUserId: userId ?? '',
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(myKitchenProvider),
        ),
      ),
    );
  }
}

class _NoKitchenView extends StatelessWidget {
  const _NoKitchenView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.kitchen_outlined,
              size: 64,
              color: context.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No Kitchen Yet',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Create a kitchen or join one to start '
              'planning meals together.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),
            ElevatedButton.icon(
              onPressed: () => context.push('/kitchen/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Kitchen'),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            OutlinedButton.icon(
              onPressed: () => context.push('/kitchen/join'),
              icon: const Icon(Icons.group_add),
              label: const Text('Join Kitchen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
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
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitchenContent extends ConsumerWidget {
  const _KitchenContent({
    required this.detail,
    required this.isLead,
    required this.currentUserId,
  });

  final KitchenDetail detail;
  final bool isLead;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchen = detail.kitchen;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        // Kitchen header
        _KitchenHeader(kitchen: kitchen),
        const SizedBox(height: AppTheme.spacingLg),

        // Invite code
        _InviteCodeCard(inviteCode: kitchen.inviteCode),
        const SizedBox(height: AppTheme.spacingLg),

        // Kitchen recipes link
        Card(
          child: ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Kitchen Recipes'),
            subtitle: const Text('Browse recipes from all members'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/kitchen/recipes'),
          ),
        ),
        const SizedBox(height: AppTheme.spacingLg),

        // Members section
        _MembersSection(
          detail: detail,
          isLead: isLead,
          currentUserId: currentUserId,
        ),
        const SizedBox(height: AppTheme.spacingLg),

        // Lead actions
        if (isLead) ...[
          _LeadActionsSection(kitchen: kitchen, ref: ref),
          const SizedBox(height: AppTheme.spacingLg),
        ],

        // Leave / Delete
        _DangerSection(isLead: isLead),
        const SizedBox(height: AppTheme.spacingXl),
      ],
    );
  }
}

class _KitchenHeader extends StatelessWidget {
  const _KitchenHeader({required this.kitchen});

  final Kitchen kitchen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Kitchen photo
        CircleAvatar(
          radius: 48,
          backgroundColor: context.colorScheme.primaryContainer,
          backgroundImage: kitchen.photo != null
              ? CachedNetworkImageProvider(kitchen.photo!)
              : null,
          child: kitchen.photo == null
              ? Icon(
                  Icons.kitchen,
                  size: 40,
                  color: context.colorScheme.onPrimaryContainer,
                )
              : null,
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Text(
          kitchen.name,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          '${kitchen.memberCount} member${kitchen.memberCount == 1 ? '' : 's'}',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Text(
              'Invite Code',
              style: context.textTheme.labelLarge?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  inviteCode,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy invite code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite code copied to clipboard.'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Share this code with family or friends to invite them.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersSection extends ConsumerWidget {
  const _MembersSection({
    required this.detail,
    required this.isLead,
    required this.currentUserId,
  });

  final KitchenDetail detail;
  final bool isLead;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchen = detail.kitchen;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isPremium = currentUser?.isPremium ?? false;
    final atCapacity = !isPremium && kitchen.memberCount >= 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.spacingXs),
          child: Text(
            'Members',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        if (isLead && atCapacity)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Card(
              color: AppTheme.secondaryColor.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(
                  Icons.group,
                  color: AppTheme.secondaryColor,
                ),
                title: const Text('Kitchen at capacity'),
                subtitle: const Text(
                  'Upgrade to Premium for unlimited members.',
                ),
                trailing: TextButton(
                  onPressed: () {
                    PaywallBottomSheet.show(
                      context,
                      reason: PaywallReason.kitchenCapacityReached,
                    );
                  },
                  child: const Text('Upgrade'),
                ),
              ),
            ),
          ),
        ...detail.members.map((member) {
          final memberIsLead = member.id == kitchen.leadId;
          final canEditSchedule =
              kitchen.membersWithScheduleEdit.contains(member.id);
          final canApprove =
              kitchen.membersWithApprovalPower.contains(member.id);

          return _MemberTile(
            member: member,
            isLead: memberIsLead,
            canEditSchedule: canEditSchedule,
            canApprove: canApprove,
            showRemoveButton:
                isLead && member.id != currentUserId,
            onRemove: () => _confirmRemove(context, ref, member),
            onTransfer: isLead && member.id != currentUserId
                ? () => _confirmTransfer(context, ref, member)
                : null,
          );
        }),
      ],
    );
  }

  void _confirmRemove(
      BuildContext context, WidgetRef ref, CheflessUser member) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member.fullName} '
          'from the kitchen?',
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
              final success = await ref
                  .read(kitchenActionProvider.notifier)
                  .removeMember(member.id);
              if (context.mounted && !success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to remove member.')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmTransfer(
      BuildContext context, WidgetRef ref, CheflessUser member) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer Lead'),
        content: Text(
          'Transfer the Kitchen Lead role to ${member.fullName}? '
          'You will become a regular member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(kitchenActionProvider.notifier)
                  .transferLead(member.id);
              if (context.mounted && !success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to transfer lead role.'),
                  ),
                );
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isLead,
    required this.canEditSchedule,
    required this.canApprove,
    required this.showRemoveButton,
    required this.onRemove,
    this.onTransfer,
  });

  final CheflessUser member;
  final bool isLead;
  final bool canEditSchedule;
  final bool canApprove;
  final bool showRemoveButton;
  final VoidCallback onRemove;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    if (isLead) {
      badges.add(_RoleBadge(
        label: 'Lead',
        color: context.colorScheme.primary,
      ));
    }
    if (canEditSchedule) {
      badges.add(_RoleBadge(
        label: 'Editor',
        color: context.colorScheme.secondary,
      ));
    }
    if (canApprove) {
      badges.add(const _RoleBadge(
        label: 'Approver',
        color: AppTheme.secondaryColor,
      ));
    }

    return Card(
      child: ListTile(
        leading: UserAvatar(
          fullName: member.fullName,
          profilePictureUrl: member.profilePicture,
          size: 40,
        ),
        title: Text(member.fullName),
        subtitle: badges.isNotEmpty
            ? Wrap(
                spacing: 4,
                runSpacing: 4,
                children: badges,
              )
            : null,
        trailing: showRemoveButton
            ? PopupMenuButton<String>(
                itemBuilder: (ctx) => [
                  if (onTransfer != null)
                    const PopupMenuItem(
                      value: 'transfer',
                      child: Text('Transfer Lead'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'remove') {
                    onRemove();
                  } else if (value == 'transfer') {
                    onTransfer?.call();
                  }
                },
              )
            : null,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppTheme.borderRadiusSmall,
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LeadActionsSection extends StatelessWidget {
  const _LeadActionsSection({
    required this.kitchen,
    required this.ref,
  });

  final Kitchen kitchen;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.spacingXs),
          child: Text(
            'Kitchen Management',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Manage Permissions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/kitchen/permissions'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Regenerate Invite Code'),
                subtitle: const Text(
                  'The current code will stop working.',
                ),
                onTap: () => _confirmRegenerate(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmRegenerate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Code'),
        content: const Text(
          'The current invite code will be invalidated. '
          'Anyone who has the old code will no longer be able to join.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(kitchenActionProvider.notifier)
                  .regenerateInviteCode();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Invite code regenerated.'
                          : 'Failed to regenerate code.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }
}

class _DangerSection extends ConsumerWidget {
  const _DangerSection({required this.isLead});

  final bool isLead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.spacingXs),
          child: Text(
            'Danger Zone',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Card(
          child: Column(
            children: [
              if (!isLead)
                ListTile(
                  leading: Icon(
                    Icons.exit_to_app,
                    color: context.colorScheme.error,
                  ),
                  title: Text(
                    'Leave Kitchen',
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                  onTap: () => _confirmLeave(context, ref),
                ),
              if (isLead)
                ListTile(
                  leading: Icon(
                    Icons.delete_forever,
                    color: context.colorScheme.error,
                  ),
                  title: Text(
                    'Delete Kitchen',
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                  subtitle: const Text(
                    'This will remove all members and cannot be undone.',
                  ),
                  onTap: () => _confirmDelete(context, ref),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Kitchen'),
        content: const Text(
          'Are you sure you want to leave this kitchen?',
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
              final success =
                  await ref.read(kitchenActionProvider.notifier).leaveKitchen();
              if (context.mounted) {
                if (success) {
                  context.go('/settings');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to leave kitchen.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Kitchen'),
        content: const Text(
          'This action is permanent and cannot be undone. '
          'All members will be removed from the kitchen.',
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
              final success = await ref
                  .read(kitchenActionProvider.notifier)
                  .deleteKitchen();
              if (context.mounted) {
                if (success) {
                  context.go('/settings');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete kitchen.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
