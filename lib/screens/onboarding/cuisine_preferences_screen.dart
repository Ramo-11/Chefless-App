import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';

/// Available cuisine preference options.
const List<String> _cuisineOptions = [
  'Middle Eastern',
  'Italian',
  'Mexican',
  'Asian',
  'American',
  'Indian',
  'Mediterranean',
  'French',
  'Japanese',
  'Thai',
  'Korean',
  'Greek',
];

/// Onboarding step: select cuisine preferences.
class CuisinePreferencesScreen extends ConsumerStatefulWidget {
  const CuisinePreferencesScreen({super.key});

  @override
  ConsumerState<CuisinePreferencesScreen> createState() =>
      _CuisinePreferencesScreenState();
}

class _CuisinePreferencesScreenState
    extends ConsumerState<CuisinePreferencesScreen> {
  final Set<String> _selected = {};
  bool _isSaving = false;

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.put(
        '/users/me',
        data: {'cuisinePreferences': _selected.toList()},
      );

      if (!mounted) return;

      if (result.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to save preferences.'),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      ref.invalidate(currentUserProvider);
      context.go('/onboarding/premium');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
      setState(() => _isSaving = false);
    }
  }

  void _skip() {
    context.go('/onboarding/premium');
  }

  void _toggleOption(String option) {
    if (!mounted) return;
    setState(() {
      if (_selected.contains(option)) {
        _selected.remove(option);
      } else {
        _selected.add(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuisine Preferences'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _skip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spacingSm),

              Text(
                'What cuisines do you enjoy?',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Select as many as you like. We\'ll personalize your experience.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spacingXl),

              // Chips
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: AppTheme.spacingSm,
                    runSpacing: AppTheme.spacingSm,
                    children: _cuisineOptions.map((option) {
                      final isSelected = _selected.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isSelected,
                        showCheckmark: true,
                        onSelected: (_) => _toggleOption(option),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Continue button
              FilledButton(
                onPressed: _isSaving ? null : _saveAndContinue,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
