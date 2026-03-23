import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/search_provider.dart';
import '../../utils/extensions.dart';
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
      appBar: AppBar(
        titleSpacing: 0,
        title: _SearchField(
          controller: _controller,
          focusNode: _focusNode,
          query: query,
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
          onClear: () {
            _controller.clear();
            ref.read(searchQueryProvider.notifier).state = '';
          },
          onSubmitted: _submitSearch,
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

// ── Search Field ────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: 'Search recipes, people, kitchens...',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingSm,
        ),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: onClear,
                tooltip: 'Clear',
              )
            : null,
      ),
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
      children: [
        // Recent searches
        if (recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
            ),
            child: Row(
              children: [
                Text(
                  'Recent',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(recentSearchesProvider.notifier).clearAll();
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Clear all',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          ...recentSearches.map(
            (query) => _RecentSearchTile(
              query: query,
              onTap: () => onTapRecent(query),
              onRemove: () {
                ref.read(recentSearchesProvider.notifier).remove(query);
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
        ],

        // Explore categories
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
          ),
          child: Text(
            'Explore',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
          ),
          child: Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: _suggestedCategories.map((entry) {
              final (label, icon) = entry;
              return ActionChip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                onPressed: () => onTapCategory(label),
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
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
      ),
      leading: Icon(
        Icons.history,
        size: 20,
        color: context.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        query,
        style: context.textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.close,
          size: 18,
          color: context.colorScheme.onSurfaceVariant,
        ),
        onPressed: onRemove,
        tooltip: 'Remove',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
      onTap: onTap,
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
        const Divider(height: 1),

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
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: types.map((entry) {
          final (value, label, count) = entry;
          final isSelected = selected == value;
          final displayLabel =
              count != null && count > 0 ? '$label ($count)' : label;

          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacingSm),
            child: FilterChip(
              label: Text(displayLabel),
              selected: isSelected,
              onSelected: (_) => onSelected(value),
              showCheckmark: false,
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
        top: AppTheme.spacingSm,
        bottom: AppTheme.spacingXl,
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
                  .map((recipe) => _CompactRecipeCard(recipe: recipe))
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
        top: AppTheme.spacingSm,
        bottom: AppTheme.spacingXl,
      ),
      children: switch (type) {
        'recipes' => results.recipes
            .map((recipe) => _CompactRecipeCard(recipe: recipe))
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
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          child: Row(
            children: [
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                '($count)',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (showSeeAll)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: context.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        child,
        const SizedBox(height: AppTheme.spacingSm),
      ],
    );
  }
}

// ── Compact Recipe Card ─────────────────────────────────────────────────────

class _CompactRecipeCard extends StatelessWidget {
  const _CompactRecipeCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = recipe.photos.isNotEmpty;
    final timeText = _formatTime(recipe.totalTime ?? recipe.cookTime);
    final difficultyText = recipe.difficulty;

    return InkWell(
      onTap: () => context.push('/recipe/${recipe.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: AppTheme.borderRadiusSmall,
              child: SizedBox(
                width: 72,
                height: 72,
                child: hasPhoto
                    ? CachedNetworkImage(
                        imageUrl: recipe.photos.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color:
                              context.colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) =>
                            _RecipePlaceholder(context: context),
                      )
                    : _RecipePlaceholder(context: context),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm + 4),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    recipe.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Author
                  if (recipe.authorName != null)
                    Text(
                      'by ${recipe.authorName}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),

                  // Metadata row: time, difficulty, likes
                  Row(
                    children: [
                      if (timeText != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          timeText,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                      ],
                      if (difficultyText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _difficultyColor(difficultyText)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            difficultyText[0].toUpperCase() +
                                difficultyText.substring(1),
                            style:
                                context.textTheme.labelSmall?.copyWith(
                              color: _difficultyColor(difficultyText),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                      ],
                      if (recipe.likesCount > 0) ...[
                        const Icon(
                          Icons.favorite,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.likesCount}',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  static String? _formatTime(int? minutes) {
    if (minutes == null || minutes <= 0) return null;
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  static Color _difficultyColor(String difficulty) {
    return switch (difficulty.toLowerCase()) {
      'easy' => const Color(0xFF43A047),
      'medium' => const Color(0xFFF59E0B),
      'hard' => const Color(0xFFEF233C),
      _ => const Color(0xFF8D99AE),
    };
  }
}

class _RecipePlaceholder extends StatelessWidget {
  const _RecipePlaceholder({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant_menu,
        size: 28,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      leading: UserAvatar(
        fullName: user.fullName,
        profilePictureUrl: user.profilePicture,
        size: 48,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.fullName,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!user.isPublic) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.lock_outline,
              size: 14,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          if (user.followersCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${_formatCount(user.followersCount)} follower${user.followersCount == 1 ? '' : 's'}',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      onTap: () => context.push('/user/${user.id}'),
    );
  }
}

// ── Kitchen Tile ────────────────────────────────────────────────────────────

class _KitchenTile extends StatelessWidget {
  const _KitchenTile({required this.kitchen});

  final SearchKitchen kitchen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer,
          borderRadius: AppTheme.borderRadiusSmall,
        ),
        clipBehavior: Clip.antiAlias,
        child: kitchen.photo != null
            ? CachedNetworkImage(
                imageUrl: kitchen.photo!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Icon(
                  Icons.kitchen,
                  color: context.colorScheme.onPrimaryContainer,
                ),
              )
            : Icon(
                Icons.kitchen,
                color: context.colorScheme.onPrimaryContainer,
              ),
      ),
      title: Text(
        kitchen.name,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${kitchen.memberCount} member${kitchen.memberCount == 1 ? '' : 's'} · Led by ${kitchen.leadName}',
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      onTap: () {
        // Navigate to kitchen detail (currently only supports own kitchen)
        context.push('/kitchen');
      },
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
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No results for "$query"',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Try a different spelling or fewer words.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
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
        padding: const EdgeInsets.all(AppTheme.spacingXl),
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
              'Something went wrong',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
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
