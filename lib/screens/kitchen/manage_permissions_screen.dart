import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/kitchen.dart';
import '../../models/user.dart';
import '../../providers/kitchen_provider.dart';
import '../../widgets/shimmer_loading.dart';
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
    _approvers = Set<String>.from(detail.kitchen.membersWithApprovalPower);
    _initialized = true;
  }

  Future<void> _handleSave(KitchenDetail detail) async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    final success =
        await ref.read(kitchenActionProvider.notifier).updatePermissions(
              membersWithScheduleEdit: _scheduleEditors.toList(),
              membersWithApprovalPower: _approvers.toList(),
            );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      HapticFeedback.mediumImpact();
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
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text(
          'Manage Permissions',
          style: AppTheme.displayTitleMedium(),
        ),
      ),
      body: kitchenAsync.when(
        data: (detail) {
          if (detail == null) {
            return const _EmptyView(
              title: 'No kitchen found',
              subtitle: 'Try refreshing or returning to the kitchen tab.',
              icon: Icons.kitchen_outlined,
            );
          }

          _initFromKitchen(detail);

          final nonLeadMembers = detail.members
              .where((m) => m.id != detail.kitchen.leadId)
              .toList();

          if (nonLeadMembers.isEmpty) {
            return const _EmptyView(
              title: 'No members yet',
              subtitle:
                  'Invite members to your kitchen to manage their permissions.',
              icon: Icons.people_alt_rounded,
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing12,
                  AppTheme.spacing16,
                  AppTheme.spacing4,
                ),
                child: _IntroNote(
                  count: nonLeadMembers.length,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    AppTheme.spacing16,
                    AppTheme.spacing16,
                    AppTheme.spacing24,
                  ),
                  itemCount: nonLeadMembers.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spacing12),
                  itemBuilder: (context, index) {
                    final member = nonLeadMembers[index];
                    return _PermissionCard(
                      member: member,
                      canEditSchedule: _scheduleEditors.contains(member.id),
                      canApprove: _approvers.contains(member.id),
                      onScheduleEditChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (value) {
                            _scheduleEditors.add(member.id);
                          } else {
                            _scheduleEditors.remove(member.id);
                          }
                        });
                      },
                      onApproveChanged: (value) {
                        HapticFeedback.selectionClick();
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
              _StickyFooter(
                isSaving: _isSaving,
                onSave: () => _handleSave(detail),
              ),
            ],
          );
        },
        loading: () => const _PermissionsLoadingView(),
        error: (error, _) => _EmptyView(
          title: 'Couldn’t load permissions',
          subtitle: error.toString().replaceFirst('Exception: ', ''),
          icon: Icons.error_outline_rounded,
          accent: AppTheme.error,
          accentBg: AppTheme.errorLight,
        ),
      ),
    );
  }
}

class _IntroNote extends StatelessWidget {
  const _IntroNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        color: AppTheme.accentPlayfulLight.withValues(alpha: 0.55),
        borderRadius: AppTheme.borderRadiusLarge,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.borderRadiusMedium,
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 16,
              color: AppTheme.accentPlayful,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count member${count == 1 ? '' : 's'} to configure',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryDeep,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Editors add to the schedule directly. Approvers can confirm '
                  'suggestions on your behalf.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.gray700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusLarge,
        boxShadow: AppTheme.shadowSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  fullName: member.fullName,
                  profilePictureUrl: member.profilePicture,
                  size: 44,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDeep,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _summary(canEditSchedule, canApprove),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing14),
            Container(
              height: 1,
              color: AppTheme.gray100,
            ),
            const SizedBox(height: AppTheme.spacing4),
            _PermissionToggle(
              icon: Icons.edit_calendar_rounded,
              iconColor: AppTheme.info,
              iconBg: AppTheme.info.withValues(alpha: 0.10),
              title: 'Can edit schedule',
              subtitle: 'Add, update, or remove meals from the schedule.',
              value: canEditSchedule,
              onChanged: onScheduleEditChanged,
            ),
            _PermissionToggle(
              icon: Icons.verified_rounded,
              iconColor: AppTheme.success,
              iconBg: AppTheme.success.withValues(alpha: 0.10),
              title: 'Can approve suggestions',
              subtitle: 'Approve or deny meal suggestions from other members.',
              value: canApprove,
              onChanged: onApproveChanged,
            ),
          ],
        ),
      ),
    );
  }

  String _summary(bool editor, bool approver) {
    if (editor && approver) return 'Editor · Approver';
    if (editor) return 'Editor';
    if (approver) return 'Approver';
    return 'Suggestions only';
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: AppTheme.borderRadiusMedium,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryDeep,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.gray500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.accentPlayful,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _StickyFooter extends StatelessWidget {
  const _StickyFooter({required this.isSaving, required this.onSave});

  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentPlayful,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.accentPlayful.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Save permissions'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionsLoadingView extends StatelessWidget {
  const _PermissionsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
      children: const [
        UserListShimmer(itemCount: 4),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = AppTheme.accentPlayful,
    this.accentBg = AppTheme.accentPlayfulLight,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color accentBg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBg,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: 38, color: accent),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              title,
              style: AppTheme.displayTitleMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.gray500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
