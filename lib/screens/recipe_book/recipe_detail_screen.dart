import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/fraction_utils.dart';
import '../../widgets/ingredient_scaling.dart';
import '../../widgets/photo_carousel.dart';
import '../../widgets/report_sheet.dart';
import '../../widgets/signature_overlay.dart';
import '../../widgets/user_avatar.dart';
import 'share_recipe_sheet.dart';

/// Full recipe detail screen with photo carousel, ingredients, steps,
/// serving adjuster, and action bar.
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _adjustedServings;
  bool? _localIsLiked;
  int? _localLikesCount;

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return recipeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 28,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                Text(
                  'Failed to load recipe',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing24),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(recipeDetailProvider(widget.recipeId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (recipe) {
        final servings = _adjustedServings ?? recipe.servings ?? recipe.baseServings;
        final isOwner = currentUser?.id == recipe.authorId;
        final isLiked = _localIsLiked ?? (recipe.isLiked ?? false);
        final likesCount = _localLikesCount ?? recipe.likesCount;
        final isScaled = _adjustedServings != null &&
            _adjustedServings != recipe.baseServings;

        // Build the signature overlay if applicable.
        Widget? signatureOverlay;
        if (recipe.showSignature && currentUser?.signature != null) {
          signatureOverlay =
              SignatureOverlay(signatureUrl: currentUser!.signature!);
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App bar with photo carousel
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                leading: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                actions: [
                  Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: AppTheme.spacing8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                      tooltip: 'More options',
                      onSelected: (value) => _onMenuAction(value, recipe),
                      itemBuilder: (context) => [
                        if (isOwner) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: AppTheme.spacing8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: AppTheme.error,
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                      color: AppTheme.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (!isOwner)
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, size: 20),
                                SizedBox(width: AppTheme.spacing8),
                                Text('Report'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: PhotoCarousel(
                    photos: recipe.photos,
                    height: 370,
                    overlayWidget: signatureOverlay,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing20,
                    vertical: AppTheme.spacing20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        recipe.title,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: AppTheme.gray900,
                        ),
                      ),

                      // Author card
                      if (recipe.authorName != null && !isOwner) ...[
                        const SizedBox(height: AppTheme.spacing16),
                        GestureDetector(
                          onTap: () =>
                              context.push('/user/${recipe.authorId}'),
                          child: Row(
                            children: [
                              UserAvatar(
                                fullName: recipe.authorName!,
                                profilePictureUrl: recipe.authorPhoto,
                                size: 40,
                              ),
                              const SizedBox(width: AppTheme.spacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.authorName!,
                                      style: context.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.gray900,
                                      ),
                                    ),
                                    Text(
                                      'View profile',
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                        color: AppTheme.gray500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.gray400,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (recipe.authorName != null && isOwner) ...[
                        const SizedBox(height: AppTheme.spacing6),
                        Text(
                          'By you',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.gray500,
                          ),
                        ),
                      ],

                      // Fork source
                      if (recipe.forkedFrom != null) ...[
                        const SizedBox(height: AppTheme.spacing6),
                        GestureDetector(
                          onTap: () => context.push(
                              '/recipe/${recipe.forkedFrom!.recipeId}'),
                          child: Text(
                            'Remixed from @${recipe.forkedFrom!.authorName}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      // Modified fork badge
                      if (recipe.isModifiedFork) ...[
                        const SizedBox(height: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing12,
                            vertical: AppTheme.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: AppTheme.borderRadiusFull,
                          ),
                          child: Text(
                            'Modified from original',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      // Description
                      if (recipe.description != null &&
                          recipe.description!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacing16),
                        Text(
                          recipe.description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.gray600,
                            height: 1.5,
                          ),
                        ),
                      ],

                      // Story (collapsible)
                      if (recipe.story != null &&
                          recipe.story!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacing16),
                        _CollapsibleStory(story: recipe.story!),
                      ],

                      // Tags
                      const SizedBox(height: AppTheme.spacing16),
                      _TagChips(recipe: recipe),

                      // Info row
                      const SizedBox(height: AppTheme.spacing16),
                      _InfoRow(recipe: recipe),

                      // Divider before servings
                      const SizedBox(height: AppTheme.spacing24),
                      Divider(color: AppTheme.gray100),
                      const SizedBox(height: AppTheme.spacing24),

                      // Servings adjuster
                      Row(
                        children: [
                          Text(
                            'Servings',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: AppTheme.gray900,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing16),
                          IngredientScaling(
                            currentServings: servings,
                            baseServings: recipe.baseServings,
                            onChanged: (value) {
                              if (mounted) {
                                setState(() => _adjustedServings = value);
                              }
                            },
                          ),
                        ],
                      ),

                      if (isScaled) ...[
                        const SizedBox(height: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing12,
                            vertical: AppTheme.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: AppTheme.borderRadiusFull,
                          ),
                          child: Text(
                            'Adjusted for $servings servings (original: ${recipe.baseServings})',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      // Ingredients
                      const SizedBox(height: AppTheme.spacing24),
                      Text(
                        'Ingredients',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: AppTheme.gray900,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      _IngredientsList(
                        ingredients: recipe.ingredients,
                        baseServings: recipe.baseServings,
                        currentServings: servings,
                      ),

                      // Divider before steps
                      const SizedBox(height: AppTheme.spacing24),
                      Divider(color: AppTheme.gray100),
                      const SizedBox(height: AppTheme.spacing24),

                      // Steps
                      Text(
                        'Steps',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: AppTheme.gray900,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      _StepsList(steps: recipe.steps),

                      const SizedBox(height: AppTheme.spacing40),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _ActionBar(
            recipe: recipe,
            isOwner: isOwner,
            isLiked: isLiked,
            likesCount: likesCount,
            onLike: () {
              final currentCount = _localLikesCount ?? recipe.likesCount;
              if (mounted) {
                setState(() {
                  _localIsLiked = !isLiked;
                  _localLikesCount = currentCount + (isLiked ? -1 : 1);
                });
              }
              if (isLiked) {
                ref
                    .read(recipeActionProvider.notifier)
                    .unlike(recipe.id);
              } else {
                ref.read(recipeActionProvider.notifier).like(recipe.id);
              }
            },
            onForkOrDuplicate: isOwner
                ? () => _onDuplicate(recipe)
                : () => _onFork(recipe),
            onShare: () => _onShare(recipe),
          ),
        );
      },
    );
  }

  void _onMenuAction(String action, Recipe recipe) {
    switch (action) {
      case 'edit':
        context.push('/recipe/${recipe.id}/edit');
      case 'delete':
        _confirmDelete(recipe);
      case 'report':
        _showReportSheet(recipe);
    }
  }

  void _showReportSheet(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ReportSheet(
        targetType: 'recipe',
        targetId: recipe.id,
      ),
    );
  }

  void _confirmDelete(Recipe recipe) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${recipe.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pop();
              ref
                  .read(recipeActionProvider.notifier)
                  .deleteRecipe(recipe.id);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onFork(Recipe recipe) async {
    final forked =
        await ref.read(recipeActionProvider.notifier).fork(recipe.id);
    if (forked != null && mounted) {
      context.push('/recipe/${forked.id}');
    }
  }

  Future<void> _onDuplicate(Recipe recipe) async {
    final forked =
        await ref.read(recipeActionProvider.notifier).fork(recipe.id);
    if (forked != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated "${recipe.title}"'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.push('/recipe/${forked.id}'),
          ),
        ),
      );
    }
  }

  void _onShare(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ShareRecipeSheet(recipeId: recipe.id),
    );
  }
}

class _CollapsibleStory extends StatefulWidget {
  const _CollapsibleStory({required this.story});

  final String story;

  @override
  State<_CollapsibleStory> createState() => _CollapsibleStoryState();
}

class _CollapsibleStoryState extends State<_CollapsibleStory>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.gray200),
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: _isExpanded
                ? const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusMedium),
                    topRight: Radius.circular(AppTheme.radiusMedium),
                  )
                : AppTheme.borderRadiusMedium,
            onTap: () {
              if (mounted) setState(() => _isExpanded = !_isExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      'Read the story behind this recipe',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                0,
                AppTheme.spacing16,
                AppTheme.spacing16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: AppTheme.gray100),
                  const SizedBox(height: AppTheme.spacing12),
                  Text(
                    widget.story,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray600,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _TagChips extends StatelessWidget {
  const _TagChips({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final hasLabels = recipe.labels.isNotEmpty;
    final hasDietary = recipe.dietaryTags.isNotEmpty;
    final hasCuisine = recipe.cuisineTags.isNotEmpty;

    if (!hasLabels && !hasDietary && !hasCuisine) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AppTheme.spacing6,
      runSpacing: AppTheme.spacing6,
      children: [
        if (hasLabels)
          ...recipe.labels.map((tag) => _buildChip(context, tag, AppTheme.gray50, AppTheme.gray700)),
        if (hasDietary)
          ...recipe.dietaryTags.map((tag) => _buildChip(context, tag, AppTheme.primaryLight, AppTheme.primaryDark)),
        if (hasCuisine)
          ...recipe.cuisineTags.map((tag) => _buildChip(context, tag, AppTheme.gray100, AppTheme.gray600)),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String tag,
      Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: Text(
        tag,
        style: context.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (recipe.prepTime != null) {
      items.add(_InfoChip(
        icon: Icons.timer_outlined,
        label: 'Prep: ${recipe.prepTime} min',
      ));
    }
    if (recipe.cookTime != null) {
      items.add(_InfoChip(
        icon: Icons.local_fire_department_outlined,
        label: 'Cook: ${recipe.cookTime} min',
      ));
    }
    if (recipe.difficulty != null) {
      items.add(_InfoChip(
        icon: Icons.signal_cellular_alt,
        label: recipe.difficulty!,
      ));
    }
    if (recipe.calories != null) {
      items.add(_InfoChip(
        icon: Icons.bolt_outlined,
        label: '${recipe.calories} cal',
      ));
    }
    if (recipe.costEstimate != null) {
      items.add(_InfoChip(
        icon: Icons.attach_money,
        label: recipe.costEstimate!,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppTheme.spacing8,
      runSpacing: AppTheme.spacing8,
      children: items,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: AppTheme.borderRadiusFull,
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.gray500),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: AppTheme.gray600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientsList extends StatefulWidget {
  const _IngredientsList({
    required this.ingredients,
    required this.baseServings,
    required this.currentServings,
  });

  final List<Ingredient> ingredients;
  final int baseServings;
  final int currentServings;

  @override
  State<_IngredientsList> createState() => _IngredientsListState();
}

class _IngredientsListState extends State<_IngredientsList> {
  final Set<int> _checked = {};

  @override
  Widget build(BuildContext context) {
    if (widget.ingredients.isEmpty) {
      return Text(
        'No ingredients listed.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: AppTheme.gray500,
        ),
      );
    }

    // Group ingredients by their group field.
    final grouped = <String?, List<Ingredient>>{};
    for (final ingredient in widget.ingredients) {
      grouped.putIfAbsent(ingredient.group, () => []).add(ingredient);
    }

    final widgets = <Widget>[];
    var flatIndex = 0;
    for (final entry in grouped.entries) {
      if (entry.key != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacing16,
              bottom: AppTheme.spacing8,
            ),
            child: Text(
              entry.key!,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
      }

      for (final ingredient in entry.value) {
        final idx = flatIndex;
        final isChecked = _checked.contains(idx);
        final scaledQty = scaleQuantity(
            ingredient.quantity, widget.baseServings, widget.currentServings);
        widgets.add(
          InkWell(
            borderRadius: AppTheme.borderRadiusSmall,
            onTap: () {
              setState(() {
                if (isChecked) {
                  _checked.remove(idx);
                } else {
                  _checked.add(idx);
                }
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: isChecked,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _checked.add(idx);
                          } else {
                            _checked.remove(idx);
                          }
                        });
                      },
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: context.textTheme.bodyMedium?.copyWith(
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : null,
                          color: isChecked
                              ? AppTheme.gray400
                              : AppTheme.gray900,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${formatQuantity(scaledQty)} ${ingredient.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          TextSpan(
                            text: '  ${ingredient.name}',
                            style: TextStyle(
                              color: isChecked
                                  ? AppTheme.gray400
                                  : AppTheme.gray700,
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
        flatIndex++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _StepsList extends StatefulWidget {
  const _StepsList({required this.steps});

  final List<RecipeStep> steps;

  @override
  State<_StepsList> createState() => _StepsListState();
}

class _StepsListState extends State<_StepsList> {
  final Set<int> _completed = {};

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return Text(
        'No steps listed.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: AppTheme.gray500,
        ),
      );
    }

    final sorted = List<RecipeStep>.from(widget.steps)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      children: sorted.map((step) {
        final isDone = _completed.contains(step.order);
        return InkWell(
          borderRadius: AppTheme.borderRadiusSmall,
          onTap: () {
            setState(() {
              if (isDone) {
                _completed.remove(step.order);
              } else {
                _completed.add(step.order);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppTheme.success
                        : AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : Text(
                          '${step.order}',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppTheme.spacing4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: (context.textTheme.bodyMedium ?? const TextStyle())
                            .copyWith(
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                          color: isDone
                              ? AppTheme.gray400
                              : AppTheme.gray800,
                          height: 1.5,
                        ),
                        child: Text(step.instruction),
                      ),
                      if (step.photo != null) ...[
                        const SizedBox(height: AppTheme.spacing8),
                        ClipRRect(
                          borderRadius: AppTheme.borderRadiusMedium,
                          child: Image.network(
                            step.photo!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
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
      }).toList(),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.recipe,
    required this.isOwner,
    required this.isLiked,
    required this.likesCount,
    required this.onLike,
    required this.onForkOrDuplicate,
    required this.onShare,
  });

  final Recipe recipe;
  final bool isOwner;
  final bool isLiked;
  final int likesCount;
  final VoidCallback onLike;
  final VoidCallback onForkOrDuplicate;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.gray200,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spacing16,
        right: AppTheme.spacing16,
        top: AppTheme.spacing8,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacing8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            label: '$likesCount',
            color: isLiked ? AppTheme.likeColor : null,
            onTap: onLike,
            tooltip: isLiked ? 'Unlike' : 'Like',
          ),
          _ActionButton(
            icon: isOwner ? Icons.copy_outlined : Icons.autorenew_rounded,
            label: isOwner ? 'Duplicate' : '${recipe.forksCount}',
            onTap: onForkOrDuplicate,
            tooltip: isOwner ? 'Duplicate recipe' : 'Remix recipe',
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: onShare,
            tooltip: 'Share recipe',
          ),
          _ActionButton(
            icon: Icons.calendar_today_outlined,
            label: 'Schedule',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scheduling coming soon')),
              );
            },
            tooltip: 'Add to schedule',
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: AppTheme.borderRadiusSmall,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: color ?? AppTheme.gray600,
              ),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: color ?? AppTheme.gray500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
