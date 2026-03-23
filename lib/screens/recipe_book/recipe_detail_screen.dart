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
            padding: const EdgeInsets.all(AppTheme.spacingLg),
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
                  'Failed to load recipe',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingMd),
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
        final isLiked = recipe.isLiked ?? false;
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
                expandedHeight: 300,
                pinned: true,
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'More options',
                    onSelected: (value) => _onMenuAction(value, recipe),
                    itemBuilder: (context) => [
                      if (isOwner) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: AppTheme.spacingSm),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: context.colorScheme.error,
                              ),
                              const SizedBox(width: AppTheme.spacingSm),
                              Text(
                                'Delete',
                                style: TextStyle(
                                    color: context.colorScheme.error),
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
                              SizedBox(width: AppTheme.spacingSm),
                              Text('Report'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: PhotoCarousel(
                    photos: recipe.photos,
                    height: 350,
                    overlayWidget: signatureOverlay,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        recipe.title,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Author card
                      if (recipe.authorName != null && !isOwner) ...[
                        const SizedBox(height: AppTheme.spacingMd),
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
                              const SizedBox(width: AppTheme.spacingSm),
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
                                      ),
                                    ),
                                    Text(
                                      'View profile',
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                        color: context
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color:
                                    context.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (recipe.authorName != null && isOwner) ...[
                        const SizedBox(height: AppTheme.spacingXs),
                        Text(
                          'By you',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      // Fork source
                      if (recipe.forkedFrom != null) ...[
                        const SizedBox(height: AppTheme.spacingXs),
                        GestureDetector(
                          onTap: () => context.push(
                              '/recipes/${recipe.forkedFrom!.recipeId}'),
                          child: Text(
                            'Forked from @${recipe.forkedFrom!.authorName}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],

                      // Modified fork badge
                      if (recipe.isModifiedFork) ...[
                        const SizedBox(height: AppTheme.spacingSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.tertiaryContainer,
                            borderRadius: AppTheme.borderRadiusSmall,
                          ),
                          child: Text(
                            'Modified from original',
                            style: context.textTheme.labelSmall?.copyWith(
                              color:
                                  context.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],

                      // Description
                      if (recipe.description != null &&
                          recipe.description!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          recipe.description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      // Story (collapsible)
                      if (recipe.story != null &&
                          recipe.story!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingMd),
                        _CollapsibleStory(story: recipe.story!),
                      ],

                      // Tags
                      const SizedBox(height: AppTheme.spacingMd),
                      _TagChips(recipe: recipe),

                      // Info row
                      const SizedBox(height: AppTheme.spacingMd),
                      _InfoRow(recipe: recipe),

                      // Servings adjuster
                      const SizedBox(height: AppTheme.spacingLg),
                      Row(
                        children: [
                          Text(
                            'Servings',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
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
                        const SizedBox(height: AppTheme.spacingXs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primaryContainer,
                            borderRadius: AppTheme.borderRadiusSmall,
                          ),
                          child: Text(
                            'Adjusted for $servings servings (original: ${recipe.baseServings})',
                            style: context.textTheme.labelSmall?.copyWith(
                              color:
                                  context.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],

                      // Ingredients
                      const SizedBox(height: AppTheme.spacingLg),
                      Text(
                        'Ingredients',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      _IngredientsList(
                        ingredients: recipe.ingredients,
                        baseServings: recipe.baseServings,
                        currentServings: servings,
                      ),

                      // Steps
                      const SizedBox(height: AppTheme.spacingLg),
                      Text(
                        'Steps',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      _StepsList(steps: recipe.steps),

                      const SizedBox(height: AppTheme.spacingXl),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _ActionBar(
            recipe: recipe,
            isLiked: isLiked,
            onLike: () {
              if (isLiked) {
                ref
                    .read(recipeActionProvider.notifier)
                    .unlike(recipe.id);
              } else {
                ref.read(recipeActionProvider.notifier).like(recipe.id);
              }
            },
            onFork: () => _onFork(recipe),
            onShare: () => _onShare(recipe),
          ),
        );
      },
    );
  }

  void _onMenuAction(String action, Recipe recipe) {
    switch (action) {
      case 'edit':
        context.push('/recipes/${recipe.id}/edit');
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
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(recipeActionProvider.notifier)
                  .deleteRecipe(recipe.id);
              if (mounted) context.pop();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Forked "${recipe.title}" to your recipes'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.push('/recipes/${forked.id}'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: AppTheme.borderRadiusMedium,
          onTap: () {
            if (mounted) setState(() => _isExpanded = !_isExpanded);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm + 2,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: _isExpanded
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    )
                  : AppTheme.borderRadiusMedium,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 18,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    'Read the story behind this recipe',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: context.colorScheme.primary,
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
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Text(
              widget.story,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

class _TagChips extends StatelessWidget {
  const _TagChips({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final allTags = <_TagItem>[
      ...recipe.labels.map((l) => _TagItem(l, context.colorScheme.secondaryContainer,
          context.colorScheme.onSecondaryContainer)),
      ...recipe.dietaryTags.map((t) => _TagItem(t, context.colorScheme.tertiaryContainer,
          context.colorScheme.onTertiaryContainer)),
      ...recipe.cuisineTags.map((t) => _TagItem(t, context.colorScheme.primaryContainer,
          context.colorScheme.onPrimaryContainer)),
    ];

    if (allTags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: allTags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tag.bgColor,
            borderRadius: AppTheme.borderRadiusSmall,
          ),
          child: Text(
            tag.label,
            style: context.textTheme.labelSmall?.copyWith(
              color: tag.textColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TagItem {
  const _TagItem(this.label, this.bgColor, this.textColor);
  final String label;
  final Color bgColor;
  final Color textColor;
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
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: AppTheme.borderRadiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientsList extends StatelessWidget {
  const _IngredientsList({
    required this.ingredients,
    required this.baseServings,
    required this.currentServings,
  });

  final List<Ingredient> ingredients;
  final int baseServings;
  final int currentServings;

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return Text(
        'No ingredients listed.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Group ingredients by their group field.
    final grouped = <String?, List<Ingredient>>{};
    for (final ingredient in ingredients) {
      grouped.putIfAbsent(ingredient.group, () => []).add(ingredient);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      if (entry.key != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacingMd,
              bottom: AppTheme.spacingSm,
            ),
            child: Text(
              entry.key!,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colorScheme.primary,
              ),
            ),
          ),
        );
      }

      for (final ingredient in entry.value) {
        final scaledQty =
            scaleQuantity(ingredient.quantity, baseServings, currentServings);
        widgets.add(
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: context.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: context.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: '${formatQuantity(scaledQty)} ${ingredient.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: '  ${ingredient.name}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _StepsList extends StatelessWidget {
  const _StepsList({required this.steps});

  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Text(
        'No steps listed.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final sorted = List<RecipeStep>.from(steps)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      children: sorted.map((step) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${step.order}',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.instruction,
                      style: context.textTheme.bodyMedium,
                    ),
                    if (step.photo != null) ...[
                      const SizedBox(height: AppTheme.spacingSm),
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
        );
      }).toList(),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.recipe,
    required this.isLiked,
    required this.onLike,
    required this.onFork,
    required this.onShare,
  });

  final Recipe recipe;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onFork;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: context.colorScheme.outlineVariant,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spacingMd,
        right: AppTheme.spacingMd,
        top: AppTheme.spacingSm,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacingSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: '${recipe.likesCount}',
            color: isLiked ? AppTheme.tertiaryColor : null,
            onTap: onLike,
            tooltip: isLiked ? 'Unlike' : 'Like',
          ),
          _ActionButton(
            icon: Icons.fork_right,
            label: '${recipe.forksCount}',
            onTap: onFork,
            tooltip: 'Fork recipe',
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
            horizontal: AppTheme.spacingSm,
            vertical: AppTheme.spacingXs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: color ?? context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: color ?? context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
