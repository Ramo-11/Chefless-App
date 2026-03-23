import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/onboarding_illustration.dart';

/// Available dietary preference options.
const List<String> _dietaryOptions = [
  'Halal',
  'Vegan',
  'Vegetarian',
  'Gluten-Free',
  'Dairy-Free',
  'Nut-Free',
  'None',
];

/// Onboarding step: select dietary preferences.
class DietaryPreferencesScreen extends ConsumerStatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  ConsumerState<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState
    extends ConsumerState<DietaryPreferencesScreen> {
  final Set<String> _selected = {};
  bool _isSaving = false;

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);

    try {
      final apiService = await ref.read(apiServiceProvider.future);

      // If "None" is selected, send an empty list.
      final preferences =
          _selected.contains('None') ? <String>[] : _selected.toList();

      final result = await apiService.patch(
        '/users/me',
        data: {'dietaryPreferences': preferences},
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

      if (mounted) context.go('/onboarding/cuisine');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
      setState(() => _isSaving = false);
    }
  }

  void _skip() {
    context.go('/onboarding/cuisine');
  }

  void _toggleOption(String option) {
    if (!mounted) return;
    setState(() {
      if (option == 'None') {
        // Selecting "None" clears all others.
        _selected.clear();
        _selected.add('None');
      } else {
        _selected.remove('None');
        if (_selected.contains(option)) {
          _selected.remove(option);
        } else {
          _selected.add(option);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dietary Preferences'),
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
                  centerIcon: Icons.set_meal_rounded,
                  centerColor: AppTheme.primaryColor,
                  centerIconSize: 40,
                  centerCircleSize: 80,
                  backdropColors: [
                    AppTheme.primaryColor,
                    Color(0xFF43A047),
                  ],
                  satellites: [
                    Satellite(
                      icon: Icons.eco_rounded,
                      color: Color(0xFF43A047),
                      angle: -pi / 3,
                      distance: 72,
                      bobPhase: 0,
                      containerSize: 36,
                      iconSize: 18,
                      bobAmplitude: 6,
                    ),
                    Satellite(
                      icon: Icons.grain_rounded,
                      color: AppTheme.secondaryColor,
                      angle: pi / 4,
                      distance: 75,
                      bobPhase: 0.35,
                      containerSize: 34,
                      iconSize: 18,
                      bobAmplitude: 5,
                    ),
                    Satellite(
                      icon: Icons.water_drop_rounded,
                      color: Color(0xFF42A5F5),
                      angle: 3 * pi / 4,
                      distance: 70,
                      bobPhase: 0.7,
                      containerSize: 34,
                      iconSize: 18,
                      bobAmplitude: 7,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingSm),

              Text(
                'Any dietary needs?',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'This helps us suggest recipes you\'ll love.',
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
                    children: _dietaryOptions.map((option) {
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
