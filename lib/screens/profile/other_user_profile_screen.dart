import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/cookbook.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cookbook_provider.dart';
import '../../providers/kitchen_provider.dart';
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
              await ref.read(userRecipesPagedProvider(userId).notifier).refresh();
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
                  actionSection: Column(
                    children: [
                      _FollowButton(
                        userId: userId,
                        followStatus: followStatus,
                        isPublicAccount: user.isPublic,
                      ),
                      _KitchenInviteButton(targetUser: user),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                if (isPrivateAndNotFollowing)
                  const _PrivacyWall()
                else ...[
                  _UserCookbooksSection(userId: userId),
                  const SizedBox(height: AppTheme.spacing20),
                  _UserRecipesList(userId: userId),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserCookbooksSection extends ConsumerWidget {
  const _UserCookbooksSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cookbooksAsync = ref.watch(userCookbooksProvider(userId));

    return cookbooksAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (cookbooks) {
        if (cookbooks.isEmpty) return const SizedBox.shrink();
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
                'Cookbooks',
                style: AppTheme.displayTitleSmall(),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                '${cookbooks.length} cookbook${cookbooks.length == 1 ? '' : 's'} from this chef.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray500,
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cookbooks.length,
                  separatorBuilder: (_, _) => const SizedBox(
                    width: AppTheme.spacing12,
                  ),
                  itemBuilder: (context, index) =>
                      _ProfileCookbookCard(cookbook: cookbooks[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileCookbookCard extends StatelessWidget {
  const _ProfileCookbookCard({required this.cookbook});

  final Cookbook cookbook;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: InkWell(
        borderRadius: AppTheme.borderRadiusXL,
        onTap: () => context.push('/cookbook/${cookbook.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: AppTheme.borderRadiusXL,
            border: Border.all(color: AppTheme.gray100),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: cookbook.coverPhoto != null
                    ? CachedNetworkImage(
                        imageUrl: cookbook.coverPhoto!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: AppTheme.accentPlayfulLight,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: AppTheme.accentPlayful,
                          ),
                        ),
                      )
                    : Container(
                        color: AppTheme.accentPlayfulLight,
                        child: const Center(
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: AppTheme.accentPlayful,
                            size: 32,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cookbook.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cookbook.recipesCount} recipe'
                      '${cookbook.recipesCount == 1 ? '' : 's'}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppTheme.gray500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    final recipesAsync = ref.watch(userRecipesPagedProvider(userId));

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Failed to load recipes.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray500,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  TextButton(
                    onPressed: () => ref
                        .read(userRecipesPagedProvider(userId).notifier)
                        .loadInitial(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (paged) {
              final recipes = paged.recipes;
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (paged.totalCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                      child: Text(
                        '${recipes.length} of ${paged.totalCount} recipe'
                        '${paged.totalCount == 1 ? '' : 's'}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.gray500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ListView.builder(
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
                  ),
                  if (paged.hasMore) ...[
                    const SizedBox(height: AppTheme.spacing12),
                    Center(
                      child: paged.isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppTheme.spacing8,
                              ),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : TextButton.icon(
                              onPressed: () => ref
                                  .read(
                                    userRecipesPagedProvider(userId).notifier,
                                  )
                                  .loadMore(),
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text('Load more'),
                            ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Shown under the Follow button when the viewer is the lead of a kitchen
/// and the target user is eligible to be invited:
/// - Not the viewer themselves.
/// - Not already in the viewer's (or any) kitchen.
///
/// Uses session-only local state so the button flips to "Invite sent" after
/// a successful send, without requiring a full refetch.
class _KitchenInviteButton extends ConsumerStatefulWidget {
  const _KitchenInviteButton({required this.targetUser});

  final CheflessUser targetUser;

  @override
  ConsumerState<_KitchenInviteButton> createState() =>
      _KitchenInviteButtonState();
}

class _KitchenInviteButtonState
    extends ConsumerState<_KitchenInviteButton> {
  bool _isSending = false;
  bool _wasSent = false;

  Future<void> _send() async {
    if (_isSending || _wasSent) return;
    setState(() => _isSending = true);

    final ok = await ref
        .read(kitchenActionProvider.notifier)
        .sendKitchenInvite(widget.targetUser.id);

    if (!mounted) return;
    setState(() => _isSending = false);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      setState(() => _wasSent = true);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Invite sent to ${widget.targetUser.fullName}.'),
        ),
      );
    } else {
      final errorState = ref.read(kitchenActionProvider);
      final message = errorState is AsyncError
          ? errorState.error.toString().replaceFirst('Exception: ', '')
          : 'Failed to send invite.';
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
          content: Text(message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final myKitchenAsync = ref.watch(myKitchenProvider);

    final currentUser = currentUserAsync.valueOrNull;

    // Hide on self-profile — inviting yourself is never useful.
    if (currentUser == null || currentUser.id == widget.targetUser.id) {
      return const SizedBox.shrink();
    }

    // Wait for kitchen state before deciding — the invite affordance depends
    // on it. Show a subtle placeholder rather than flicker in on load.
    if (myKitchenAsync.isLoading && !myKitchenAsync.hasValue) {
      return const SizedBox.shrink();
    }

    final myKitchen = myKitchenAsync.valueOrNull;

    // If the target is already in the viewer's own kitchen, the invite is
    // irrelevant — hide entirely.
    if (myKitchen != null &&
        widget.targetUser.kitchenId != null &&
        widget.targetUser.kitchenId == myKitchen.kitchen.id) {
      return const SizedBox.shrink();
    }

    // State derivation — any kitchen member can invite. Capacity depends on
    // the lead's premium status, which the client can't see from the Kitchen
    // payload; the server is the source of truth and returns a friendly error
    // that we surface via SnackBar if the invite is rejected.
    final bool hasKitchen = myKitchen != null;
    final bool targetInOtherKitchen = widget.targetUser.kitchenId != null;

    final String labelText;
    final IconData iconData;
    final bool disabled;

    if (!hasKitchen) {
      labelText = 'Create a kitchen to invite';
      iconData = Icons.kitchen_outlined;
      disabled = true;
    } else if (targetInOtherKitchen) {
      labelText = 'Already in a kitchen';
      iconData = Icons.kitchen_outlined;
      disabled = true;
    } else if (_wasSent) {
      labelText = 'Invite sent';
      iconData = Icons.check_circle_outline_rounded;
      disabled = true;
    } else {
      labelText = 'Invite to kitchen';
      iconData = Icons.kitchen_rounded;
      disabled = false;
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: (_isSending || disabled) ? null : _send,
          style: OutlinedButton.styleFrom(
            foregroundColor:
                disabled ? AppTheme.gray500 : AppTheme.primaryDark,
            side: BorderSide(
              color: disabled
                  ? AppTheme.gray300
                  : AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(iconData, size: 18),
          label: Text(labelText),
        ),
      ),
    );
  }
}
