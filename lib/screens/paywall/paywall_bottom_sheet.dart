import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/extensions.dart';

/// The reason a paywall bottom sheet is being shown.
enum PaywallReason {
  recipeLimitReached,
  scheduleLimitReached,
  kitchenCapacityReached,
}

/// A non-aggressive bottom sheet shown when a user hits a free tier limit.
///
/// Displays the specific limit that was reached and offers an upgrade button
/// that navigates to the full paywall.
class PaywallBottomSheet extends StatelessWidget {
  const PaywallBottomSheet({
    super.key,
    required this.reason,
  });

  final PaywallReason reason;

  String get _title {
    switch (reason) {
      case PaywallReason.recipeLimitReached:
        return 'Recipe Limit Reached';
      case PaywallReason.scheduleLimitReached:
        return 'Schedule Limit Reached';
      case PaywallReason.kitchenCapacityReached:
        return 'Kitchen Full';
    }
  }

  String get _description {
    switch (reason) {
      case PaywallReason.recipeLimitReached:
        return 'Free accounts are limited to 10 recipes. '
            'Upgrade to Premium for unlimited recipes and more.';
      case PaywallReason.scheduleLimitReached:
        return 'Free accounts can only schedule up to 2 weeks ahead. '
            'Upgrade to Premium to plan your full year.';
      case PaywallReason.kitchenCapacityReached:
        return 'Free kitchens are limited to 4 members. '
            'Upgrade to Premium for unlimited kitchen members.';
    }
  }

  IconData get _icon {
    switch (reason) {
      case PaywallReason.recipeLimitReached:
        return Icons.menu_book;
      case PaywallReason.scheduleLimitReached:
        return Icons.calendar_month;
      case PaywallReason.kitchenCapacityReached:
        return Icons.group;
    }
  }

  /// Shows the paywall bottom sheet and returns `true` if the user navigated
  /// to the full paywall and completed a purchase.
  static Future<bool> show(
    BuildContext context, {
    required PaywallReason reason,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (_) => PaywallBottomSheet(reason: reason),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 32,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Title
            Text(
              _title,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingSm),

            // Description
            Text(
              _description,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/paywall');
                },
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Upgrade to Premium'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingMd,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),

            // Dismiss
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not now',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
