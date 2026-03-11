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
      context.go('/kitchen');
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
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  Icons.group_add,
                  size: 64,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Join a Kitchen',
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'Enter the invite code shared by your Kitchen Lead.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXl),

                // Invite code field
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Invite Code',
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
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'Invite codes look like CHEF-XXXX. Ask your Kitchen Lead '
                  'to share theirs with you.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),

                // Join button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleJoin,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join Kitchen'),
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
