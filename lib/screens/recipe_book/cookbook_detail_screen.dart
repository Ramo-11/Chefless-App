import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cookbook_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/error_state.dart';
import '../../widgets/recipe_compact_row.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/user_avatar.dart';
import 'cookbook_filter_sheet.dart';

class CookbookDetailScreen extends ConsumerStatefulWidget {
  const CookbookDetailScreen({super.key, required this.cookbookId});

  final String cookbookId;

  @override
  ConsumerState<CookbookDetailScreen> createState() =>
      _CookbookDetailScreenState();
}

class _CookbookDetailScreenState extends ConsumerState<CookbookDetailScreen> {
  String? _label;
  String? _dietary;
  String? _cuisine;
  int? _maxCookTime;
  String _sort = 'newest';

  CookbookRecipeFilters get _filters => CookbookRecipeFilters(
        label: _label,
        dietaryTag: _dietary,
        cuisineTag: _cuisine,
        maxCookTime: _maxCookTime,
        sort: _sort,
      );

  int get _activeFilterCount {
    var count = 0;
    if (_label != null) count++;
    if (_dietary != null) count++;
    if (_cuisine != null) count++;
    if (_maxCookTime != null) count++;
    return count;
  }

  void _clearFilters() {
    if (mounted) {
      setState(() {
        _label = null;
        _dietary = null;
        _cuisine = null;
        _maxCookTime = null;
      });
    }
  }

