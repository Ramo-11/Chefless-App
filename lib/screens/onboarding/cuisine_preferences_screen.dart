import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/cuisine_selector.dart';
import '../../widgets/onboarding_illustration.dart';
import '../../widgets/onboarding_progress_bar.dart';

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
    HapticFeedback.lightImpact();
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
    HapticFeedback.selectionClick();
    context.go('/onboarding/premium');
  }

  void _onCuisineChanged(Set<String> updated) {
    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(updated);
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
          onPressed: () => context.go('/onboarding/dietary'),
          tooltip: 'Back',
        ),
        title: const Text('Cuisine Preferences'),
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
            const OnboardingProgressBar(current: 3),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing32,
              ),
              child: Column(
                children: [
                  const Center(
                    child: OnboardingIllustration(
                      size: 200,
                      centerIcon: Icons.public_rounded,
                      centerColor: AppTheme.primaryColor,
                      centerIconSize: 42,
                      centerCircleSize: 80,
                      backdropColors: [
                        AppTheme.primaryColor,
                        AppTheme.accentPlayful,
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
                          color: AppTheme.accentPlayful,
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
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    'What cuisines do you enjoy?',
                    style: AppTheme.displayTitleMedium(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing10),
                  const Text(
                    'Pick as many as you like — we\'ll personalize your feed.',
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
                child: CuisineSelector(
                  selected: _selected,
                  onChanged: _onCuisineChanged,
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
