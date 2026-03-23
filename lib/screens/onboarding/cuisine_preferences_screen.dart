import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/onboarding_illustration.dart';

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
      final result = await apiService.patch(
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

      if (mounted) context.go('/onboarding/premium');
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
              // Illustration
              const Center(
                child: OnboardingIllustration(
                  size: 200,
                  centerIcon: Icons.public_rounded,
                  centerColor: AppTheme.primaryColor,
                  centerIconSize: 42,
                  centerCircleSize: 80,
                  backdropColors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                  ],
                  satellites: [
                    Satellite(
                      icon: Icons.ramen_dining_rounded,
                      color: AppTheme.tertiaryColor,
                      angle: -pi / 4,
                      distance: 74,
                      bobPhase: 0,
                      containerSize: 36,
                      iconSize: 18,
                      bobAmplitude: 6,
                    ),
                    Satellite(
                      icon: Icons.local_pizza_rounded,
                      color: AppTheme.secondaryColor,
                      angle: pi / 2 + pi / 6,
                      distance: 72,
                      bobPhase: 0.3,
                      containerSize: 36,
                      iconSize: 18,
                      bobAmplitude: 5,
                    ),
                    Satellite(
                      icon: Icons.rice_bowl_rounded,
                      color: Color(0xFF8D6E63),
                      angle: pi + pi / 5,
                      distance: 70,
                      bobPhase: 0.6,
                      containerSize: 34,
                      iconSize: 18,
                      bobAmplitude: 7,
                    ),
                  ],
                ),
              ),

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

              const SizedBox(height: AppTheme.spacingLg),

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
