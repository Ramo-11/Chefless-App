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
        return Icons.menu_book_rounded;
      case PaywallReason.scheduleLimitReached:
        return Icons.calendar_month_rounded;
      case PaywallReason.kitchenCapacityReached:
        return Icons.group_rounded;
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
          top: Radius.circular(AppTheme.radiusXL),
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
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing24,
          AppTheme.spacing8,
          AppTheme.spacing24,
          AppTheme.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 30,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),

            // Title
            Text(
              _title,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppTheme.gray900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),

            // Description
            Text(
              _description,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing24),

            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/paywall');
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Upgrade to Premium'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),

            // Dismiss
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Not now',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray400,
                    fontWeight: FontWeight.w500,
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
