import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/kitchen_provider.dart';
import '../../utils/extensions.dart';

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

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(kitchenActionProvider.notifier)
        .joinKitchen(_codeController.text.trim());

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
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
      appBar: AppBar(title: const Text('Join Kitchen')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spacing20),

                // Header
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.group_add,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                Text(
                  'Join a Kitchen',
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'Enter the invite code shared by your Kitchen Lead.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing40),

                // Invite code field
                Text(
                  'Invite Code',
                  style: context.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray700,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    hintText: 'CHEF-XXXX',
                    prefixIcon: Icon(Icons.key),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
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
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.gray50,
                    borderRadius: AppTheme.borderRadiusSmall,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.gray400,
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: Text(
                          'Invite codes look like CHEF-XXXX. Ask your Kitchen Lead '
                          'to share theirs with you.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppTheme.gray500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Join button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleJoin,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Join Kitchen'),
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
