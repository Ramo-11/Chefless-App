import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/extensions.dart';

/// First onboarding screen with branding and a call-to-action.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo / icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
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

              // Get Started button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/onboarding/profile'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingMd,
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Already have an account
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  'Already have an account? Log in',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.primary,
                  ),
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
