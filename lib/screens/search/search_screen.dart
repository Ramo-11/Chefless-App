import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/search_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/recipe_compact_row.dart';
import '../../widgets/user_avatar.dart';

/// Suggested categories shown in the empty state for quick exploration.
const _suggestedCategories = [
  ('Quick Meals', Icons.timer_outlined),
  ('Italian', Icons.local_pizza_outlined),
  ('Healthy', Icons.eco_outlined),
  ('Breakfast', Icons.egg_outlined),
  ('Desserts', Icons.cake_outlined),
  ('Comfort Food', Icons.soup_kitchen_outlined),
  ('Vegan', Icons.spa_outlined),
  ('Grilling', Icons.outdoor_grill_outlined),
];

/// The maximum number of results to preview per section in the "All" tab.
const _allTabPreviewLimit = 5;

// ── Search Screen ───────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    if (query.trim().isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).add(query.trim());
    }
  }

  void _searchFromSuggestion(String text) {
    _controller.text = text;
    ref.read(searchQueryProvider.notifier).state = text;
    _submitSearch(text);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final hasQuery = query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppTheme.spacing16),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.gray50,
              borderRadius: AppTheme.borderRadiusFull,
              border: Border.all(color: AppTheme.gray200),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: AppTheme.spacing12),
                  child: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppTheme.gray400,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Search recipes, people, kitchens...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    style: context.textTheme.bodyMedium,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      ref.read(searchQueryProvider.notifier).state = value;
                    },
                    onSubmitted: _submitSearch,
                  ),
                ),
                if (query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppTheme.spacing8),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: AppTheme.gray300,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: hasQuery
            ? _ResultsBody(
                key: const ValueKey('results'),
                onSeeAll: (type) {
                  ref.read(searchTypeProvider.notifier).state = type;
                },
              )
            : _EmptyState(
                key: const ValueKey('empty'),
                onTapRecent: _searchFromSuggestion,
                onTapCategory: _searchFromSuggestion,
              ),
      ),
    );
  }
}

// ── Empty State (Recent Searches + Categories) ──────────────────────────────

class _EmptyState extends ConsumerWidget {
  const _EmptyState({
    super.key,
    required this.onTapRecent,
    required this.onTapCategory,
  });

