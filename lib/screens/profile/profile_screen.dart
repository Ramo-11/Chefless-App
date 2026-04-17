import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/cookbook.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cookbook_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/app_help_content.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/error_state.dart';
import '../../widgets/profile_header_card.dart';
import '../../widgets/recipe_compact_row.dart';
import '../../widgets/shimmer_loading.dart';

/// The current user's own profile screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => _ProfileScaffold(
        body: const ProfileShimmer(),
      ),
      error: (error, _) => _ProfileScaffold(
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

        return _ProfileScaffold(
          actions: [
            const NotificationBellIcon(),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
              tooltip: 'Settings',
            ),
            const MainTabMoreButton(topic: AppHelpTopic.profile),
          ],
          body: RefreshIndicator(
            color: AppTheme.accentPlayful,
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
              await ref.read(currentUserProvider.future);
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
                  eyebrow: 'Your kitchen journal',
                  onFollowersTap: () {
                    final loc =
                        GoRouterState.of(context).matchedLocation;
                    context.push('$loc/followers');
                  },
                  onFollowingTap: () {
                    final loc =
                        GoRouterState.of(context).matchedLocation;
                    context.push('$loc/following');
                  },
                  actionSection: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentPlayful,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final loc =
                            GoRouterState.of(context).matchedLocation;
                        context.push('$loc/edit');
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                const _OwnCookbooksSection(),
                const SizedBox(height: AppTheme.spacing20),
                _ProfileSnapshotSection(
                  recipeCount: user.recipesCount,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OwnCookbooksSection extends ConsumerWidget {
  const _OwnCookbooksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cookbooksAsync = ref.watch(myCookbooksProvider);

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your cookbooks',
                  style: AppTheme.displayTitleSmall(),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/cookbook/new'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentPlayful,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            'Group recipes into folders. Public ones appear on your profile.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          cookbooksAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.accentPlayful,
                    ),
                  ),
                ),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacing8,
              ),
              child: ErrorState(
                message: 'Couldn\'t load your cookbooks. '
                    'Check your connection and try again.',
                onRetry: () => ref.invalidate(myCookbooksProvider),
              ),
            ),
            data: (cookbooks) {
              if (cookbooks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing8,
                  ),
                  child: Text(
                    'No cookbooks yet — tap "New" to create your first one.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray500,
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cookbooks.length,
                  separatorBuilder: (_, _) => const SizedBox(
                    width: AppTheme.spacing12,
                  ),
                  itemBuilder: (context, index) =>
                      _OwnCookbookCard(cookbook: cookbooks[index]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OwnCookbookCard extends StatelessWidget {
  const _OwnCookbookCard({required this.cookbook});

  final Cookbook cookbook;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowCard,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppTheme.borderRadiusXL,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: AppTheme.borderRadiusXL,
            splashColor: AppTheme.accentPlayful.withValues(alpha: 0.12),
            highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.06),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/cookbook/${cookbook.id}');
            },
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
                          child: const Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: AppTheme.accentPlayful,
                            ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cookbook.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (cookbook.isPrivate)
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: AppTheme.accentPlayful,
                          ),
                      ],
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
      ),
    );
  }
}

class _ProfileScaffold extends StatelessWidget {
  const _ProfileScaffold({
    required this.body,
    this.actions,
  });

  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
                tooltip: 'Back',
              )
            : IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => context.push('/search'),
                tooltip: 'Search',
              ),
        title: Text(
          'Profile',
          style: AppTheme.displayTitleMedium(),
        ),
        actions: actions ?? const [NotificationBellIcon()],
      ),
      body: body,
    );
  }
}

class _ProfileSnapshotSection extends ConsumerWidget {
  const _ProfileSnapshotSection({
    required this.recipeCount,
  });

  final int recipeCount;

