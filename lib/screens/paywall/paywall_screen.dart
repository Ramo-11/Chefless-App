import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../utils/constants.dart';
import '../../utils/extensions.dart';

// Warm accent color for the paywall — premium gold/amber tone.
const _accentColor = Color(0xFFD4920B);
const _accentLight = Color(0xFFF5C842);
const _accentBg = Color(0xFFFFF8E7);

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = false;
  bool _isRestoring = false;
  bool _showPromoInput = false;
  bool _isRedeeming = false;
  String? _promoError;
  final _promoController = TextEditingController();

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _redeemPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      setState(() => _promoError = 'Please enter a promo code');
      return;
    }
    if (_isRedeeming) return;
    setState(() {
      _isRedeeming = true;
      _promoError = null;
    });
    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/promo-codes/redeem',
        data: {'code': code},
      );
      if (!mounted) return;
      if (result.isSuccess) {
        ref.invalidate(isPremiumProvider);
        ref.invalidate(currentUserProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated!')),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _promoError = result.error ?? 'Failed to redeem code';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _promoError = 'Something went wrong. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

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

  Widget _buildPromoCodeSection(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showPromoInput = !_showPromoInput),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Have a promo code?',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppTheme.gray500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showPromoInput
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppTheme.gray400,
                ),
              ],
            ),
          ),
        ),
        if (_showPromoInput) ...[
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing12,
                      vertical: AppTheme.spacing12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadiusSmall,
                      borderSide: const BorderSide(color: AppTheme.gray200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadiusSmall,
                      borderSide: const BorderSide(color: AppTheme.gray200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadiusSmall,
                      borderSide: const BorderSide(color: _accentColor),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadiusSmall,
                      borderSide: BorderSide(color: AppTheme.error),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _isRedeeming ? null : _redeemPromoCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                    ),
                  ),
                  child: _isRedeeming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Apply',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
          if (_promoError != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              _promoError!,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppTheme.error,
              ),
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!RevenueCatConstants.isConfigured) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _accentBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 36,
                    color: _accentColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                Text(
                  'Subscriptions coming soon',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  'Premium features are not available yet. Stay tuned!',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
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
              padding: const EdgeInsets.all(AppTheme.spacing48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.errorLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 28,
                      color: AppTheme.error,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    'Unable to load subscription options.',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
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
                    icon: const Icon(Icons.close_rounded),
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
                        const SizedBox(height: AppTheme.spacing8),

                        // App logo
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: AppTheme.borderRadiusXL,
                            boxShadow: AppTheme.shadowSm,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 80,
                            height: 80,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing24),

                        // Title
                        Text(
                          'Upgrade to\nChefless Pro',
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.5,
                            color: AppTheme.gray900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          'Take your cooking to the next level',
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.gray500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: AppTheme.spacing32),

                        // Feature list
                        const _FeatureList(),

                        const SizedBox(height: AppTheme.spacing32),

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
                          const SizedBox(height: AppTheme.spacing12),
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
                                color: AppTheme.gray500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: AppTheme.spacing16),

                        // Promo code section
                        _buildPromoCodeSection(context),

                        const SizedBox(height: AppTheme.spacing8),

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
                                    color: AppTheme.gray400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        const SizedBox(height: AppTheme.spacing16),
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
    _Feature(icon: Icons.all_inclusive_rounded, text: 'Unlimited recipe storage'),
    _Feature(icon: Icons.calendar_month_rounded, text: 'Schedule meals for the full year'),
    _Feature(icon: Icons.group_rounded, text: 'Unlimited kitchen members'),
    _Feature(icon: Icons.auto_awesome_rounded, text: 'AI-powered recipe helper'),
    _Feature(icon: Icons.verified_rounded, text: 'Chef hat badge on your profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.gray200.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: _features
            .map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                  child: f,
                ))
            .toList(),
      ),
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
            color: _accentBg,
            borderRadius: AppTheme.borderRadiusSmall,
          ),
          child: Icon(
            icon,
            size: 20,
            color: _accentColor,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: AppTheme.gray800,
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
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(
            color: isSelected
                ? _accentColor
                : AppTheme.gray200,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? _accentBg : Colors.white,
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
                      : AppTheme.gray300,
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
            const SizedBox(width: AppTheme.spacing12),

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
                          color: AppTheme.gray900,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_accentColor, _accentLight],
                            ),
                            borderRadius: AppTheme.borderRadiusFull,
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
                        color: AppTheme.gray500,
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
                          color: AppTheme.gray900,
                        ),
                      ),
                      Text(
                        period,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.gray400,
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

// ── Upper Case Input Formatter ───────────────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
