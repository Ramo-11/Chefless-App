import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/onboarding_illustration.dart';

/// Landing screen for unauthenticated users. Directs to signup or login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
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
                  AppTheme.accentPlayful,
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
                    color: AppTheme.accentPlayful,
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

              const SizedBox(height: AppTheme.spacing32),

              // Editorial brand wordmark
              Text(
                'Chefless',
                style: GoogleFonts.fraunces(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: -1.2,
                  color: AppTheme.textPrimaryDeep,
                ),
              ),

              const SizedBox(height: AppTheme.spacing12),

              Text(
                'Your kitchen, your recipes, your way.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.gray600,
                  letterSpacing: -0.1,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Primary CTA
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.go('/signup');
                  },
                  style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMedium,
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ),

              const SizedBox(height: AppTheme.spacing12),

              // Secondary CTA
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.go('/login');
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusMedium,
                    ),
                    side: const BorderSide(color: AppTheme.gray200),
                    foregroundColor: AppTheme.gray800,
                    textStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  child: const Text('I already have an account'),
                ),
              ),

              const SizedBox(height: AppTheme.spacing40),
            ],
          ),
        ),
      ),
    );
  }
}
