import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/error_state.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../paywall/paywall_bottom_sheet.dart';

/// Sort options for recipe lists.
enum RecipeSortOption {
  recent('Recent'),
  alphabetical('A-Z'),
  mostLiked('Most Liked'),
  mostForked('Most Forked');

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
      case RecipeSortOption.mostForked:
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => context.push('/search'),
          tooltip: 'Search',
        ),
        title: const Text('Recipe Book'),
        actions: [
          PopupMenuButton<RecipeSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort recipes',
            onSelected: (option) {
              if (mounted) setState(() => _sortOption = option);
            },
            itemBuilder: (context) => RecipeSortOption.values
                .map((option) => PopupMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          if (_sortOption == option)
                            Icon(Icons.check,
                                size: 18,
                                color: context.colorScheme.primary)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: AppTheme.spacingSm),
                          Text(option.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Recipes'),
            Tab(text: 'Liked'),
            Tab(text: 'Forked'),
          ],
          labelColor: context.colorScheme.primary,
          unselectedLabelColor: context.colorScheme.onSurfaceVariant,
          indicatorColor: context.colorScheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecipeListTab(
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
          ),
          _RecipeListTab(
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
          ),
          _RecipeListTab(
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
            emptyIcon: Icons.fork_right,
            emptyMessage: 'No forked recipes',
            emptySubMessage: 'Fork recipes to add them to your collection',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipeBookFab',
        onPressed: _onAddRecipe,
        tooltip: 'Add Recipe',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecipeListTab extends ConsumerWidget {
  const _RecipeListTab({
    required this.provider,
    required this.sortFn,
    required this.filterFn,
    required this.extractLabels,
    required this.selectedLabel,
    required this.onLabelSelected,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubMessage,
  });

  final FutureProvider<List<Recipe>> provider;
  final List<Recipe> Function(List<Recipe>) sortFn;
  final List<Recipe> Function(List<Recipe>) filterFn;
  final Set<String> Function(List<Recipe>) extractLabels;
  final String? selectedLabel;
  final ValueChanged<String> onLabelSelected;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptySubMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(provider);

    return recipesAsync.when(
      loading: () => const RecipeCardShimmerList(itemCount: 3),
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
          child: sorted.isEmpty
              ? _EmptyState(
                  icon: emptyIcon,
                  message: emptyMessage,
                  subMessage: emptySubMessage,
                  labels: labels,
                  selectedLabel: selectedLabel,
                  onLabelSelected: onLabelSelected,
                )
              : CustomScrollView(
                  slivers: [
                    if (labels.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _LabelChips(
                          labels: labels,
                          selectedLabel: selectedLabel,
                          onLabelSelected: onLabelSelected,
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppTheme.spacingMd),
                            child: RecipeCard(recipe: sorted[index]),
                          ),
                          childCount: sorted.length,
                        ),
                      ),
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
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: labels.map((label) {
            final isSelected = selectedLabel == label;
            return Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingSm),
              child: FilterChip(
                label: Text(label),
                selected: isSelected,
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
    return ListView(
      children: [
        if (labels.isNotEmpty)
          _LabelChips(
            labels: labels,
            selectedLabel: selectedLabel,
            onLabelSelected: onLabelSelected,
          ),
        SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color:
                      context.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  message,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  subMessage,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
