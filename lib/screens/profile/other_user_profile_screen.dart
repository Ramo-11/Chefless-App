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
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 32,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Failed to load profile',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing20),
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
                vertical: AppTheme.spacing20,
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
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppTheme.gray900,
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
                  const SizedBox(height: AppTheme.spacing6),
                  Text(
                    user.bio!,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: AppTheme.spacing20),

                // Stats row
                _StatsRow(
                  recipesCount: user.recipesCount,
                  followersCount: user.followersCount,
                  followingCount: user.followingCount,
                ),

                const SizedBox(height: AppTheme.spacing20),

                // Follow button
                _FollowButton(
                  userId: userId,
                  followStatus: followStatus,
                  isPublicAccount: user.isPublic,
                ),

                // Kitchen
                if (user.kitchenId != null) ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: AppTheme.borderRadiusFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.kitchen_outlined,
                            size: 16,
                            color: AppTheme.gray500,
                          ),
                          const SizedBox(width: AppTheme.spacing4),
                          Text(
                            'In a Kitchen',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppTheme.gray500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Follow / Requested / Following button with optimistic UI updates.
///
/// Tracks its own local state so the button updates instantly on tap,
/// without waiting for the API round-trip or profile re-fetch.
class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({
    required this.userId,
    required this.followStatus,
    required this.isPublicAccount,
  });

  final String userId;
  final String followStatus;
  final bool isPublicAccount;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  late String _localStatus;
  bool _isActioning = false;

  @override
  void initState() {
    super.initState();
    _localStatus = widget.followStatus;
  }

  @override
  void didUpdateWidget(covariant _FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from server data if not mid-action (e.g. pull-to-refresh).
    if (!_isActioning && widget.followStatus != oldWidget.followStatus) {
      _localStatus = widget.followStatus;
    }
  }

  Future<void> _follow() async {
    final previousStatus = _localStatus;
    if (mounted) {
      setState(() {
        _isActioning = true;
        _localStatus = widget.isPublicAccount ? 'active' : 'pending';
      });
    }
    try {
      await ref.read(followActionProvider.notifier).follow(widget.userId);
    } catch (_) {
      // Revert on failure.
      if (mounted) setState(() => _localStatus = previousStatus);
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _unfollow() async {
    final previousStatus = _localStatus;
    if (mounted) {
      setState(() {
        _isActioning = true;
        _localStatus = 'none';
      });
    }
    try {
      await ref.read(followActionProvider.notifier).unfollow(widget.userId);
    } catch (_) {
      if (mounted) setState(() => _localStatus = previousStatus);
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _confirmUnfollow() {
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
              _unfollow();
            },
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_localStatus) {
      case 'active':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isActioning ? null : _confirmUnfollow,
            child: const Text('Following'),
          ),
        );
      case 'pending':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isActioning ? null : _unfollow,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.gray300),
              foregroundColor: AppTheme.gray500,
            ),
            child: const Text('Requested'),
          ),
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isActioning ? null : _follow,
            child: const Text('Follow'),
          ),
        );
    }
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
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.spacingMd,
        horizontal: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(count: recipesCount, label: 'Recipes'),
          Container(width: 1, height: 32, color: AppTheme.gray200),
          _StatItem(count: followersCount, label: 'Followers'),
          Container(width: 1, height: 32, color: AppTheme.gray200),
          _StatItem(count: followingCount, label: 'Following'),
        ],
      ),
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
            fontWeight: FontWeight.w700,
            color: AppTheme.gray900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: AppTheme.gray500,
            fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            decoration: BoxDecoration(
              color: AppTheme.gray50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 36,
              color: AppTheme.gray400,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'This account is private',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: AppTheme.spacing6),
          Text(
            'Follow to see their recipes.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
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
          padding: const EdgeInsets.only(
            bottom: AppTheme.spacing12,
          ),
          child: Text(
            'Recipes',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.gray900,
              letterSpacing: -0.1,
            ),
          ),
        ),
        recipesAsync.when(
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.gray50,
              borderRadius: AppTheme.borderRadiusMedium,
            ),
            child: Text(
              'Failed to load recipes.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
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
                        size: 36,
                        color: AppTheme.gray300,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'No recipes yet',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.gray500,
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
              itemCount: recipes.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.spacing12),
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
