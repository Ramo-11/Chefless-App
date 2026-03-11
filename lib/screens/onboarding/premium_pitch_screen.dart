import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/extensions.dart';

/// Onboarding step: non-aggressive premium pitch with feature comparison.
class PremiumPitchScreen extends StatelessWidget {
  const PremiumPitchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(top: AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.workspace_premium,
                  size: 44,
                  color: AppTheme.secondaryColor,
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              Text(
                'Get more out of Chefless',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'You can always upgrade later.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // Feature comparison card
              const _ComparisonCard(),

              const SizedBox(height: AppTheme.spacingXl),

              // Go Premium button
              FilledButton(
                onPressed: () async {
                  await context.push('/paywall');
                  if (context.mounted) {
                    context.go('/onboarding/tour');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingMd,
                  ),
                ),
                child: const Text('Go Premium'),
              ),

              const SizedBox(height: AppTheme.spacingSm),

              // Start free button
              OutlinedButton(
                onPressed: () => context.go('/onboarding/tour'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingMd,
                  ),
                ),
                child: const Text('Start Free'),
              ),

              const SizedBox(height: AppTheme.spacingLg),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
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
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Premium',
                    textAlign: TextAlign.center,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: AppTheme.spacingMd),
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
