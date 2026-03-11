import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../utils/extensions.dart';

/// A card widget that displays a recipe summary in a list or grid.
class RecipeCard extends ConsumerWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
  });

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            AspectRatio(
              aspectRatio: 16 / 10,
              child: recipe.photos.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: recipe.photos.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: context.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          _PhotoPlaceholder(colorScheme: context.colorScheme),
                    )
                  : _PhotoPlaceholder(colorScheme: context.colorScheme),
            ),

            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    recipe.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Author
                  if (recipe.authorName != null) ...[
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => context.push('/user/${recipe.authorId}'),
                      child: Text(
                        '@${recipe.authorName}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTheme.spacingSm),

                  // Tags row
                  _TagsRow(recipe: recipe),

                  const SizedBox(height: AppTheme.spacingSm),

                  // Engagement row
                  Row(
                    children: [
                      _LikeButton(recipe: recipe, ref: ref),
                      const SizedBox(width: AppTheme.spacingMd),
                      Icon(
                        Icons.fork_right,
                        size: 18,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.forksCount}',
                        style: context.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (recipe.cookTime != null || recipe.totalTime != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.totalTime ?? recipe.cookTime} min',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          size: 40,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  const _TagsRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final allTags = <String>[
      ...recipe.labels.take(2),
      ...recipe.dietaryTags.take(2),
    ];

    if (allTags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: allTags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.colorScheme.secondaryContainer,
            borderRadius: AppTheme.borderRadiusSmall,
          ),
          child: Text(
            tag,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSecondaryContainer,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.recipe,
    required this.ref,
  });

  final Recipe recipe;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isLiked = recipe.isLiked ?? false;

    return InkWell(
      borderRadius: AppTheme.borderRadiusSmall,
      onTap: () {
        if (isLiked) {
          ref.read(recipeActionProvider.notifier).unlike(recipe.id);
        } else {
          ref.read(recipeActionProvider.notifier).like(recipe.id);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: isLiked
                ? AppTheme.tertiaryColor
                : context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '${recipe.likesCount}',
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
