import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/kitchen_provider.dart';

/// Screen for creating a new Kitchen group.
class CreateKitchenScreen extends ConsumerStatefulWidget {
  const CreateKitchenScreen({super.key});

  @override
  ConsumerState<CreateKitchenScreen> createState() =>
      _CreateKitchenScreenState();
}

class _CreateKitchenScreenState extends ConsumerState<CreateKitchenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    final success =
        await ref.read(kitchenActionProvider.notifier).createKitchen(
              name: _nameController.text.trim(),
            );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kitchen created!')),
      );
      context.pushReplacement('/kitchen');
    } else {
      final error = ref.read(kitchenActionProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.error?.toString().replaceFirst('Exception: ', '') ??
                'Failed to create kitchen.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text('Create Kitchen', style: AppTheme.displayTitleMedium()),
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
                const Center(child: _HeaderArt(icon: Icons.kitchen_rounded)),
                const SizedBox(height: AppTheme.spacing24),
                Text(
                  'Start your kitchen',
                  style: AppTheme.displayTitleMedium().copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing8),
                const Text(
                  'A shared space for your family or friends to plan meals, '
                  'share recipes, and shop together.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing32),
                const Text(
                  'Kitchen name',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., The Smith Family',
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleCreate(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a kitchen name.';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters.';
                    }
                    if (value.trim().length > 50) {
                      return 'Name must be 50 characters or less.';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _handleCreate,
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
                        : const Text('Create kitchen'),
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
