import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/user.dart';
import '../utils/badge_utils.dart';
import '../utils/extensions.dart';
import 'user_avatar.dart';

String formatCompactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.user,
    required this.eyebrow,
    this.onRecipesTap,
    this.onFollowersTap,
    this.onFollowingTap,
    this.actionSection,
  });

  final CheflessUser user;
  final String eyebrow;
  final VoidCallback? onRecipesTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final Widget? actionSection;

  @override
  Widget build(BuildContext context) {
    final badge = computeSpatulaBadge(user.recipesCount);
    final memberSince = DateFormat('MMM yyyy').format(user.createdAt);
    final chips = <_ProfileChipData>[
      _ProfileChipData(
        icon: user.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
        label: user.isPublic ? 'Public profile' : 'Private profile',
      ),
      if (user.isPremium)
        const _ProfileChipData(
          icon: Icons.workspace_premium_rounded,
          label: 'Premium',
        ),
      if (user.kitchenId != null)
        const _ProfileChipData(
          icon: Icons.kitchen_outlined,
          label: 'Kitchen member',
        ),
      ...user.dietaryPreferences.take(2).map(
            (dietary) => _ProfileChipData(
              icon: Icons.eco_rounded,
              label: dietary,
            ),
          ),
      ...user.cuisinePreferences
          .take(2)
          .map(
            (cuisine) => _ProfileChipData(
              icon: Icons.auto_awesome,
              label: cuisine,
            ),
          ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowFeatured,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.accentPlayfulLight.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentPlayful.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -36,
            left: -10,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryLight.withValues(alpha: 0.45),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: context.textTheme.labelMedium?.copyWith(
                  color: AppTheme.accentPlayful,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Center(
                child: UserAvatar(
                  fullName: user.fullName,
                  profilePictureUrl: user.profilePicture,
                  size: 88,
                  badge: badge,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppTheme.spacing6,
                  runSpacing: AppTheme.spacing6,
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      user.fullName,
                      style: AppTheme.displayTitleMedium(),
                      textAlign: TextAlign.center,
                    ),
                    if (badge != null)
                      Tooltip(
                        message: badgeLabel(badge),
                        child: Icon(
                          badgeIcon(badge),
                          size: 20,
                          color: badgeColor(badge),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing6),
              Center(
                child: Text(
                  'Member since $memberSince',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppTheme.gray500,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing12),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    user.bio!,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray600,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing16),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppTheme.spacing8,
                    runSpacing: AppTheme.spacing8,
                    children: chips
                        .map(
                          (chip) => _ProfileMetaChip(
                            icon: chip.icon,
                            label: chip.label,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacing20),
              _ProfileMetricStrip(
                recipesCount: user.recipesCount,
                followersCount: user.followersCount,
                followingCount: user.followingCount,
                onRecipesTap: onRecipesTap,
                onFollowersTap: onFollowersTap,
                onFollowingTap: onFollowingTap,
              ),
              if (actionSection != null) ...[
                const SizedBox(height: AppTheme.spacing16),
                actionSection!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileChipData {
  const _ProfileChipData({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _ProfileMetaChip extends StatelessWidget {
  const _ProfileMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.accentPlayful.withValues(alpha: 0.75),
        ),
        const SizedBox(width: AppTheme.spacing6),
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: AppTheme.gray600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProfileMetricStrip extends StatelessWidget {
  const _ProfileMetricStrip({
    required this.recipesCount,
    required this.followersCount,
    required this.followingCount,
    this.onRecipesTap,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final int recipesCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback? onRecipesTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.gray200.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProfileMetricCell(
              value: recipesCount,
              label: 'Recipes',
              onTap: onRecipesTap,
            ),
          ),
          _MetricDivider(),
          Expanded(
            child: _ProfileMetricCell(
              value: followersCount,
              label: 'Followers',
              onTap: onFollowersTap,
            ),
          ),
          _MetricDivider(),
          Expanded(
            child: _ProfileMetricCell(
              value: followingCount,
              label: 'Following',
              onTap: onFollowingTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppTheme.gray200,
    );
  }
}

class _ProfileMetricCell extends StatelessWidget {
  const _ProfileMetricCell({
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCompactCount(value),
            style: context.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimaryDeep,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: AppTheme.gray500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusMedium,
      child: child,
    );
  }
}
