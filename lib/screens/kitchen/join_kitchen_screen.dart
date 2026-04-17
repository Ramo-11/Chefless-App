import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/kitchen_provider.dart';

/// Screen for joining an existing Kitchen via invite code.
class JoinKitchenScreen extends ConsumerStatefulWidget {
  const JoinKitchenScreen({super.key});

  @override
  ConsumerState<JoinKitchenScreen> createState() => _JoinKitchenScreenState();
}

class _JoinKitchenScreenState extends ConsumerState<JoinKitchenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    final success = await ref
        .read(kitchenActionProvider.notifier)
        .joinKitchen(_codeController.text.trim());

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined kitchen!')),
      );
      context.pushReplacement('/kitchen');
    } else {
      final error = ref.read(kitchenActionProvider);
      final errorMessage =
          error.error?.toString().replaceFirst('Exception: ', '') ??
              'Failed to join kitchen.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text('Join Kitchen', style: AppTheme.displayTitleMedium()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spacing20),
                const Center(child: _HeaderArt(icon: Icons.group_add_rounded)),
                const SizedBox(height: AppTheme.spacing24),
                Text(
                  'Join a kitchen',
                  style: AppTheme.displayTitleMedium().copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing8),
                const Text(
                  'Enter the invite code shared by your Kitchen Lead.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing32),
                const Text(
                  'Invite code',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: 'CHEF-AB12CD',
                    prefixIcon: Icon(
                      Icons.key_rounded,
                      color: AppTheme.accentPlayful.withValues(alpha: 0.7),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                  onFieldSubmitted: (_) => _handleJoin(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an invite code.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing12),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPlayfulLight.withValues(alpha: 0.55),
                    borderRadius: AppTheme.borderRadiusLarge,
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_rounded,
                        size: 16,
                        color: AppTheme.accentPlayful,
                      ),
                      SizedBox(width: AppTheme.spacing10),
                      Expanded(
                        child: Text(
                          'Invite codes start with CHEF- followed by letters '
                          'and numbers. Ask your Kitchen Lead to share theirs.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.gray700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _handleJoin,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentPlayful,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.accentPlayful.withValues(alpha: 0.4),
                      disabledForegroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Join kitchen'),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderArt extends StatelessWidget {
  const _HeaderArt({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accentPlayfulLight,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPlayful.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: AppTheme.accentPlayfulLight,
        ),
        child: Icon(icon, size: 42, color: AppTheme.accentPlayful),
      ),
    );
  }
}
