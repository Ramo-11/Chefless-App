import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/kitchen.dart';
import '../../models/user.dart';
import '../../providers/kitchen_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/user_avatar.dart';

/// Allows the Kitchen Lead to manage schedule-edit and approval permissions
/// for each member.
class ManagePermissionsScreen extends ConsumerStatefulWidget {
  const ManagePermissionsScreen({super.key});

  @override
  ConsumerState<ManagePermissionsScreen> createState() =>
      _ManagePermissionsScreenState();
}

class _ManagePermissionsScreenState
    extends ConsumerState<ManagePermissionsScreen> {
  late Set<String> _scheduleEditors;
  late Set<String> _approvers;
  bool _initialized = false;
  bool _isSaving = false;

  void _initFromKitchen(KitchenDetail detail) {
    if (_initialized) return;
    _scheduleEditors =
        Set<String>.from(detail.kitchen.membersWithScheduleEdit);
    _approvers =
        Set<String>.from(detail.kitchen.membersWithApprovalPower);
    _initialized = true;
  }

  Future<void> _handleSave(KitchenDetail detail) async {
    setState(() => _isSaving = true);

    final success =
        await ref.read(kitchenActionProvider.notifier).updatePermissions(
              membersWithScheduleEdit: _scheduleEditors.toList(),
              membersWithApprovalPower: _approvers.toList(),
            );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions updated.')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update permissions.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchenAsync = ref.watch(myKitchenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Permissions')),
      body: kitchenAsync.when(
        data: (detail) {
          if (detail == null) {
            return Center(
              child: Text(
                'No kitchen found.',
                style: context.textTheme.bodyLarge,
              ),
            );
          }

          _initFromKitchen(detail);

          final nonLeadMembers = detail.members
              .where((m) => m.id != detail.kitchen.leadId)
              .toList();

          if (nonLeadMembers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      'No Members Yet',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      'Invite members to your kitchen to manage '
                      'their permissions.',
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  itemCount: nonLeadMembers.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spacingMd),
                  itemBuilder: (context, index) {
                    final member = nonLeadMembers[index];
                    return _PermissionCard(
                      member: member,
                      canEditSchedule:
                          _scheduleEditors.contains(member.id),
                      canApprove: _approvers.contains(member.id),
                      onScheduleEditChanged: (value) {
                        setState(() {
                          if (value) {
                            _scheduleEditors.add(member.id);
                          } else {
                            _scheduleEditors.remove(member.id);
                          }
                        });
                      },
                      onApproveChanged: (value) {
                        setState(() {
                          if (value) {
                            _approvers.add(member.id);
                          } else {
                            _approvers.remove(member.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

              // Save button
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isSaving ? null : () => _handleSave(detail),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save Permissions'),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: Text(
              error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.member,
    required this.canEditSchedule,
    required this.canApprove,
    required this.onScheduleEditChanged,
    required this.onApproveChanged,
  });

  final CheflessUser member;
  final bool canEditSchedule;
  final bool canApprove;
  final ValueChanged<bool> onScheduleEditChanged;
  final ValueChanged<bool> onApproveChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member info
            Row(
              children: [
                UserAvatar(
                  fullName: member.fullName,
                  profilePictureUrl: member.profilePicture,
                  size: 40,
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Text(
                    member.fullName,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Schedule edit toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Can edit schedule'),
              subtitle: const Text(
                'Add, update, or remove meals from the schedule.',
              ),
              value: canEditSchedule,
              onChanged: onScheduleEditChanged,
            ),

            // Approval power toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Can approve suggestions'),
              subtitle: const Text(
                'Approve or deny meal suggestions from other members.',
              ),
              value: canApprove,
              onChanged: onApproveChanged,
            ),
          ],
        ),
      ),
    );
  }
}
