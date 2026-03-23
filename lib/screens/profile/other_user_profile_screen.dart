import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../utils/badge_utils.dart';
import '../../utils/extensions.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/report_sheet.dart';
import '../../widgets/user_avatar.dart';

/// Profile screen for viewing another user's profile.
class OtherUserProfileScreen extends ConsumerWidget {
  const OtherUserProfileScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
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
                  'Failed to load profile',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(userProfileProvider(userId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (result) {
        final user = result.user;
        final followStatus = result.followStatus;
        final badge = computeSpatulaBadge(user.recipesCount);
        final isPrivateAndNotFollowing =
            !user.isPublic && followStatus != 'active';

        return Scaffold(
          appBar: AppBar(
            title: Text(user.fullName),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'report') {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (context) => ReportSheet(
                        targetType: 'user',
                        targetId: userId,
                      ),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, size: 20),
                        SizedBox(width: AppTheme.spacingSm),
                        Text('Report User'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileProvider(userId));
              await ref.read(userProfileProvider(userId).future);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLg,
                vertical: AppTheme.spacingMd,
              ),
              children: [
                // Avatar
                Center(
                  child: UserAvatar(
                    fullName: user.fullName,
                    profilePictureUrl: user.profilePicture,
                    size: 96,
                    badge: badge,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Name + badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: AppTheme.spacingXs),
                      Tooltip(
                        message: badgeLabel(badge),
                        child: Icon(
                          badgeIcon(badge),
                          size: 20,
                          color: badgeColor(badge),
                        ),
                      ),
                    ],
                  ],
                ),

                // Bio
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    user.bio!,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: AppTheme.spacingMd),

                // Stats row
                _StatsRow(
                  recipesCount: user.recipesCount,
                  followersCount: user.followersCount,
                  followingCount: user.followingCount,
                ),

                const SizedBox(height: AppTheme.spacingMd),

                // Follow button
                _FollowButton(
                  userId: userId,
                  followStatus: followStatus,
                ),

                // Kitchen
                if (user.kitchenId != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.kitchen_outlined,
                        size: 18,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTheme.spacingXs),
                      Text(
                        'In a Kitchen',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppTheme.spacingLg),

                // Content — privacy wall or recipes tab
                if (isPrivateAndNotFollowing)
                  _PrivacyWall()
                else
                  _UserRecipesList(userId: userId),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Follow / Requested / Following button with three visual states.
class _FollowButton extends ConsumerWidget {
  const _FollowButton({
    required this.userId,
    required this.followStatus,
  });

  final String userId;
  final String followStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(followActionProvider);
    final isLoading = actionState is AsyncLoading;

    switch (followStatus) {
      case 'active':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () => _confirmUnfollow(context, ref),
            child: isLoading
                ? const _SmallLoader()
                : const Text('Following'),
          ),
        );
      case 'pending':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isLoading
                ? null
                : () {
                    ref.read(followActionProvider.notifier).unfollow(userId);
                  },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            child: isLoading
                ? const _SmallLoader()
                : Text(
                    'Requested',
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading
                ? null
                : () {
                    ref.read(followActionProvider.notifier).follow(userId);
                  },
            child: isLoading
                ? const _SmallLoader()
                : const Text('Follow'),
          ),
        );
    }
  }

  void _confirmUnfollow(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfollow'),
        content: const Text('Are you sure you want to unfollow this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(followActionProvider.notifier).unfollow(userId);
            },
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }
}

class _SmallLoader extends StatelessWidget {
  const _SmallLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.recipesCount,
    required this.followersCount,
    required this.followingCount,
  });

  final int recipesCount;
  final int followersCount;
  final int followingCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(count: recipesCount, label: 'Recipes'),
        _StatItem(count: followersCount, label: 'Followers'),
        _StatItem(count: followingCount, label: 'Following'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
  });

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatCount(count),
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

/// Shown when the account is private and the viewer is not a follower.
class _PrivacyWall extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXl),
      child: Column(
        children: [
          Icon(
            Icons.lock_outline,
            size: 48,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'This account is private',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Follow to see their recipes.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRecipesList extends ConsumerWidget {
  const _UserRecipesList({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(userRecipesProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          child: Text(
            'Recipes',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        recipesAsync.when(
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Text(
              'Failed to load recipes.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          data: (recipes) {
            if (recipes.isEmpty) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 40,
                        color: context.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'No recipes yet',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
              ),
              itemCount: recipes.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.spacingSm),
              itemBuilder: (context, index) {
                return RecipeCard(
                  recipe: recipes[index],
                  useRootRoute: true,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