  static void _showFilteredRecipes(
    BuildContext context,
    String title,
    List<Recipe> recipes,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing12),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing20,
                    vertical: AppTheme.spacing16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTheme.displayTitleSmall(),
                        ),
                      ),
                      Text(
                        '${recipes.length}',
                        style: context.textTheme.titleMedium?.copyWith(
                          color: AppTheme.gray500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: recipes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.restaurant_menu_rounded,
                                size: 40,
                                color: AppTheme.gray300,
                              ),
                              const SizedBox(height: AppTheme.spacing12),
                              Text(
                                'No recipes here yet',
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.gray500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing4,
                          ),
                          itemCount: recipes.length,
                          itemBuilder: (context, index) {
                            return RecipeCompactRow(
                              recipe: recipes[index],
                              showAuthor: false,
                              showChevron: true,
                              showVisibilityBadge: true,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRecipes = ref.watch(myRecipesProvider);
    final likedRecipes = ref.watch(likedRecipesProvider);
    final likedCount = likedRecipes.valueOrNull?.length ?? 0;
    final ownedRecipes = myRecipes.valueOrNull ?? const <Recipe>[];
    final privateCount = ownedRecipes.where((recipe) => recipe.isPrivate).length;
    final publicCount = ownedRecipes.where((recipe) => !recipe.isPrivate).length;

    return Column(
      children: [
        Container(
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
                'Snapshot',
                style: AppTheme.displayTitleSmall(),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                'A quick look at your cooking habits without duplicating the full recipe book.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Row(
                children: [
                  Expanded(
                    child: _ProfileInsightCard(
                      label: 'Created',
                      value: '$recipeCount',
                      icon: Icons.menu_book_rounded,
                      onTap: () => _showFilteredRecipes(
                        context,
                        'Created Recipes',
                        ownedRecipes,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: _ProfileInsightCard(
                      label: 'Public',
                      value: '$publicCount',
                      icon: Icons.public_rounded,
                      onTap: () => _showFilteredRecipes(
                        context,
                        'Public Recipes',
                        ownedRecipes
                            .where((r) => !r.isPrivate)
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              Row(
                children: [
                  Expanded(
                    child: _ProfileInsightCard(
                      label: 'Private',
                      value: '$privateCount',
                      icon: Icons.lock_outline_rounded,
                      onTap: () => _showFilteredRecipes(
                        context,
                        'Private Recipes',
                        ownedRecipes
                            .where((r) => r.isPrivate)
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: _ProfileInsightCard(
                      label: 'Saved',
                      value: '$likedCount',
                      icon: Icons.favorite_outline_rounded,
                      onTap: () => _showFilteredRecipes(
                        context,
                        'Saved Recipes',
                        likedRecipes.valueOrNull ?? const [],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing20),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: AppTheme.borderRadiusXL,
            boxShadow: AppTheme.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent creations',
                          style: AppTheme.displayTitleSmall(),
                        ),
                        const SizedBox(height: AppTheme.spacing4),
                        Text(
                          'Your latest recipes, with the full library living in Recipe Book.',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.gray500,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/recipes'),
                    icon: const Icon(Icons.arrow_outward_rounded, size: 16),
                    label: const Text('Open Recipe Book'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              myRecipes.when(
                loading: () => Column(
                  children: const [
                    RecipeCompactRowShimmer(gradientValue: 0.2),
                    RecipeCompactRowShimmer(gradientValue: 0.5),
                    RecipeCompactRowShimmer(gradientValue: 0.8),
                  ],
                ),
                error: (error, _) => ErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(myRecipesProvider),
                ),
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return const _ModernRecipeEmptyState(
                      icon: Icons.restaurant_menu_rounded,
                      title: 'No recipes yet',
                      subtitle:
                          'Create your first recipe and it will appear here as part of your profile snapshot.',
                    );
                  }

                  final preview = [...recipes]
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return Column(
                    children: [
                      ...preview.take(3).map(
                            (recipe) => RecipeCompactRow(
                              recipe: recipe,
                              showAuthor: false,
                              showChevron: true,
                              showVisibilityBadge: true,
                            ),
                          ),
                      const SizedBox(height: AppTheme.spacing8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/recipes'),
                          icon: const Icon(Icons.grid_view_rounded, size: 18),
                          label: const Text('View Full Library'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileInsightCard extends StatelessWidget {
  const _ProfileInsightCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceWarm,
      borderRadius: AppTheme.borderRadiusLarge,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: AppTheme.borderRadiusLarge,
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.12),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: AppTheme.accentPlayful,
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppTheme.gray400,
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                value,
                style: context.textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimaryDeep,
                  fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}

class _ModernRecipeEmptyState extends StatelessWidget {
  const _ModernRecipeEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentPlayfulLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppTheme.accentPlayful,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimaryDeep,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              subtitle,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
