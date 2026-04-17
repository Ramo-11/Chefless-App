import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_selectable_chip.dart';
import '../../widgets/onboarding_illustration.dart';
import '../../widgets/onboarding_progress_bar.dart';

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
    HapticFeedback.lightImpact();
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
    HapticFeedback.selectionClick();
    context.go('/onboarding/cuisine');
  }

  void _toggleOption(String option) {
    if (!mounted) return;
    setState(() {
      if (option == 'None') {
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
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/onboarding/profile'),
          tooltip: 'Back',
        ),
        title: const Text('Dietary Preferences'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _skip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OnboardingProgressBar(current: 2),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing32,
              ),
              child: Column(
                children: [
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
                          color: AppTheme.accentPlayful,
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
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    'Any dietary needs?',
                    style: AppTheme.displayTitleMedium(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing10),
                  const Text(
                    'We\'ll tailor recipe suggestions to fit how you eat.',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppTheme.gray600,
                      letterSpacing: -0.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing32,
                ),
                child: Wrap(
                  spacing: AppTheme.spacing10,
                  runSpacing: AppTheme.spacing10,
                  children: _dietaryOptions.map((option) {
                    return AnimatedSelectableChip(
                      label: option,
                      selected: _selected.contains(option),
                      onTap: () => _toggleOption(option),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing32,
              ),
              child: SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveAndContinue,
                  style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMedium,
                    ),
                  ),
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
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
          ],
        ),
      ),
    );
  }
}
