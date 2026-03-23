import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/badge_utils.dart';
import '../../utils/extensions.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/user_avatar.dart';

/// The current user's own profile screen (Tab 5).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
            tooltip: 'Search',
          ),
          title: const Text('Profile'),
        ),
        body: const ProfileShimmer(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
            tooltip: 'Search',
          ),
          title: const Text('Profile'),
        ),
        body: ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Not signed in.')),
          );
        }

        final badge = computeSpatulaBadge(user.recipesCount);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.push('/search'),
              tooltip: 'Search',
            ),
            title: const Text('Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
              // Wait for the new data to arrive.
              await ref.read(currentUserProvider.future);
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
                    Text(
                      user.fullName,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
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
                  onFollowersTap: () => context.push('/profile/followers'),
                  onFollowingTap: () => context.push('/profile/following'),
                ),

                const SizedBox(height: AppTheme.spacingMd),

                // Edit Profile button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/profile/edit'),
                    child: const Text('Edit Profile'),
                  ),
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

                // Sub-tabs
                const _ProfileSubTabs(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Displays recipes / followers / following counts in a horizontal row.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.recipesCount,
    required this.followersCount,
    required this.followingCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final int recipesCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(
          count: recipesCount,
          label: 'Recipes',
        ),
        GestureDetector(
          onTap: onFollowersTap,
          child: _StatItem(
            count: followersCount,
            label: 'Followers',
          ),
        ),
        GestureDetector(
          onTap: onFollowingTap,
          child: _StatItem(
            count: followingCount,
            label: 'Following',
          ),
        ),
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

/// Tabs showing the user's own, liked, and forked recipes.
class _ProfileSubTabs extends StatelessWidget {
  const _ProfileSubTabs();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'My Recipes'),
              Tab(text: 'Liked'),
              Tab(text: 'Forked'),
            ],
            labelColor: context.colorScheme.primary,
            unselectedLabelColor: context.colorScheme.onSurfaceVariant,
            indicatorColor: context.colorScheme.primary,
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [
                _ProfileRecipeList(
                  provider: myRecipesProvider,
                  emptyIcon: Icons.restaurant_menu,
                  emptyMessage: 'No recipes yet',
                  emptySubMessage: 'Create your first recipe to see it here',
                ),
                _ProfileRecipeList(
                  provider: likedRecipesProvider,
                  emptyIcon: Icons.favorite_outline,
                  emptyMessage: 'No liked recipes',
                  emptySubMessage: 'Like recipes to save them here',
                ),
                _ProfileRecipeList(
                  provider: forkedRecipesProvider,
                  emptyIcon: Icons.fork_right,
                  emptyMessage: 'No forked recipes',
                  emptySubMessage: 'Fork recipes to make them your own',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRecipeList extends ConsumerWidget {
  const _ProfileRecipeList({
    required this.provider,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubMessage,
  });

  final FutureProvider<List<Recipe>> provider;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptySubMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(provider);

    return recipesAsync.when(
      loading: () => const RecipeCardShimmerList(itemCount: 2),
      error: (error, _) => ErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (recipes) {
        if (recipes.isEmpty) {
          return EmptyState(
            icon: emptyIcon,
            title: emptyMessage,
            subtitle: emptySubMessage,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          itemCount: recipes.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: RecipeCard(recipe: recipes[index]),
          ),
        );
      },
    );
  }
}
