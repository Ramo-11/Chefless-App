import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/constants.dart';
import '../../utils/extensions.dart';

// Warm accent color for the paywall — premium gold/amber tone.
const _accentColor = Color(0xFFD4920B);
const _accentLight = Color(0xFFF5C842);

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = false;
  bool _isRestoring = false;

  Future<void> _purchase(Package package) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(subscriptionServiceProvider);
      final success = await service.purchasePackage(package);
      if (mounted && success) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    try {
      final service = ref.read(subscriptionServiceProvider);
      final restored = await service.restorePurchases();
      if (mounted) {
        if (restored) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Premium restored successfully.')),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No previous purchases found.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!RevenueCatConstants.isConfigured) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 64,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Subscriptions coming soon',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'Premium features are not available yet. Stay tuned!',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final offeringsAsync = ref.watch(offeringsProvider);

    return Scaffold(
      body: SafeArea(
        child: offeringsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: context.colorScheme.error,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'Unable to load subscription options.',
                    style: context.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(offeringsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (offerings) {
            final currentOffering = offerings.current;
            final monthly = currentOffering?.monthly;
            final annual = currentOffering?.annual;

            return Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLg,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: AppTheme.spacingSm),

                        // App logo
                        Image.asset(
                          'assets/images/logo.png',
                          width: 80,
                          height: 80,
                        ),
                        const SizedBox(height: AppTheme.spacingLg),

                        // Title
                        Text(
                          'Upgrade to\nChefless Pro',
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        Text(
                          'Take your cooking to the next level',
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: AppTheme.spacingXl),

                        // Feature list
                        const _FeatureList(),

                        const SizedBox(height: AppTheme.spacingXl),

                        // Plan selection
                        if (annual != null)
                          _PlanCard(
                            title: 'Annual',
                            price: annual.storeProduct.priceString,
                            period: '/year',
                            badge: 'Best Value',
                            subtitle: 'Save 50% compared to monthly',
                            isSelected: true,
                            isLoading: _isLoading,
                            onTap: () => _purchase(annual),
                          ),
                        if (annual != null && monthly != null)
                          const SizedBox(height: AppTheme.spacingSm),
                        if (monthly != null)
                          _PlanCard(
                            title: 'Monthly',
                            price: monthly.storeProduct.priceString,
                            period: '/month',
                            isSelected: annual == null,
                            isLoading: _isLoading,
                            onTap: () => _purchase(monthly),
                          ),

                        if (monthly == null && annual == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingLg,
                            ),
                            child: Text(
                              'Subscription options are not available right now. '
                              'Please try again later.',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: AppTheme.spacingMd),

                        // Restore
                        TextButton(
                          onPressed: _isRestoring ? null : _restore,
                          child: _isRestoring
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Restore Purchases',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Feature List ──────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _features = [
    _Feature(icon: Icons.all_inclusive, text: 'Unlimited recipe storage'),
    _Feature(icon: Icons.calendar_month_rounded, text: 'Schedule meals for the full year'),
    _Feature(icon: Icons.group_rounded, text: 'Unlimited kitchen members'),
    _Feature(icon: Icons.auto_awesome_rounded, text: 'AI-powered recipe helper'),
    _Feature(icon: Icons.verified_rounded, text: 'Chef hat badge on your profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: f,
              ))
          .toList(),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.1),
            borderRadius: AppTheme.borderRadiusSmall,
          ),
          child: Icon(
            icon,
            size: 20,
            color: _accentColor,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    this.subtitle,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  final String title;
  final String price;
  final String period;
  final String? badge;
  final String? subtitle;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(
            color: isSelected
                ? _accentColor
                : context.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? _accentColor.withValues(alpha: isDark ? 0.08 : 0.04)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? _accentColor
                      : context.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppTheme.spacingMd),

            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: AppTheme.spacingSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_accentColor, _accentLight],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Color(0xFF3E2800),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Price
            isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        period,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