  final ValueChanged<String> onTapRecent;
  final ValueChanged<String> onTapCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentSearchesProvider);
    final recentSearches = recentAsync.valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
      children: [
        // Recent searches
        if (recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing20,
            ),
            child: Row(
              children: [
                Text(
                  'Recent',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    ref.read(recentSearchesProvider.notifier).clearAll();
                  },
                  child: Text(
                    'Clear all',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          ...recentSearches.map(
            (query) => _RecentSearchTile(
              query: query,
              onTap: () => onTapRecent(query),
              onRemove: () {
                ref.read(recentSearchesProvider.notifier).remove(query);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
        ],

        // Explore categories
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing20,
          ),
          child: Text(
            'Explore',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.gray900,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
          ),
          child: Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: _suggestedCategories.map((entry) {
              final (label, icon) = entry;
              return GestureDetector(
                onTap: () => onTapCategory(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.borderRadiusFull,
                    border: Border.all(color: AppTheme.gray200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: AppTheme.gray500),
                      const SizedBox(width: AppTheme.spacing6),
                      Text(
                        label,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.gray700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  const _RecentSearchTile({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing20,
          vertical: AppTheme.spacing8,
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: AppTheme.gray400,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                query,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.gray300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results Body ────────────────────────────────────────────────────────────

class _ResultsBody extends ConsumerWidget {
  const _ResultsBody({
    super.key,
    required this.onSeeAll,
  });

  final ValueChanged<String> onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(searchTypeProvider);
    final searchAsync = ref.watch(searchResultsProvider);

    return Column(
      children: [
        // Type filter tabs
        searchAsync.when(
          loading: () => _TypeFilterRow(
            selected: selectedType,
            onSelected: (type) {
              ref.read(searchTypeProvider.notifier).state = type;
            },
          ),
          error: (error, stackTrace) => _TypeFilterRow(
            selected: selectedType,
            onSelected: (type) {
              ref.read(searchTypeProvider.notifier).state = type;
            },
          ),
          data: (results) => _TypeFilterRow(
            selected: selectedType,
            onSelected: (type) {
              ref.read(searchTypeProvider.notifier).state = type;
            },
            totals: results.totals,
          ),
        ),
        Container(height: 1, color: AppTheme.gray100),

        // Results
        Expanded(
          child: searchAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 64),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            error: (error, _) => _ErrorState(
              error: error,
              onRetry: () => ref.invalidate(searchResultsProvider),
            ),
            data: (results) {
              if (results.isEmpty) {
                return _NoResultsState(
                  query: ref.watch(searchQueryProvider),
                );
              }

              if (selectedType == 'all') {
                return _AllResultsView(
                  results: results,
                  onSeeAll: onSeeAll,
                );
              }

              return _TypedResultsView(
                results: results,
                type: selectedType,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Type Filter Row ─────────────────────────────────────────────────────────

class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({
    required this.selected,
    required this.onSelected,
    this.totals,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final SearchTotals? totals;

  @override
  Widget build(BuildContext context) {
    final types = [
      ('all', 'All', totals?.total),
      ('recipes', 'Recipes', totals?.recipes),
      ('users', 'People', totals?.users),
      ('kitchens', 'Kitchens', totals?.kitchens),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Row(
        children: types.map((entry) {
          final (value, label, count) = entry;
          final isSelected = selected == value;
          final displayLabel =
              count != null && count > 0 ? '$label ($count)' : label;

          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacing8),
            child: GestureDetector(
              onTap: () => onSelected(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: AppTheme.borderRadiusFull,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.gray200,
                  ),
                ),
                child: Text(
                  displayLabel,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.gray700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── All Results View ────────────────────────────────────────────────────────

class _AllResultsView extends StatelessWidget {
  const _AllResultsView({
    required this.results,
    required this.onSeeAll,
  });

  final SearchResults results;
  final ValueChanged<String> onSeeAll;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(
        top: AppTheme.spacing8,
        bottom: AppTheme.spacing48,
      ),
      children: [
        // Recipes section
        if (results.recipes.isNotEmpty)
          _ResultSection(
            title: 'Recipes',
            count: results.totals.recipes,
            showSeeAll: results.totals.recipes > _allTabPreviewLimit,
            onSeeAll: () => onSeeAll('recipes'),
            child: Column(
              children: results.recipes
                  .take(_allTabPreviewLimit)
                  .map(
                    (recipe) => RecipeCompactRow(
                      recipe: recipe,
                      useRootRoute: true,
                      showChevron: true,
                    ),
                  )
                  .toList(),
            ),
          ),

        // People section
        if (results.users.isNotEmpty)
          _ResultSection(
            title: 'People',
            count: results.totals.users,
            showSeeAll: results.totals.users > _allTabPreviewLimit,
            onSeeAll: () => onSeeAll('users'),
            child: Column(
              children: results.users
                  .take(_allTabPreviewLimit)
                  .map((user) => _UserTile(user: user))
                  .toList(),
            ),
          ),

        // Kitchens section
        if (results.kitchens.isNotEmpty)
          _ResultSection(
            title: 'Kitchens',
            count: results.totals.kitchens,
            showSeeAll: results.totals.kitchens > _allTabPreviewLimit,
            onSeeAll: () => onSeeAll('kitchens'),
            child: Column(
              children: results.kitchens
                  .take(_allTabPreviewLimit)
                  .map((kitchen) => _KitchenTile(kitchen: kitchen))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// ── Typed Results View ──────────────────────────────────────────────────────

class _TypedResultsView extends StatelessWidget {
  const _TypedResultsView({
    required this.results,
    required this.type,
  });

  final SearchResults results;
  final String type;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(
        top: AppTheme.spacing8,
        bottom: AppTheme.spacing48,
      ),
      children: switch (type) {
        'recipes' => results.recipes
            .map(
              (recipe) => RecipeCompactRow(
                recipe: recipe,
                useRootRoute: true,
                showChevron: true,
              ),
            )
            .toList(),
        'users' => results.users
            .map((user) => _UserTile(user: user))
            .toList(),
        'kitchens' => results.kitchens
            .map((kitchen) => _KitchenTile(kitchen: kitchen))
            .toList(),
        _ => const [],
      },
    );
  }
}

// ── Result Section (All Tab) ────────────────────────────────────────────────

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.count,
    required this.showSeeAll,
    required this.onSeeAll,
    required this.child,
  });

  final String title;
  final int count;
  final bool showSeeAll;
  final VoidCallback onSeeAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing20,
            vertical: AppTheme.spacing8,
          ),
          child: Row(
            children: [
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gray900,
                ),
              ),
              const SizedBox(width: AppTheme.spacing6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: AppTheme.borderRadiusFull,
                ),
                child: Text(
                  '$count',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: AppTheme.gray500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (showSeeAll)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        child,
        const SizedBox(height: AppTheme.spacing8),
      ],
    );
  }
}

// ── User Tile ───────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final SearchUser user;

  @override
  Widget build(BuildContext context) {
    final subtitle = user.bio != null && user.bio!.isNotEmpty
        ? user.bio!
        : '${user.recipesCount} recipe${user.recipesCount == 1 ? '' : 's'}';

    return InkWell(
      onTap: () => context.push('/user/${user.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing8,
        ),
        child: Row(
          children: [
            UserAvatar(
              fullName: user.fullName,
              profilePictureUrl: user.profilePicture,
              size: 48,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.gray900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!user.isPublic) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppTheme.gray400,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray500,
                    ),
                  ),
                  if (user.followersCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_formatCount(user.followersCount)} follower${user.followersCount == 1 ? '' : 's'}',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: AppTheme.gray400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.gray300,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Kitchen Tile ────────────────────────────────────────────────────────────

class _KitchenTile extends StatelessWidget {
  const _KitchenTile({required this.kitchen});

  final SearchKitchen kitchen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Navigate to kitchen detail (currently only supports own kitchen)
        context.push('/kitchen');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing8,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: AppTheme.borderRadiusMedium,
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: kitchen.photo != null
                  ? CachedNetworkImage(
                      imageUrl: kitchen.photo!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(
                        Icons.kitchen_rounded,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    )
                  : const Icon(
                      Icons.kitchen_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kitchen.name,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${kitchen.memberCount} member${kitchen.memberCount == 1 ? '' : 's'} · Led by ${kitchen.leadName}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.gray300,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty & Error States ────────────────────────────────────────────────────

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 32,
                color: AppTheme.gray300,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'No results for "$query"',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              'Try a different spelling or fewer words.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              'Something went wrong',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              style: context.textTheme.bodySmall?.copyWith(
                color: AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacing16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Utilities ───────────────────────────────────────────────────────────────

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return count.toString();
}
