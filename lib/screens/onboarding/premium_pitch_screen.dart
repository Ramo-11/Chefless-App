import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/extensions.dart';
import '../../widgets/onboarding_illustration.dart';

// Same accent colors used in paywall_screen.dart for visual consistency.
const _premiumAccent = Color(0xFFD4920B);
const _premiumAccentLight = Color(0xFFF5C842);

/// Onboarding step: non-aggressive premium pitch with feature comparison.
class PremiumPitchScreen extends StatelessWidget {
  const PremiumPitchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding/cuisine'),
          tooltip: 'Back',
        ),
        title: const Text('Chefless Premium'),
        actions: [
          TextButton(
            onPressed: () => context.go('/onboarding/tour'),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing32,
            vertical: AppTheme.spacing24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Illustration
              const Center(
                child: OnboardingIllustration(
                  size: 190,
                  centerIcon: Icons.workspace_premium_rounded,
                  centerColor: _premiumAccent,
                  centerIconSize: 42,
                  centerCircleSize: 78,
                  backdropColors: [
                    _premiumAccent,
                    _premiumAccentLight,
                  ],
                  satellites: [
                    Satellite(
                      icon: Icons.star_rounded,
                      color: _premiumAccent,
                      angle: -pi / 3,
                      distance: 68,
                      bobPhase: 0,
                      containerSize: 34,
                      iconSize: 18,
                      bobAmplitude: 5,
                    ),
                    Satellite(
                      icon: Icons.diamond_outlined,
                      color: _premiumAccentLight,
                      angle: pi / 4,
                      distance: 66,
                      bobPhase: 0.35,
                      containerSize: 32,
                      iconSize: 16,
                      bobAmplitude: 6,
                    ),
                    Satellite(
                      icon: Icons.bolt_rounded,
                      color: _premiumAccent,
                      angle: 3 * pi / 4,
                      distance: 64,
                      bobPhase: 0.7,
                      containerSize: 32,
                      iconSize: 16,
                      bobAmplitude: 5,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacing16),

              Text(
                'Get more out of Chefless',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppTheme.gray900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'You can always upgrade later.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spacing32),

              // Feature comparison card
              const _ComparisonCard(),

              const SizedBox(height: AppTheme.spacing40),

              // Go Premium button
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    await context.push('/paywall');
                    if (context.mounted) {
                      context.go('/onboarding/tour');
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _premiumAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMedium,
                    ),
                  ),
                  child: const Text('Go Premium'),
                ),
              ),

              const SizedBox(height: AppTheme.spacing12),

              // Start free button
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.go('/onboarding/tour'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.gray200),
                    foregroundColor: AppTheme.gray800,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMedium,
                    ),
                  ),
                  child: const Text('Start Free'),
                ),
              ),

              const SizedBox(height: AppTheme.spacing32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.gray200),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              Expanded(
                flex: 2,
                child: Text(
                  'Free',
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: AppTheme.gray400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Premium',
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: _premiumAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
            child: Divider(color: AppTheme.gray100, height: 1),
          ),
          const _Row(label: 'Recipes', free: '10', premium: 'Unlimited'),
          const _Row(
            label: 'Schedule',
            free: '2 weeks',
            premium: 'Full year',
          ),
          const _Row(
            label: 'Kitchen Members',
            free: '4',
            premium: 'Unlimited',
          ),
          const _Row(label: 'AI Helper', free: '--', premium: 'Yes'),
          const _Row(label: 'Chef Hat Badge', free: '--', premium: 'Yes'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.free,
    required this.premium,
  });

  final String label;
  final String free;
  final String premium;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.gray700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray400,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: _premiumAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