  Future<void> _openFilterSheet({
    required Iterable<Recipe> recipes,
  }) async {
    final labels = <String>{};
    final dietary = <String>{};
    final cuisine = <String>{};
    for (final recipe in recipes) {
      labels.addAll(recipe.labels);
      dietary.addAll(recipe.dietaryTags);
      cuisine.addAll(recipe.cuisineTags);
    }

    final result = await showCookbookFilterSheet(
      context: context,
      labels: labels,
      dietaryTags: dietary,
      cuisineTags: cuisine,
      initialLabel: _label,
      initialDietary: _dietary,
      initialCuisine: _cuisine,
      initialMaxCookTimeMinutes: _maxCookTime,
    );
    if (result == null || !mounted) return;
    setState(() {
      _label = result.label;
      _dietary = result.dietary;
      _cuisine = result.cuisine;
      _maxCookTime = result.maxCookTimeMinutes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cookbookAsync =
        ref.watch(cookbookDetailProvider(widget.cookbookId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final recipesAsync = ref.watch(
      cookbookRecipesProvider(
        CookbookRecipesArgs(
          cookbookId: widget.cookbookId,
          filters: _filters,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: cookbookAsync.maybeWhen(
          data: (c) => Text(
            c.name,
            style: AppTheme.displayTitleSmall(),
            overflow: TextOverflow.ellipsis,
          ),
          orElse: () => Text('Cookbook', style: AppTheme.displayTitleSmall()),
        ),
        actions: [
          cookbookAsync.maybeWhen(
            data: (c) {
              final isOwner = currentUser?.id == c.ownerId;
              if (!isOwner) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Cookbook options',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await context.push('/cookbook/${c.id}/edit');
                  } else if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete "${c.name}"?'),
                        content: const Text(
                          'The cookbook is removed but the recipes inside stay in your library.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Delete',
                              style: TextStyle(color: AppTheme.error),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final ok = await ref
                        .read(cookbookActionProvider.notifier)
                        .delete(c.id);
                    if (!context.mounted) return;
                    if (ok) {
                      context.pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to delete cookbook.'),
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: cookbookAsync.when(
        loading: () => const _CookbookLoadingState(),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(cookbookDetailProvider(widget.cookbookId)),
        ),
        data: (cookbook) {
          final isOwner = currentUser?.id == cookbook.ownerId;

          return RefreshIndicator(
            color: AppTheme.accentPlayful,
            onRefresh: () async {
              ref.invalidate(cookbookDetailProvider(widget.cookbookId));
              ref.invalidate(cookbookRecipesProvider);
              await ref.read(cookbookDetailProvider(widget.cookbookId).future);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _CookbookHeader(
                    cookbook: cookbook,
                    isOwner: isOwner,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FilterBar(
                    activeCount: _activeFilterCount,
                    sortLabel: _sortLabel(_sort),
                    onSortSelected: (value) {
                      if (mounted) setState(() => _sort = value);
                    },
                    onOpenFilters: () {
                      final loaded = recipesAsync.valueOrNull ?? const [];
                      _openFilterSheet(recipes: loaded);
                    },
                    onClearFilters:
                        _activeFilterCount > 0 ? _clearFilters : null,
                  ),
                ),
                recipesAsync.when(
                  loading: () => const SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      RecipeCompactRowShimmer(gradientValue: 0.25),
                      RecipeCompactRowShimmer(gradientValue: 0.5),
                      RecipeCompactRowShimmer(gradientValue: 0.75),
                    ]),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorState(
                      message: err.toString(),
                      onRetry: () =>
                          ref.invalidate(cookbookRecipesProvider),
                    ),
                  ),
                  data: (recipes) {
                    if (recipes.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(
                          isOwner: isOwner,
                          hasFilters: _activeFilterCount > 0,
                          onClearFilters: _clearFilters,
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => RecipeCompactRow(
                          recipe: recipes[index],
                          showChevron: true,
                          showAuthor: !isOwner,
                          useRootRoute: true,
                        ),
                        childCount: recipes.length,
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.spacing40),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _sortLabel(String value) {
    return switch (value) {
      'newest' => 'Newest',
      'oldest' => 'Oldest',
      'popular' => 'Most liked',
      'alphabetical' => 'A–Z',
      _ => 'Newest',
    };
  }
}

class _CookbookHeader extends StatelessWidget {
  const _CookbookHeader({required this.cookbook, required this.isOwner});

  final dynamic cookbook;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final coverPhoto = cookbook.coverPhoto as String?;
    final ownerName = cookbook.ownerName as String?;
    final ownerPhoto = cookbook.ownerPhoto as String?;
    final isPrivate = cookbook.isPrivate as bool;
    final description = cookbook.description as String?;
    final count = cookbook.recipesCount as int;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowSm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverPhoto != null)
              SizedBox(
                width: double.infinity,
                height: 160,
                child: CachedNetworkImage(
                  imageUrl: coverPhoto,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    color: AppTheme.gray100,
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppTheme.gray400,
                      size: 36,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentPlayfulLight,
                      AppTheme.primaryLight,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppTheme.accentPlayful,
                    size: 44,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${cookbook.name}',
                        style: AppTheme.displayTitleSmall(),
                      ),
                      if (isPrivate) ...[
                        const SizedBox(width: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPlayfulLight,
                            borderRadius: AppTheme.borderRadiusFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 12,
                                color: AppTheme.accentPlayful,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Private',
                                style:
                                    context.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.accentPlayful,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    '$count recipe${count == 1 ? '' : 's'}',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing12),
                    Text(
                      description,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gray700,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (!isOwner && ownerName != null) ...[
                    const SizedBox(height: AppTheme.spacing16),
                    InkWell(
                      onTap: () =>
                          context.push('/user/${cookbook.ownerId}'),
                      borderRadius: AppTheme.borderRadiusFull,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing4),
                        child: Row(
                          children: [
                            UserAvatar(
                              fullName: ownerName,
                              profilePictureUrl: ownerPhoto,
                              size: 28,
                            ),
                            const SizedBox(width: AppTheme.spacing8),
                            Expanded(
                              child: Text(
                                'Curated by $ownerName',
                                style:
                                    context.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.gray700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppTheme.gray400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeCount,
    required this.sortLabel,
    required this.onSortSelected,
    required this.onOpenFilters,
    required this.onClearFilters,
  });

  final int activeCount;
  final String sortLabel;
  final ValueChanged<String> onSortSelected;
  final VoidCallback onOpenFilters;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    final filterLabel = hasActive ? 'Filter · $activeCount' : 'Filter';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onOpenFilters,
            borderRadius: AppTheme.borderRadiusFull,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing8,
              ),
              decoration: BoxDecoration(
                color: hasActive
                    ? AppTheme.accentPlayfulLight
                    : AppTheme.surfaceElevated,
                borderRadius: AppTheme.borderRadiusFull,
                border: Border.all(
                  color: hasActive
                      ? AppTheme.accentPlayful.withValues(alpha: 0.4)
                      : AppTheme.gray200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: hasActive
                        ? AppTheme.accentPlayful
                        : AppTheme.gray700,
                  ),
                  const SizedBox(width: AppTheme.spacing6),
                  Text(
                    filterLabel,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: hasActive
                          ? AppTheme.accentPlayful
                          : AppTheme.gray700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onClearFilters != null) ...[
            const SizedBox(width: AppTheme.spacing8),
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear'),
            ),
          ],
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Sort',
            initialValue: _sortValueFromLabel(sortLabel),
            onSelected: onSortSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'newest', child: Text('Newest')),
              PopupMenuItem(value: 'oldest', child: Text('Oldest')),
              PopupMenuItem(value: 'popular', child: Text('Most liked')),
              PopupMenuItem(value: 'alphabetical', child: Text('A–Z')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing12,
                vertical: AppTheme.spacing8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sort: $sortLabel',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: AppTheme.gray700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.gray500,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sortValueFromLabel(String label) {
    return switch (label) {
      'Newest' => 'newest',
      'Oldest' => 'oldest',
      'Most liked' => 'popular',
      'A–Z' => 'alphabetical',
      _ => 'newest',
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isOwner,
    required this.hasFilters,
    required this.onClearFilters,
  });

  final bool isOwner;
  final bool hasFilters;
  final VoidCallback onClearFilters;

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
              decoration: const BoxDecoration(
                color: AppTheme.accentPlayfulLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons.filter_alt_off_outlined
                    : Icons.menu_book_outlined,
                size: 30,
                color: AppTheme.accentPlayful.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              hasFilters
                  ? 'No matching recipes'
                  : isOwner
                      ? 'Cookbook is empty'
                      : 'Nothing here yet',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryDeep,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              hasFilters
                  ? 'Try clearing the filters above.'
                  : isOwner
                      ? 'Open any of your recipes and tap "Add to cookbook" to fill this folder.'
                      : 'Check back later — the chef may add new recipes here.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.45,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: AppTheme.spacing12),
              TextButton(
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CookbookLoadingState extends StatelessWidget {
  const _CookbookLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: AppTheme.spacing40),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
