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
                style: context.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.gray500,
                ),
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
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing24),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_outline,
                        size: 40,
                        color: AppTheme.gray400,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    Text(
                      'No Members Yet',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Text(
                      'Invite members to your kitchen to manage '
                      'their permissions.',
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gray500,
                        height: 1.5,
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
                      const SizedBox(height: AppTheme.spacing12),
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
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.gray100,
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
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
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 32,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray600,
                  ),
                ),
              ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(color: AppTheme.gray200),
      ),
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
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    member.fullName,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            Divider(height: 1, color: AppTheme.gray100),
            const SizedBox(height: AppTheme.spacing4),

            // Schedule edit toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Can edit schedule',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.gray900,
                ),
              ),
              subtitle: Text(
                'Add, update, or remove meals from the schedule.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppTheme.gray500,
                ),
              ),
              value: canEditSchedule,
              onChanged: onScheduleEditChanged,
            ),

            // Approval power toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Can approve suggestions',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.gray900,
                ),
              ),
              subtitle: Text(
                'Approve or deny meal suggestions from other members.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppTheme.gray500,
                ),
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
