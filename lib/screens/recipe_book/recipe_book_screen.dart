import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/app_help_content.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/error_state.dart';
import '../../widgets/recipe_compact_row.dart';
import '../../widgets/shimmer_loading.dart';
import 'import_recipe_sheet.dart';
import '../paywall/paywall_bottom_sheet.dart';

/// Sort options for recipe lists.
enum RecipeSortOption {
  recent('Recent'),
  alphabetical('A-Z'),
  mostLiked('Most Liked'),
  mostRemixed('Most Remixed');

  const RecipeSortOption(this.label);
  final String label;
}

/// Recipe Book screen (Tab 3) with three sub-tabs:
/// My Recipes, Liked, and Forked.
class RecipeBookScreen extends ConsumerStatefulWidget {
  const RecipeBookScreen({super.key});

  @override
  ConsumerState<RecipeBookScreen> createState() => _RecipeBookScreenState();
}

class _RecipeBookScreenState extends ConsumerState<RecipeBookScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  RecipeSortOption _sortOption = RecipeSortOption.recent;
  String? _selectedLabel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Recipe> _sortRecipes(List<Recipe> recipes) {
    final sorted = List<Recipe>.from(recipes);
    switch (_sortOption) {
      case RecipeSortOption.recent:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case RecipeSortOption.alphabetical:
        sorted.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case RecipeSortOption.mostLiked:
        sorted.sort((a, b) => b.likesCount.compareTo(a.likesCount));
      case RecipeSortOption.mostRemixed:
        sorted.sort((a, b) => b.forksCount.compareTo(a.forksCount));
    }
    return sorted;
  }

  List<Recipe> _filterByLabel(List<Recipe> recipes) {
    if (_selectedLabel == null) return recipes;
    return recipes
        .where((r) =>
            r.labels.any((l) => l.toLowerCase() == _selectedLabel!.toLowerCase()))
        .toList();
  }

  Set<String> _extractLabels(List<Recipe> recipes) {
    final labels = <String>{};
    for (final recipe in recipes) {
      labels.addAll(recipe.labels);
    }
    return labels;
  }

  void _onAddRecipe() {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final myRecipes = ref.read(myRecipesProvider).valueOrNull ?? [];

    // Free tier: 10 recipe limit.
    if (currentUser != null &&
        !currentUser.isPremium &&
        myRecipes.length >= 10) {
      PaywallBottomSheet.show(
        context,
        reason: PaywallReason.recipeLimitReached,
      );
      return;
    }

    context.push('/recipes/create');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        leading: IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
          tooltip: 'Search',
        ),
        title: Text(
          'Recipes',
          style: AppTheme.displayTitleMedium(),
        ),
        actions: [
          const NotificationBellIcon(),
          const ProfileShortcutIcon(),
          MainTabMoreButton(
            topic: AppHelpTopic.recipes,
            primaryActionLabel: 'Import recipe',
            primaryActionIcon: Icons.download_outlined,
            onPrimaryAction: () => ImportRecipeSheet.show(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing8,
                0,
                AppTheme.spacing8,
                AppTheme.spacing8,
              ),
              indicator: BoxDecoration(
                color: AppTheme.accentPlayful.withValues(alpha: 0.14),
                borderRadius: AppTheme.borderRadiusFull,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppTheme.textPrimaryDeep,
              unselectedLabelColor: AppTheme.gray500,
              tabs: const [
                Tab(text: 'My Recipes'),
                Tab(text: 'Liked'),
                Tab(text: 'Remixed'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecipeListTab(
            title: 'My recipes',
            subtitle:
                'These are the recipes you created. Browse everyone else\'s recipes from Home or Search.',
            provider: myRecipesProvider,
            sortFn: _sortRecipes,
            filterFn: _filterByLabel,
            extractLabels: _extractLabels,
            selectedLabel: _selectedLabel,
            onLabelSelected: (label) {
              if (mounted) {
                setState(() {
                  _selectedLabel = _selectedLabel == label ? null : label;
                });
              }
            },
            emptyIcon: Icons.restaurant_menu,
            emptyMessage: 'No recipes yet',
            emptySubMessage: 'Tap + to create your first recipe',
            sortOption: _sortOption,
            onSortSelected: (option) {
              if (mounted) setState(() => _sortOption = option);
            },
            showAuthor: false,
            showVisibilityBadge: true,
          ),
          _RecipeListTab(
            title: 'Saved inspiration',
            subtitle: 'Recipes you loved enough to keep close.',
            provider: likedRecipesProvider,
            sortFn: _sortRecipes,
            filterFn: _filterByLabel,
            extractLabels: _extractLabels,
            selectedLabel: _selectedLabel,
            onLabelSelected: (label) {
              if (mounted) {
                setState(() {
                  _selectedLabel = _selectedLabel == label ? null : label;
                });
              }
            },
            emptyIcon: Icons.favorite_outline,
            emptyMessage: 'No liked recipes',
            emptySubMessage: 'Like recipes to see them here',
            sortOption: _sortOption,
            onSortSelected: (option) {
              if (mounted) setState(() => _sortOption = option);
            },
          ),
          _RecipeListTab(
            title: 'Remixed and personalized',
            subtitle: 'Your adaptations, experiments, and second takes.',
            provider: forkedRecipesProvider,
            sortFn: _sortRecipes,
            filterFn: _filterByLabel,
            extractLabels: _extractLabels,
            selectedLabel: _selectedLabel,
            onLabelSelected: (label) {
              if (mounted) {
                setState(() {
                  _selectedLabel = _selectedLabel == label ? null : label;
                });
              }
            },
            emptyIcon: Icons.refresh_outlined,
            emptyMessage: 'No remixed recipes',
            emptySubMessage: 'Remix recipes to make them your own',
            sortOption: _sortOption,
            onSortSelected: (option) {
              if (mounted) setState(() => _sortOption = option);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'recipeBookFab',
        onPressed: _onAddRecipe,
        tooltip: 'Add Recipe',
        backgroundColor: AppTheme.accentPlayful,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Recipe'),
      ),
    );
  }
}

class _RecipeListTab extends ConsumerWidget {
  const _RecipeListTab({
    required this.title,
    required this.subtitle,
    required this.provider,
    required this.sortFn,
    required this.filterFn,
    required this.extractLabels,
    required this.selectedLabel,
    required this.onLabelSelected,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubMessage,
    required this.sortOption,
    required this.onSortSelected,
    this.showAuthor = true,
    this.showVisibilityBadge = false,
  });

  final String title;
  final String subtitle;
  final FutureProvider<List<Recipe>> provider;
  final List<Recipe> Function(List<Recipe>) sortFn;
  final List<Recipe> Function(List<Recipe>) filterFn;
  final Set<String> Function(List<Recipe>) extractLabels;
  final String? selectedLabel;
  final ValueChanged<String> onLabelSelected;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptySubMessage;
  final RecipeSortOption sortOption;
  final ValueChanged<RecipeSortOption> onSortSelected;
  final bool showAuthor;
  final bool showVisibilityBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(provider);

    return recipesAsync.when(
      loading: () => const _RecipeBookLoadingState(),
      error: (error, _) => ErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (recipes) {
        final labels = extractLabels(recipes);
        final filtered = filterFn(recipes);
        final sorted = sortFn(filtered);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(provider);
            await ref.read(provider.future);
          },
          color: AppTheme.accentPlayful,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _CollectionSummaryCard(
                  title: title,
                  subtitle: subtitle,
                  totalCount: sorted.length,
                  sortLabel: sortOption.label,
                  selectedSort: sortOption,
                  onSortSelected: onSortSelected,
                ),
              ),
              if (labels.isNotEmpty)
                SliverToBoxAdapter(
                  child: _LabelChips(
                    labels: labels,
                    selectedLabel: selectedLabel,
                    onLabelSelected: onLabelSelected,
                  ),
                ),
              if (sorted.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: emptyIcon,
                    message: emptyMessage,
                    subMessage: emptySubMessage,
                    labels: labels,
                    selectedLabel: selectedLabel,
                    onLabelSelected: onLabelSelected,
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => RecipeCompactRow(
                      recipe: sorted[index],
                      showChevron: true,
                      showAuthor: showAuthor,
                      showVisibilityBadge: showVisibilityBadge,
                    ),
                    childCount: sorted.length,
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacing32),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LabelChips extends StatelessWidget {
  const _LabelChips({
    required this.labels,
    required this.selectedLabel,
    required this.onLabelSelected,
  });

  final Set<String> labels;
  final String? selectedLabel;
  final ValueChanged<String> onLabelSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: labels.map((label) {
            final isSelected = selectedLabel == label;
            return Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacing8),
              child: FilterChip(
                label: Text(label),
                selected: isSelected,
                backgroundColor: AppTheme.surfaceElevated,
                selectedColor: AppTheme.accentPlayfulLight,
                labelStyle: TextStyle(
                  color:
                      isSelected ? AppTheme.accentPlayful : AppTheme.gray700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.accentPlayful.withValues(alpha: 0.28)
                      : AppTheme.gray200,
                ),
                onSelected: (_) => onLabelSelected(label),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subMessage,
    required this.labels,
    required this.selectedLabel,
    required this.onLabelSelected,
  });

  final IconData icon;
  final String message;
  final String subMessage;
  final Set<String> labels;
  final String? selectedLabel;
  final ValueChanged<String> onLabelSelected;

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
                icon,
                size: 30,
                color: AppTheme.accentPlayful.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              message,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryDeep,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              subMessage,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            if (labels.isNotEmpty && selectedLabel != null) ...[
              const SizedBox(height: AppTheme.spacing12),
              TextButton(
                onPressed: () => onLabelSelected(selectedLabel!),
                child: const Text('Clear filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectionSummaryCard extends StatelessWidget {
  const _CollectionSummaryCard({
    required this.title,
    required this.subtitle,
    required this.totalCount,
    required this.sortLabel,
    required this.selectedSort,
    required this.onSortSelected,
  });

  final String title;
  final String subtitle;
  final int totalCount;
  final String sortLabel;
  final RecipeSortOption selectedSort;
  final ValueChanged<RecipeSortOption> onSortSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowSm,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppTheme.accentPlayfulLight.withValues(alpha: 0.72),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: context.textTheme.labelMedium?.copyWith(
                color: AppTheme.accentPlayful,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              '$totalCount recipe${totalCount == 1 ? '' : 's'}',
              style: AppTheme.displayTitleSmall(),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              subtitle,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing8,
              children: [
                _SummaryMetaItem(
                  icon: Icons.tune_rounded,
                  label: 'Sorted by $sortLabel',
                ),
                const _SummaryMetaItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Focused browsing',
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Sort recipes',
              style: context.textTheme.labelMedium?.copyWith(
                color: AppTheme.gray600,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: RecipeSortOption.values.map((option) {
                  final isSelected = option == selectedSort;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppTheme.spacing8),
                    child: ChoiceChip(
                      label: Text(option.label),
                      selected: isSelected,
                      backgroundColor: AppTheme.surfaceWarm,
                      selectedColor: AppTheme.accentPlayfulLight,
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.accentPlayful.withValues(alpha: 0.3)
                            : AppTheme.gray200,
                      ),
                      labelStyle: context.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? AppTheme.accentPlayful
                            : AppTheme.gray600,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => onSortSelected(option),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetaItem extends StatelessWidget {
  const _SummaryMetaItem({
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

class _RecipeBookLoadingState extends StatelessWidget {
  const _RecipeBookLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppTheme.spacing12),
      children: const [
        _CollectionSummaryCard(
          title: 'Loading collection',
          subtitle: 'Gathering your recipes and organizing the library.',
          totalCount: 0,
          sortLabel: 'Recent',
          selectedSort: RecipeSortOption.recent,
          onSortSelected: _noopSortChange,
        ),
        RecipeCompactRowShimmer(gradientValue: 0.25),
        RecipeCompactRowShimmer(gradientValue: 0.5),
        RecipeCompactRowShimmer(gradientValue: 0.75),
      ],
    );
  }
}

void _noopSortChange(RecipeSortOption _) {}
