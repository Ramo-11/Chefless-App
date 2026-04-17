import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/onboarding_illustration.dart';
import '../../widgets/onboarding_progress_bar.dart';

// Same accent colors used in paywall_screen.dart for visual consistency.
const _premiumAccent = Color(0xFFD4920B);
const _premiumAccentLight = Color(0xFFF5C842);

/// Onboarding step: non-aggressive premium pitch with feature comparison.
class PremiumPitchScreen extends StatelessWidget {
  const PremiumPitchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/onboarding/cuisine'),
          tooltip: 'Back',
        ),
        title: const Text('Chefless Premium'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              context.go('/onboarding/tour');
            },
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(current: 4, accent: _premiumAccent),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: OnboardingIllustration(
                        size: 200,
                        centerIcon: Icons.workspace_premium_rounded,
                        centerColor: _premiumAccent,
                        centerIconSize: 44,
                        centerCircleSize: 82,
                        backdropColors: [
                          _premiumAccent,
                          _premiumAccentLight,
                        ],
                        satellites: [
                          Satellite(
                            icon: Icons.star_rounded,
                            color: _premiumAccent,
                            angle: -pi / 3,
                            distance: 72,
                            bobPhase: 0,
                            containerSize: 34,
                            iconSize: 18,
                            bobAmplitude: 5,
                          ),
                          Satellite(
                            icon: Icons.diamond_outlined,
                            color: _premiumAccentLight,
                            angle: pi / 4,
                            distance: 70,
                            bobPhase: 0.35,
                            containerSize: 32,
                            iconSize: 16,
                            bobAmplitude: 6,
                          ),
                          Satellite(
                            icon: Icons.bolt_rounded,
                            color: _premiumAccent,
                            angle: 3 * pi / 4,
                            distance: 68,
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
                      style: AppTheme.displayTitleMedium(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing10),
                    const Text(
                      'Unlock unlimited recipes, planning, and smart tools. You can always upgrade later.',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: AppTheme.gray600,
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    const _ComparisonCard(),
                    const SizedBox(height: AppTheme.spacing16),
                    const _TrustRow(),
                    const SizedBox(height: AppTheme.spacing32),
                  ],
                ),
              ),
            ),
            // Sticky CTA stack
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing32,
                0,
                AppTheme.spacing32,
                AppTheme.spacing24,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.borderRadiusMedium,
                        boxShadow: [
                          BoxShadow(
                            color: _premiumAccent.withValues(alpha: 0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          await context.push('/paywall');
                          if (context.mounted) {
                            context.go('/onboarding/tour');
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _premiumAccent,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusMedium,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.workspace_premium_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Go Premium'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.go('/onboarding/tour');
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceElevated,
                        side: const BorderSide(color: AppTheme.gray200),
                        foregroundColor: AppTheme.gray800,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMedium,
                        ),
                      ),
                      child: const Text('Start Free'),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowCard,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        AppTheme.spacing16,
        AppTheme.spacing20,
        AppTheme.spacing8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              const Expanded(
                flex: 2,
                child: Text(
                  'Free',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppTheme.gray500,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _premiumAccent.withValues(alpha: 0.12),
                    borderRadius: AppTheme.borderRadiusFull,
                  ),
                  child: const Text(
                    'Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: _premiumAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing12),
            child: Divider(color: AppTheme.gray100, height: 1),
          ),
          const _Row(label: 'Recipes', free: '10', premium: 'Unlimited'),
          const _Row(label: 'Schedule', free: '2 weeks', premium: 'Full year'),
          const _Row(
            label: 'Kitchen Members',
            free: '4',
            premium: 'Unlimited',
          ),
          const _Row(label: 'AI Helper', free: null, premium: 'Included'),
          const _Row(label: 'Chef Hat Badge', free: null, premium: 'Yours'),
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
  final String? free;
  final String premium;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray800,
                letterSpacing: -0.1,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: free == null
                ? const Center(
                    child: Icon(
                      Icons.remove_rounded,
                      size: 18,
                      color: AppTheme.gray300,
                    ),
                  )
                : Text(
                    free!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray500,
                    ),
                  ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: _premiumAccent,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    premium,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _premiumAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.lock_outline_rounded, 'Cancel anytime'),
      (Icons.play_circle_outline_rounded, 'Free trial'),
      (Icons.verified_user_outlined, 'No ads'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (icon, label) in items)
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.gray500),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.gray500,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
