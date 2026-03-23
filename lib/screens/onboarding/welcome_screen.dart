import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/extensions.dart';
import '../../widgets/onboarding_illustration.dart';

/// Landing screen for unauthenticated users. Directs to signup or login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animated illustration
              const OnboardingIllustration(
                size: 300,
                centerIcon: Icons.restaurant_menu,
                centerColor: AppTheme.primaryColor,
                centerImageAsset: 'assets/images/logo.png',
                centerIconSize: 56,
                centerCircleSize: 110,
                backdropColors: [
                  AppTheme.primaryColor,
                  AppTheme.secondaryColor,
                  AppTheme.tertiaryColor,
                ],
                satellites: [
                  Satellite(
                    icon: Icons.local_fire_department_rounded,
                    color: Color(0xFFEF6C00),
                    angle: -pi / 3,
                    distance: 108,
                    bobPhase: 0,
                    containerSize: 46,
                    iconSize: 24,
                  ),
                  Satellite(
                    icon: Icons.eco_rounded,
                    color: Color(0xFF43A047),
                    angle: pi / 12,
                    distance: 112,
                    bobPhase: 0.2,
                    containerSize: 42,
                    iconSize: 22,
                  ),
                  Satellite(
                    icon: Icons.favorite_rounded,
                    color: Color(0xFFE91E63),
                    angle: 2 * pi / 3,
                    distance: 105,
                    bobPhase: 0.45,
                    containerSize: 40,
                    iconSize: 20,
                  ),
                  Satellite(
                    icon: Icons.auto_awesome,
                    color: AppTheme.secondaryColor,
                    angle: pi + pi / 6,
                    distance: 110,
                    bobPhase: 0.65,
                    containerSize: 44,
                    iconSize: 22,
                  ),
                  Satellite(
                    icon: Icons.egg_alt_rounded,
                    color: Color(0xFF8D6E63),
                    angle: -pi + pi / 4,
                    distance: 100,
                    bobPhase: 0.85,
                    containerSize: 38,
                    iconSize: 20,
                    bobAmplitude: 6,
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // App name
              Text(
                'Chefless',
                style: context.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Tagline
              Text(
                'Your kitchen, your recipes, your way.',
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Get Started → Signup
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/signup'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingMd,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ),

              const SizedBox(height: AppTheme.spacingSm),

              // Log in
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingMd,
                    ),
                    side: BorderSide(
                      color: isDark
                          ? context.colorScheme.outlineVariant
                          : context.colorScheme.outline,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('I already have an account'),
                ),
              ),

              const SizedBox(height: AppTheme.spacingXl),
            ],
          ),
        ),
      ),
    );
  }
}
