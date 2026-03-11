import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/extensions.dart';

/// Full-screen paywall showing free vs. premium feature comparison and
/// purchase options.
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
    final offeringsAsync = ref.watch(offeringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Premium'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ),
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero section
                  const _HeroSection(),
                  const SizedBox(height: AppTheme.spacingLg),

                  // Feature comparison
                  const _FeatureComparisonTable(),
                  const SizedBox(height: AppTheme.spacingLg),

                  // Purchase buttons
                  if (annual != null)
                    _PurchaseButton(
                      label: 'Annual',
                      price: annual.storeProduct.priceString,
                      subtitle: 'Save 50%',
                      isPrimary: true,
                      isLoading: _isLoading,
                      onTap: () => _purchase(annual),
                    ),
                  if (annual != null)
                    const SizedBox(height: AppTheme.spacingSm),
                  if (monthly != null)
                    _PurchaseButton(
                      label: 'Monthly',
                      price: monthly.storeProduct.priceString,
                      subtitle: '',
                      isPrimary: annual == null,
                      isLoading: _isLoading,
                      onTap: () => _purchase(monthly),
                    ),

                  // Fallback if no packages are available
                  if (monthly == null && annual == null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
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

                  // Restore purchases
                  Center(
                    child: TextButton(
                      onPressed: _isRestoring ? null : _restore,
                      child: _isRestoring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Restore Purchases',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colorScheme.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.workspace_premium,
            size: 44,
            color: AppTheme.secondaryColor,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Text(
          'Unlock the Full Chefless Experience',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          'Unlimited recipes, extended scheduling, larger kitchens, '
          'and AI-powered meal planning.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FeatureComparisonTable extends StatelessWidget {
  const _FeatureComparisonTable();

  static const _features = [
    _FeatureRow(label: 'Recipes', free: '10', premium: 'Unlimited'),
    _FeatureRow(label: 'Schedule Range', free: '2 weeks', premium: 'Full year'),
    _FeatureRow(label: 'Kitchen Members', free: '4', premium: 'Unlimited'),
    _FeatureRow(label: 'AI Helper', free: '--', premium: 'Yes'),
    _FeatureRow(label: 'Chef Hat Badge', free: '--', premium: 'Yes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: SizedBox.shrink(),
                ),
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
            ..._features.map((feature) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
                  child: feature,
                )),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.label,
    required this.free,
    required this.premium,
  });

  final String label;
  final String free;
  final String premium;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _PurchaseButton extends StatelessWidget {
  const _PurchaseButton({
    required this.label,
    required this.price,
    required this.subtitle,
    required this.isPrimary,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final String price;
  final String subtitle;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return FilledButton(
        onPressed: isLoading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.secondaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$label  $price',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
      );
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              '$label  $price',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
