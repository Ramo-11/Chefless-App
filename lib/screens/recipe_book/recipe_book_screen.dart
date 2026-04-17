import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cached_network_image/cached_network_image.dart';

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
import '../../widgets/recipe_compact_row.dart';
import '../../widgets/shimmer_loading.dart';
import 'import_recipe_sheet.dart';
import '../paywall/paywall_bottom_sheet.dart';

enum _MyRecipesView { recipes, cookbooks }

/// Sort options for recipe lists.
enum RecipeSortOption {
  recent('Recent'),
  alphabetical('A-Z'),
  mostLiked('Most Liked'),
  mostRemixed('Most Remixed'),
  quickest('Quickest'),
  longest('Longest');

  const RecipeSortOption(this.label);
  final String label;
}

/// Recipe Book screen (Tab 3) with three sub-tabs:
/// My Recipes, Liked, and Remixed.
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
  String? _selectedDietary;
  String? _selectedCuisine;
  int? _maxCookTimeMinutes;
  _MyRecipesView _myRecipesView = _MyRecipesView.recipes;

  bool get _hasActiveFilters =>
      _selectedLabel != null ||
      _selectedDietary != null ||
      _selectedCuisine != null ||
      _maxCookTimeMinutes != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
      case RecipeSortOption.quickest:
        sorted.sort((a, b) =>
            (a.totalTime ?? a.cookTime ?? 9999)
                .compareTo(b.totalTime ?? b.cookTime ?? 9999));
      case RecipeSortOption.longest:
        sorted.sort((a, b) =>
            (b.totalTime ?? b.cookTime ?? 0)
                .compareTo(a.totalTime ?? a.cookTime ?? 0));
    }
    return sorted;
  }

  List<Recipe> _applyFilters(List<Recipe> recipes) {
    var list = recipes;
    if (_selectedLabel != null) {
      list = list
          .where((r) => r.labels
              .any((l) => l.toLowerCase() == _selectedLabel!.toLowerCase()))
          .toList();
    }
    if (_selectedDietary != null) {
      list = list
          .where((r) => r.dietaryTags.any(
              (t) => t.toLowerCase() == _selectedDietary!.toLowerCase()))
          .toList();
    }
    if (_selectedCuisine != null) {
      list = list
          .where((r) => r.cuisineTags.any(
              (t) => t.toLowerCase() == _selectedCuisine!.toLowerCase()))
          .toList();
    }
    if (_maxCookTimeMinutes != null) {
      list = list
          .where((r) =>
              (r.totalTime ?? r.cookTime ?? 0) <= _maxCookTimeMinutes!)
          .toList();
    }
    return list;
  }

  Set<String> _extractLabels(List<Recipe> recipes) {
    final labels = <String>{};
    for (final recipe in recipes) {
      labels.addAll(recipe.labels);
    }
    return labels;
  }

  Set<String> _extractDietaryTags(List<Recipe> recipes) {
    final tags = <String>{};
    for (final recipe in recipes) {
      tags.addAll(recipe.dietaryTags);
    }
    return tags;
  }

  Set<String> _extractCuisineTags(List<Recipe> recipes) {
    final tags = <String>{};
    for (final recipe in recipes) {
      tags.addAll(recipe.cuisineTags);
    }
    return tags;
  }

  Widget _buildPrimaryFab() {
    final showCookbookFab = _tabController.index == 0 &&
        _myRecipesView == _MyRecipesView.cookbooks &&
        !_hasActiveFilters;
    return FloatingActionButton.extended(
      heroTag: 'recipeBookFab',
      onPressed: () {
        HapticFeedback.lightImpact();
        if (showCookbookFab) {
          context.push('/cookbook/new');
        } else {
          _onAddRecipe();
        }
      },
      tooltip: showCookbookFab ? 'New cookbook' : 'New recipe',
      backgroundColor: AppTheme.accentPlayful,
      foregroundColor: Colors.white,
      elevation: 6,
      highlightElevation: 2,
      extendedTextStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        fontSize: 15,
      ),
      icon: const Icon(Icons.add_rounded, size: 22),
      label: Text(showCookbookFab ? 'New Cookbook' : 'New Recipe'),
    );
  }

  void _onAddRecipe() {
    final currentUser = ref.read(currentUserProvider).valueOrNull;

    if (currentUser != null &&
        !currentUser.isPremiumActive &&
        currentUser.originalRecipesCount >= 10) {
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
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final showQuotaBar = _tabController.index == 0 &&
        currentUser != null &&
        !currentUser.isPremiumActive;

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
          preferredSize: Size.fromHeight(showQuotaBar ? 84 : 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
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
                    color: AppTheme.accentPlayful,
                    borderRadius: AppTheme.borderRadiusFull,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPlayful.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.gray600,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  onTap: (_) => HapticFeedback.selectionClick(),
                  tabs: const [
                    Tab(text: 'My Recipes'),
                    Tab(text: 'Liked'),
                    Tab(text: 'Saved'),
                    Tab(text: 'Remixed'),
                  ],
                ),
              ),
              if (showQuotaBar) const _OriginalRecipeQuotaBar(),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyRecipesTab(
            view: _myRecipesView,
            hasActiveFilters: _hasActiveFilters,
            onViewChanged: (view) {
              if (mounted) setState(() => _myRecipesView = view);
            },
            recipesTab: _RecipeListTab(
              title: 'My recipes',
              subtitle:
                  'These are the recipes you created. Browse everyone else\'s recipes from Home or Search.',
              provider: myRecipesProvider,
              onRefresh: (ref) =>
                  ref.read(myRecipesProvider.notifier).refresh(),
              sortFn: _sortRecipes,
              filterFn: _applyFilters,
              extractLabels: _extractLabels,
              extractDietaryTags: _extractDietaryTags,
              extractCuisineTags: _extractCuisineTags,
              selectedLabel: _selectedLabel,
              selectedDietary: _selectedDietary,
              selectedCuisine: _selectedCuisine,
              onLabelSelected: (label) {
                if (mounted) {
                  setState(() {
                    _selectedLabel = label;
                    _myRecipesView = _MyRecipesView.recipes;
                  });
                }
              },
              onDietarySelected: (tag) {
                if (mounted) {
                  setState(() {
                    _selectedDietary = tag;
                    _myRecipesView = _MyRecipesView.recipes;
                  });
                }
              },
              onCuisineSelected: (tag) {
                if (mounted) {
                  setState(() {
                    _selectedCuisine = tag;
                    _myRecipesView = _MyRecipesView.recipes;
                  });
                }
              },
              onClearFilters: () {
                if (mounted) {
                  setState(() {
                    _selectedLabel = null;
                    _selectedDietary = null;
                    _selectedCuisine = null;
                    _maxCookTimeMinutes = null;
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
              maxCookTimeMinutes: _maxCookTimeMinutes,
              onCookTimeChanged: (v) {
                if (mounted) setState(() => _maxCookTimeMinutes = v);
              },
              showAuthor: false,
              showVisibilityBadge: true,
            ),
          ),
          _RecipeListTab(
            title: 'Liked recipes',
            subtitle: 'Recipes you tapped a heart on.',
            provider: likedRecipesProvider,
            onRefresh: (ref) async {
              ref.invalidate(likedRecipesProvider);
              await ref.read(likedRecipesProvider.future);
            },
            sortFn: _sortRecipes,
            filterFn: _applyFilters,
            extractLabels: _extractLabels,
            extractDietaryTags: _extractDietaryTags,
            extractCuisineTags: _extractCuisineTags,
            selectedLabel: _selectedLabel,
            selectedDietary: _selectedDietary,
            selectedCuisine: _selectedCuisine,
            onLabelSelected: (label) {
              if (mounted) {
                setState(() {
                  _selectedLabel = label;
                });
              }
            },
            onDietarySelected: (tag) {
              if (mounted) {
                setState(() {
                  _selectedDietary = tag;
                });
              }
            },
            onCuisineSelected: (tag) {
              if (mounted) {
                setState(() {
                  _selectedCuisine = tag;
                });
              }
            },
            onClearFilters: () {
              if (mounted) {
                setState(() {
                  _selectedLabel = null;
                  _selectedDietary = null;
                  _selectedCuisine = null;
                  _maxCookTimeMinutes = null;
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
            maxCookTimeMinutes: _maxCookTimeMinutes,
            onCookTimeChanged: (v) {
              if (mounted) setState(() => _maxCookTimeMinutes = v);
            },
          ),
          _RecipeListTab(
            title: 'Saved for later',
            subtitle: 'Recipes you bookmarked to come back to.',
            provider: savedRecipesProvider,
            onRefresh: (ref) async {
              ref.invalidate(savedRecipesProvider);
              await ref.read(savedRecipesProvider.future);
            },
            sortFn: _sortRecipes,
            filterFn: _applyFilters,
            extractLabels: _extractLabels,
            extractDietaryTags: _extractDietaryTags,
            extractCuisineTags: _extractCuisineTags,
            selectedLabel: _selectedLabel,
            selectedDietary: _selectedDietary,
            selectedCuisine: _selectedCuisine,
            onLabelSelected: (label) {
              if (mounted) {
                setState(() {
                  _selectedLabel = label;
                });
              }
            },
            onDietarySelected: (tag) {
              if (mounted) {
                setState(() {
                  _selectedDietary = tag;
                });
              }
            },
            onCuisineSelected: (tag) {
              if (mounted) {
                setState(() {
                  _selectedCuisine = tag;
                });
              }
            },
            onClearFilters: () {
              if (mounted) {
                setState(() {
                  _selectedLabel = null;
                  _selectedDietary = null;
                  _selectedCuisine = null;
                  _maxCookTimeMinutes = null;
                });
              }
            },
            emptyIcon: Icons.bookmark_outline_rounded,
            emptyMessage: 'No saved recipes',
            emptySubMessage: 'Tap save on any recipe to keep it here',
            sortOption: _sortOption,
            onSortSelected: (option) {
              if (mounted) setState(() => _sortOption = option);
            },
            maxCookTimeMinutes: _maxCookTimeMinutes,
            onCookTimeChanged: (v) {
              if (mounted) setState(() => _maxCookTimeMinutes = v);
            },
          ),
          _RecipeListTab(
            title: 'Remixed and personalized',
            subtitle: 'Your adaptations, experiments, and second takes.',
            provider: forkedRecipesProvider,
            onRefresh: (ref) async {
              ref.invalidate(forkedRecipesProvider);
              await ref.read(forkedRecipesProvider.future);
            },
            sortFn: _sortRecipes,
            filterFn: _applyFilters,
            extractLabels: _extractLabels,
            extractDietaryTags: _extractDietaryTags,
            extractCuisineTags: _extractCuisineTags,
            selectedLabel: _selectedLabel,
            selectedDietary: _selectedDietary,
            selectedCuisine: _selectedCuisine,
            onLabelSelected: (label) {
              if (mounted) {
                setState(() {
                  _selectedLabel = label;
                });
              }
            },
            onDietarySelected: (tag) {
              if (mounted) {
                setState(() {
                  _selectedDietary = tag;
                });
              }
            },
            onCuisineSelected: (tag) {
              if (mounted) {
                setState(() {
                  _selectedCuisine = tag;
                });
              }
            },
            onClearFilters: () {
              if (mounted) {
                setState(() {
                  _selectedLabel = null;
                  _selectedDietary = null;
                  _selectedCuisine = null;
                  _maxCookTimeMinutes = null;
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
            maxCookTimeMinutes: _maxCookTimeMinutes,
            onCookTimeChanged: (v) {
              if (mounted) setState(() => _maxCookTimeMinutes = v);
            },
          ),
        ],
      ),
      floatingActionButton: _buildPrimaryFab(),
    );
  }
}

class _RecipeListTab extends ConsumerWidget {
  const _RecipeListTab({
    required this.title,
    required this.subtitle,
    required this.provider,
    required this.onRefresh,
    required this.sortFn,
    required this.filterFn,
    required this.extractLabels,
    required this.extractDietaryTags,
    required this.extractCuisineTags,
    required this.selectedLabel,
    required this.selectedDietary,
    required this.selectedCuisine,
    required this.onLabelSelected,
    required this.onDietarySelected,
    required this.onCuisineSelected,
    required this.onClearFilters,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubMessage,
    required this.sortOption,
    required this.onSortSelected,
    this.maxCookTimeMinutes,
    this.onCookTimeChanged,
    this.showAuthor = true,
    this.showVisibilityBadge = false,
  });

  final String title;
  final String subtitle;
  final ProviderListenable<AsyncValue<List<Recipe>>> provider;
  final Future<void> Function(WidgetRef ref) onRefresh;
  final List<Recipe> Function(List<Recipe>) sortFn;
  final List<Recipe> Function(List<Recipe>) filterFn;
  final Set<String> Function(List<Recipe>) extractLabels;
  final Set<String> Function(List<Recipe>) extractDietaryTags;
  final Set<String> Function(List<Recipe>) extractCuisineTags;
  final String? selectedLabel;
  final String? selectedDietary;
  final String? selectedCuisine;
  final ValueChanged<String?> onLabelSelected;
  final ValueChanged<String?> onDietarySelected;
  final ValueChanged<String?> onCuisineSelected;
  final VoidCallback onClearFilters;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptySubMessage;
  final RecipeSortOption sortOption;
  final ValueChanged<RecipeSortOption> onSortSelected;
  final int? maxCookTimeMinutes;
  final ValueChanged<int?>? onCookTimeChanged;
  final bool showAuthor;
  final bool showVisibilityBadge;

  int get _activeFilterCount {
    var count = 0;
    if (selectedLabel != null) count++;
    if (selectedDietary != null) count++;
    if (selectedCuisine != null) count++;
    if (maxCookTimeMinutes != null) count++;
    return count;
  }

  bool _canFilter(
    Set<String> labels,
    Set<String> dietaryTags,
    Set<String> cuisineTags,
  ) {
    return onCookTimeChanged != null ||
        labels.isNotEmpty ||
        dietaryTags.isNotEmpty ||
        cuisineTags.isNotEmpty;
  }

  Future<void> _openFilterSheet(
    BuildContext context, {
    required Set<String> labels,
    required Set<String> dietaryTags,
    required Set<String> cuisineTags,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return _FilterBottomSheet(
          labels: labels,
          dietaryTags: dietaryTags,
          cuisineTags: cuisineTags,
          initialLabel: selectedLabel,
          initialDietary: selectedDietary,
          initialCuisine: selectedCuisine,
          initialMaxCookTimeMinutes: maxCookTimeMinutes,
          showCookTime: onCookTimeChanged != null,
          onApply: ({
            required String? label,
            required String? dietary,
            required String? cuisine,
            required int? maxCookTimeMinutes,
          }) {
            if (label != selectedLabel) onLabelSelected(label);
            if (dietary != selectedDietary) onDietarySelected(dietary);
            if (cuisine != selectedCuisine) onCuisineSelected(cuisine);
            if (onCookTimeChanged != null &&
                maxCookTimeMinutes != this.maxCookTimeMinutes) {
              onCookTimeChanged!(maxCookTimeMinutes);
            }
          },
          onClearAll: onClearFilters,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(provider);

    return recipesAsync.when(
      loading: () => const _RecipeBookLoadingState(),
      error: (error, _) => ErrorState(
        message: error.toString(),
        onRetry: () => onRefresh(ref),
      ),
      data: (recipes) {
        final labels = extractLabels(recipes);
        final dietaryTags = extractDietaryTags(recipes);
        final cuisineTags = extractCuisineTags(recipes);
        final filtered = filterFn(recipes);
        final sorted = sortFn(filtered);
        final hasActiveFilters = selectedLabel != null ||
            selectedDietary != null ||
            selectedCuisine != null ||
            maxCookTimeMinutes != null;

        return RefreshIndicator(
          onRefresh: () => onRefresh(ref),
          color: AppTheme.accentPlayful,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _CollectionSummaryCard(
                  title: title,
                  subtitle: subtitle,
                  totalCount: sorted.length,
                  selectedSort: sortOption,
                  onSortSelected: onSortSelected,
                ),
              ),
              if (_canFilter(labels, dietaryTags, cuisineTags))
                SliverToBoxAdapter(
                  child: _FilterBar(
                    activeCount: _activeFilterCount,
                    hasActiveFilters: hasActiveFilters,
                    onOpenFilters: () => _openFilterSheet(
                      context,
                      labels: labels,
                      dietaryTags: dietaryTags,
                      cuisineTags: cuisineTags,
                    ),
                    onClearFilters: onClearFilters,
                  ),
                ),
              if (sorted.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: emptyIcon,
                    message: emptyMessage,
                    subMessage: emptySubMessage,
                    showClearFilters: hasActiveFilters,
                    onClearFilters: onClearFilters,
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

/// Cook time options shared between the filter sheet and any future UI.
class _CookTimeOption {
  const _CookTimeOption({required this.label, required this.value});
  final String label;
  final int value;
}

const List<_CookTimeOption> _cookTimeOptions = <_CookTimeOption>[
  _CookTimeOption(label: '≤15 min', value: 15),
  _CookTimeOption(label: '≤30 min', value: 30),
  _CookTimeOption(label: '≤60 min', value: 60),
  _CookTimeOption(label: '≤2 hrs', value: 120),
];

/// Compact row that sits above the recipe list, exposing a Filter button
/// (with optional active-count badge) and an inline Clear shortcut.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeCount,
    required this.hasActiveFilters,
    required this.onOpenFilters,
    required this.onClearFilters,
  });

  final int activeCount;
  final bool hasActiveFilters;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final label = hasActiveFilters ? 'Filter · $activeCount' : 'Filter';
    final fg = hasActiveFilters ? AppTheme.accentPlayful : AppTheme.gray800;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Filter recipes',
            child: Material(
              color: hasActiveFilters
                  ? AppTheme.accentPlayfulLight
                  : Colors.transparent,
              borderRadius: AppTheme.borderRadiusFull,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpenFilters();
                },
                borderRadius: AppTheme.borderRadiusFull,
                splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
                highlightColor:
                    AppTheme.accentPlayful.withValues(alpha: 0.04),
                mouseCursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing14,
                    vertical: AppTheme.spacing8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.borderRadiusFull,
                    border: hasActiveFilters
                        ? null
                        : Border.all(color: AppTheme.gray200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 17, color: fg),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        label,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: AppTheme.spacing8),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onClearFilters();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.gray600,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing8,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }
}

String _titleCase(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  // Preserve quantitative labels like "≤15 min" unchanged.
  if (trimmed.startsWith(RegExp(r'[^a-zA-Z]'))) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Chip group used inside the filter sheet. Single-select (tapping the active
/// chip clears it). Selected chips are filled with the accent colour for a
/// clear, high-contrast state.
class _FilterChipGroup extends StatelessWidget {
  const _FilterChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            color: AppTheme.textPrimaryDeep,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        Wrap(
          spacing: AppTheme.spacing8,
          runSpacing: AppTheme.spacing8,
          children: options.map((option) {
            final isSelected = selected == option;
            return InkWell(
              borderRadius: AppTheme.borderRadiusFull,
              onTap: () => onSelected(isSelected ? null : option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentPlayful
                      : AppTheme.surfaceElevated,
                  borderRadius: AppTheme.borderRadiusFull,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentPlayful
                        : AppTheme.gray200,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                    ],
                    Text(
                      _titleCase(option),
                      style: context.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.gray800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

typedef _FilterApplyCallback = void Function({
  required String? label,
  required String? dietary,
  required String? cuisine,
  required int? maxCookTimeMinutes,
});

/// Bottom sheet that consolidates all recipe filters (Cook Time, Labels,
/// Dietary, Cuisine) behind a single entry point. Uses local state until
/// the user taps Apply.
class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({
    required this.labels,
    required this.dietaryTags,
    required this.cuisineTags,
    required this.initialLabel,
    required this.initialDietary,
    required this.initialCuisine,
    required this.initialMaxCookTimeMinutes,
    required this.showCookTime,
    required this.onApply,
    required this.onClearAll,
  });

  final Set<String> labels;
  final Set<String> dietaryTags;
  final Set<String> cuisineTags;
  final String? initialLabel;
  final String? initialDietary;
  final String? initialCuisine;
  final int? initialMaxCookTimeMinutes;
  final bool showCookTime;
  final _FilterApplyCallback onApply;
  final VoidCallback onClearAll;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String? _label = widget.initialLabel;
  late String? _dietary = widget.initialDietary;
  late String? _cuisine = widget.initialCuisine;
  late int? _maxCookTimeMinutes = widget.initialMaxCookTimeMinutes;

  bool get _hasAnySelected =>
      _label != null ||
      _dietary != null ||
      _cuisine != null ||
      _maxCookTimeMinutes != null;

  int _activeSelectionCount() {
    var count = 0;
    if (_label != null) count++;
    if (_dietary != null) count++;
    if (_cuisine != null) count++;
    if (_maxCookTimeMinutes != null) count++;
    return count;
  }

  void _clearLocal() {
    setState(() {
      _label = null;
      _dietary = null;
      _cuisine = null;
      _maxCookTimeMinutes = null;
    });
  }

  void _apply() {
    widget.onApply(
      label: _label,
      dietary: _dietary,
      cuisine: _cuisine,
      maxCookTimeMinutes: _maxCookTimeMinutes,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels.toList()..sort();
    final dietary = widget.dietaryTags.toList()..sort();
    final cuisines = widget.cuisineTags.toList()..sort();
    final mediaQuery = MediaQuery.of(context);
    final maxSheetHeight = mediaQuery.size.height * 0.85;

    final sections = <Widget>[];
    if (widget.showCookTime) {
      sections.add(_FilterChipGroup(
        title: 'Cook time',
        options:
            _cookTimeOptions.map((o) => o.label).toList(growable: false),
        selected: _labelForCookTime(_maxCookTimeMinutes),
        onSelected: (label) {
          setState(() {
            _maxCookTimeMinutes = _valueForCookTimeLabel(label);
          });
        },
      ));
    }
    if (labels.isNotEmpty) {
      sections.add(_FilterChipGroup(
        title: 'Labels',
        options: labels,
        selected: _label,
        onSelected: (value) => setState(() => _label = value),
      ));
    }
    if (dietary.isNotEmpty) {
      sections.add(_FilterChipGroup(
        title: 'Dietary',
        options: dietary,
        selected: _dietary,
        onSelected: (value) => setState(() => _dietary = value),
      ));
    }
    if (cuisines.isNotEmpty) {
      sections.add(_FilterChipGroup(
        title: 'Cuisine',
        options: cuisines,
        selected: _cuisine,
        onSelected: (value) => setState(() => _cuisine = value),
      ));
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header — the drag handle is rendered by the framework via
            // `showDragHandle: true` on showModalBottomSheet, so none is
            // drawn here (a second one would duplicate it).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing20,
                AppTheme.spacing4,
                AppTheme.spacing12,
                AppTheme.spacing8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter recipes',
                            style: context.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryDeep,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing2),
                          Text(
                            _hasAnySelected
                                ? '${_activeSelectionCount()} filter${_activeSelectionCount() == 1 ? '' : 's'} applied'
                                : 'Narrow down the list',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppTheme.gray500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.gray600,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing20,
                  AppTheme.spacing4,
                  AppTheme.spacing20,
                  AppTheme.spacing20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < sections.length; i++) ...[
                      sections[i],
                      if (i < sections.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacing20,
                          ),
                          child: Divider(
                            height: 1,
                            color: AppTheme.gray100,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.gray100),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing12,
                AppTheme.spacing16,
                AppTheme.spacing16,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _hasAnySelected ? _clearLocal : null,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 18,
                        ),
                        label: const Text('Clear all'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _hasAnySelected
                              ? AppTheme.gray800
                              : AppTheme.gray400,
                          side: BorderSide(
                            color: _hasAnySelected
                                ? AppTheme.gray300
                                : AppTheme.gray200,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacing12,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusFull,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _apply,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accentPlayful,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacing12,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusFull,
                          ),
                          textStyle: context.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        child: Text(
                          _hasAnySelected
                              ? 'Show results'
                              : 'Apply',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _labelForCookTime(int? value) {
    if (value == null) return null;
    for (final opt in _cookTimeOptions) {
      if (opt.value == value) return opt.label;
    }
    return null;
  }

  static int? _valueForCookTimeLabel(String? label) {
    if (label == null) return null;
    for (final opt in _cookTimeOptions) {
      if (opt.label == label) return opt.value;
    }
    return null;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subMessage,
    required this.showClearFilters,
    required this.onClearFilters,
  });

  final IconData icon;
  final String message;
  final String subMessage;
  final bool showClearFilters;
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
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppTheme.gray500),
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
            if (showClearFilters) ...[
              const SizedBox(height: AppTheme.spacing12),
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
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
    required this.selectedSort,
    required this.onSortSelected,
  });

  final String title;
  final String subtitle;
  final int totalCount;
  final RecipeSortOption selectedSort;
  final ValueChanged<RecipeSortOption> onSortSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing20,
          AppTheme.spacing20,
          AppTheme.spacing12,
          AppTheme.spacing20,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AccentPill(label: title.toUpperCase()),
                const Spacer(),
                _SortDropdown(
                  selected: selectedSort,
                  onSelected: onSortSelected,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacing8),
              child: Text(
                '$totalCount recipe${totalCount == 1 ? '' : 's'}',
                style: AppTheme.displayTitleSmall().copyWith(height: 1.1),
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacing8),
              child: Text(
                subtitle,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray500,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentPill extends StatelessWidget {
  const _AccentPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppTheme.accentPlayfulLight,
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: AppTheme.accentPlayful,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          height: 1,
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({
    required this.selected,
    required this.onSelected,
  });

  final RecipeSortOption selected;
  final ValueChanged<RecipeSortOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sort recipes',
      child: PopupMenuButton<RecipeSortOption>(
        initialValue: selected,
        tooltip: '',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        color: AppTheme.surfaceElevated,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        onSelected: (option) {
          HapticFeedback.selectionClick();
          onSelected(option);
        },
        itemBuilder: (context) => RecipeSortOption.values
            .map(
              (option) => PopupMenuItem<RecipeSortOption>(
                value: option,
                height: 40,
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: option == selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppTheme.accentPlayful,
                            )
                          : const SizedBox.shrink(),
                    ),
                    Text(
                      option.label,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: option == selected
                            ? AppTheme.accentPlayful
                            : AppTheme.textPrimaryDeep,
                        fontWeight: option == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing12,
            AppTheme.spacing6,
            AppTheme.spacing8,
            AppTheme.spacing6,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWarm,
            borderRadius: AppTheme.borderRadiusFull,
            border: Border.all(
              color: AppTheme.gray200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sort_rounded,
                size: 15,
                color: AppTheme.gray700,
              ),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                selected.label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: AppTheme.textPrimaryDeep,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppTheme.gray600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginalRecipeQuotaBar extends ConsumerWidget {
  const _OriginalRecipeQuotaBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null || user.isPremiumActive) {
      return const SizedBox.shrink();
    }
    final used = user.originalRecipesCount.clamp(0, 10);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: used / 10,
              minHeight: 6,
              backgroundColor: AppTheme.gray200,
              color: AppTheme.accentPlayful,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$used/10 original recipes · remixes are unlimited',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.gray600,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
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
        _CollectionSummaryCardShimmer(),
        RecipeCompactRowShimmer(gradientValue: 0.25),
        RecipeCompactRowShimmer(gradientValue: 0.5),
        RecipeCompactRowShimmer(gradientValue: 0.75),
      ],
    );
  }
}

class _CollectionSummaryCardShimmer extends StatelessWidget {
  const _CollectionSummaryCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowSubtle,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ShimmerBlock(width: 82, height: 18, radius: 999),
                Spacer(),
                _ShimmerBlock(width: 100, height: 28, radius: 999),
              ],
            ),
            SizedBox(height: AppTheme.spacing16),
            _ShimmerBlock(width: 140, height: 22, radius: 6),
            SizedBox(height: AppTheme.spacing8),
            _ShimmerBlock(width: double.infinity, height: 12, radius: 6),
            SizedBox(height: AppTheme.spacing6),
            _ShimmerBlock(width: 220, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Wraps the My Recipes tab with a Recipes ↔ Cookbooks segmented toggle.
/// When a filter is active the recipes view is forced (filter bypasses
/// cookbook grouping per product spec).
class _MyRecipesTab extends ConsumerWidget {
  const _MyRecipesTab({
    required this.view,
    required this.hasActiveFilters,
    required this.onViewChanged,
    required this.recipesTab,
  });

  final _MyRecipesView view;
  final bool hasActiveFilters;
  final ValueChanged<_MyRecipesView> onViewChanged;
  final Widget recipesTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveView = hasActiveFilters ? _MyRecipesView.recipes : view;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            AppTheme.spacing4,
          ),
          child: _MyRecipesSegmentedToggle(
            value: effectiveView,
            onChanged: onViewChanged,
            disabledHint: hasActiveFilters
                ? 'Clear filters to switch to cookbooks.'
                : null,
          ),
        ),
        Expanded(
          child: effectiveView == _MyRecipesView.recipes
              ? recipesTab
              : const _MyCookbooksGrid(),
        ),
      ],
    );
  }
}

class _MyRecipesSegmentedToggle extends StatelessWidget {
  const _MyRecipesSegmentedToggle({
    required this.value,
    required this.onChanged,
    this.disabledHint,
  });

  final _MyRecipesView value;
  final ValueChanged<_MyRecipesView> onChanged;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.gray100,
            borderRadius: AppTheme.borderRadiusFull,
          ),
          child: Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Recipes',
                  isSelected: value == _MyRecipesView.recipes,
                  onTap: () => onChanged(_MyRecipesView.recipes),
                ),
              ),
              Expanded(
                child: _SegmentButton(
                  icon: Icons.menu_book_rounded,
                  label: 'Cookbooks',
                  isSelected: value == _MyRecipesView.cookbooks,
                  onTap: disabledHint != null
                      ? null
                      : () => onChanged(_MyRecipesView.cookbooks),
                ),
              ),
            ],
          ),
        ),
        if (disabledHint != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacing6),
            child: Text(
              disabledHint!,
              textAlign: TextAlign.center,
              style: context.textTheme.labelSmall?.copyWith(
                color: AppTheme.gray500,
              ),
            ),
          ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? AppTheme.gray400
        : isSelected
            ? AppTheme.accentPlayful
            : AppTheme.gray600;

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      borderRadius: AppTheme.borderRadiusFull,
      splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
      highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
      mouseCursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: AppTheme.borderRadiusFull,
          boxShadow: isSelected ? AppTheme.shadowSubtle : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppTheme.spacing6),
            Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyCookbooksGrid extends ConsumerWidget {
  const _MyCookbooksGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cookbooksAsync = ref.watch(myCookbooksProvider);

    return cookbooksAsync.when(
      loading: () => const _CookbooksLoadingState(),
      error: (err, _) => ErrorState(
        message: err.toString(),
        onRetry: () => ref.invalidate(myCookbooksProvider),
      ),
      data: (cookbooks) {
        return RefreshIndicator(
          color: AppTheme.accentPlayful,
          onRefresh: () async {
            ref.invalidate(myCookbooksProvider);
            await ref.read(myCookbooksProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing12,
                  AppTheme.spacing16,
                  AppTheme.spacing16,
                ),
                sliver: SliverToBoxAdapter(
                  child: _CookbooksHeaderCard(count: cookbooks.length),
                ),
              ),
              if (cookbooks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CookbooksEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppTheme.spacing12,
                      crossAxisSpacing: AppTheme.spacing12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _CookbookGridTile(cookbook: cookbooks[index]),
                      childCount: cookbooks.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacing40),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CookbooksLoadingState extends StatelessWidget {
  const _CookbooksLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      children: [
        const _CollectionSummaryCardShimmer(),
        const SizedBox(height: AppTheme.spacing4),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: AppTheme.spacing12,
          crossAxisSpacing: AppTheme.spacing12,
          childAspectRatio: 0.78,
          children: List.generate(4, (_) => const _CookbookTileShimmer()),
        ),
      ],
    );
  }
}

class _CookbookTileShimmer extends StatelessWidget {
  const _CookbookTileShimmer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowSubtle,
      ),
      child: ClipRRect(
        borderRadius: AppTheme.borderRadiusXL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 11,
              child: Container(color: AppTheme.gray100),
            ),
            const Padding(
              padding: EdgeInsets.all(AppTheme.spacing12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBlock(
                      width: double.infinity, height: 14, radius: 6),
                  SizedBox(height: 8),
                  _ShimmerBlock(width: 60, height: 10, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookbooksHeaderCard extends StatelessWidget {
  const _CookbooksHeaderCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AccentPill(label: 'COOKBOOKS'),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            '$count cookbook${count == 1 ? '' : 's'}',
            style: AppTheme.displayTitleSmall().copyWith(height: 1.1),
          ),
          const SizedBox(height: AppTheme.spacing6),
          Text(
            'Group your recipes into folders. Each cookbook can be public or private.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CookbookGridTile extends StatelessWidget {
  const _CookbookGridTile({required this.cookbook});

  final Cookbook cookbook;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowCard,
      ),
      child: Material(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/cookbook/${cookbook.id}');
          },
          splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
          highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cookbook.coverPhoto != null
                        ? CachedNetworkImage(
                            imageUrl: cookbook.coverPhoto!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                const _CookbookTileFallback(),
                          )
                        : const _CookbookTileFallback(),
                    if (cookbook.coverPhoto != null)
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (cookbook.isPrivate)
                      Positioned(
                        top: AppTheme.spacing8,
                        right: AppTheme.spacing8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
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
                          color: AppTheme.textPrimaryDeep,
                          letterSpacing: -0.25,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${cookbook.recipesCount} recipe'
                        '${cookbook.recipesCount == 1 ? '' : 's'}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.gray500,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CookbookTileFallback extends StatelessWidget {
  const _CookbookTileFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          size: 36,
          color: AppTheme.accentPlayful,
        ),
      ),
    );
  }
}

class _CookbooksEmptyState extends StatelessWidget {
  const _CookbooksEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 30,
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'No cookbooks yet',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryDeep,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              'Tap “New” above to create your first cookbook.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
