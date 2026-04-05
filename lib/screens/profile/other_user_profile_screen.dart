import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/profile_header_card.dart';
import '../../widgets/report_sheet.dart';
import '../../widgets/recipe_compact_row.dart';
import '../../widgets/shimmer_loading.dart';

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
      loading: () => const _OtherProfileScaffold(
        body: ProfileShimmer(),
      ),
      error: (error, _) => _OtherProfileScaffold(
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
                    color: AppTheme.textPrimaryDeep,
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
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentPlayful,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => ref.invalidate(userProfileProvider(userId)),
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
        final isPrivateAndNotFollowing =
            !user.isPublic && followStatus != 'active';

        return _OtherProfileScaffold(
          title: user.fullName,
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
          body: RefreshIndicator(
            color: AppTheme.accentPlayful,
            onRefresh: () async {
              ref.invalidate(userProfileProvider(userId));
              await ref.read(userProfileProvider(userId).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing12,
                AppTheme.spacing16,
                AppTheme.spacing32,
              ),
              children: [
                ProfileHeaderCard(
                  user: user,
                  eyebrow: 'Chef profile',
                  actionSection: _FollowButton(
                    userId: userId,
                    followStatus: followStatus,
                    isPublicAccount: user.isPublic,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                if (isPrivateAndNotFollowing)
                  const _PrivacyWall()
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

class _OtherProfileScaffold extends StatelessWidget {
  const _OtherProfileScaffold({
    required this.body,
    this.title = 'Profile',
    this.actions,
  });

  final Widget body;
  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text(
          title,
          style: AppTheme.displayTitleSmall(),
          overflow: TextOverflow.ellipsis,
        ),
        actions: actions,
      ),
      body: body,
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
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppTheme.accentPlayful.withValues(alpha: 0.35),
              ),
              foregroundColor: AppTheme.textPrimaryDeep,
            ),
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
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentPlayful,
              foregroundColor: Colors.white,
            ),
            onPressed: _isActioning ? null : _follow,
            child: const Text('Follow'),
          ),
        );
    }
  }
}

/// Shown when the account is private and the viewer is not a follower.
class _PrivacyWall extends StatelessWidget {
  const _PrivacyWall();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            decoration: BoxDecoration(
              color: AppTheme.accentPlayfulLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 36,
              color: AppTheme.accentPlayful.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'This account is private',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryDeep,
            ),
          ),
          const SizedBox(height: AppTheme.spacing6),
          Text(
            'Follow to unlock their recipes and activity.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
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

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shared recipes',
            style: AppTheme.displayTitleSmall(),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            'A curated look at what they cook and share.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          recipesAsync.when(
            loading: () => Column(
              children: const [
                RecipeCompactRowShimmer(gradientValue: 0.25),
                RecipeCompactRowShimmer(gradientValue: 0.5),
                RecipeCompactRowShimmer(gradientValue: 0.75),
              ],
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
                  height: 160,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentPlayfulLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            size: 30,
                            color: AppTheme.accentPlayful.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        Text(
                          'No recipes yet',
                          style: context.textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimaryDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  return RecipeCompactRow(
                    recipe: recipes[index],
                    useRootRoute: true,
                    showChevron: true,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
