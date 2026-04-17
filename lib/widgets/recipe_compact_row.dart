import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../utils/cloudinary_url.dart';
import '../utils/extensions.dart';
import 'recipe_image_placeholder.dart';
import 'recipe_like_button.dart';

String? formatRecipeDurationMinutes(int? minutes) {
  if (minutes == null || minutes <= 0) return null;
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m > 0 ? '${h}h ${m}m' : '${h}h';
}

Color difficultyLabelColor(String difficulty) {
  return switch (difficulty.toLowerCase()) {
    'easy' => AppTheme.success,
    'medium' => AppTheme.warning,
    'hard' => AppTheme.error,
    _ => AppTheme.gray400,
  };
}

/// Dense recipe row for feeds and search (thumbnail + metadata + like).
class RecipeCompactRow extends StatelessWidget {
  const RecipeCompactRow({
    super.key,
    required this.recipe,
    this.useRootRoute = false,
    this.showChevron = false,
    this.showLikeButton = true,
    this.showAuthor = true,
    this.showVisibilityBadge = false,
  });

  final Recipe recipe;
  final bool useRootRoute;
  final bool showChevron;
  final bool showLikeButton;
  final bool showAuthor;
  final bool showVisibilityBadge;

  void _openRecipe(BuildContext context) {
    if (useRootRoute) {
      context.push('/recipe/${recipe.id}');
    } else {
      context.push('/recipes/${recipe.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = recipe.photos.isNotEmpty;
    final timeText = formatRecipeDurationMinutes(recipe.totalTime ?? recipe.cookTime);
    final difficultyText = recipe.difficulty;
    final thumbUrl = hasPhoto
        ? cloudinaryUrl(recipe.photos.first, width: 136, height: 136)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openRecipe(context),
              borderRadius: AppTheme.borderRadiusMedium,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.borderRadiusMedium,
                        border: Border.all(
                          color: AppTheme.gray200.withValues(alpha: 0.6),
                        ),
                        boxShadow: AppTheme.shadowSubtle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasPhoto && thumbUrl != null
                          ? CachedNetworkImage(
                              imageUrl: thumbUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppTheme.gray100,
                              ),
                              errorWidget: (context, url, error) =>
                                  const _RecipeThumbPlaceholder(),
                            )
                          : const _RecipeThumbPlaceholder(),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (recipe.difficulty != null) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: difficultyLabelColor(recipe.difficulty!),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacing6),
                              ],
                              Expanded(
                                child: Text(
                                  recipe.title,
                                  style: context.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryDeep,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (showAuthor && recipe.authorName != null) ...[
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () =>
                                  context.push('/user/${recipe.authorId}'),
                              child: Text(
                                '@${recipe.authorName}',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppTheme.spacing6),
                          Row(
                            children: [
                              if (timeText != null) ...[
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: AppTheme.gray400,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  timeText,
                                  style: context.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.gray500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                              ],
                              if (difficultyText != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: difficultyLabelColor(difficultyText)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    difficultyText[0].toUpperCase() +
                                        difficultyText.substring(1),
                                    style:
                                        context.textTheme.labelSmall?.copyWith(
                                      color: difficultyLabelColor(
                                          difficultyText),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                              ],
                              if (recipe.servings != null &&
                                  recipe.servings! > 0) ...[
                                const Icon(
                                  Icons.restaurant_rounded,
                                  size: 13,
                                  color: AppTheme.gray400,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${recipe.servings}',
                                  style:
                                      context.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.gray500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                              ],
                              if (recipe.likesCount > 0) ...[
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 12,
                                  color: AppTheme.gray400,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${recipe.likesCount}',
                                  style:
                                      context.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.gray500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                              ],
                              if (showVisibilityBadge) ...[
                                _VisibilityBadge(isPrivate: recipe.isPrivate),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showLikeButton) RecipeLikeButton(recipe: recipe, dense: true),
          if (showChevron)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.gray300,
            ),
        ],
      ),
    );
  }
}

class _RecipeThumbPlaceholder extends StatelessWidget {
  const _RecipeThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const RecipeImagePlaceholder(compact: true);
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.isPrivate});

  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final color = isPrivate ? AppTheme.accentPlayful : AppTheme.success;
    final label = isPrivate ? 'Private' : 'Public';
    final icon = isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
