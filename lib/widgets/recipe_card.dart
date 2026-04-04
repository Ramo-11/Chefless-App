import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../utils/cloudinary_url.dart';
import '../utils/extensions.dart';

/// A card widget that displays a recipe summary in a list or grid.
class RecipeCard extends ConsumerWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.useRootRoute = false,
  });

  final Recipe recipe;

  /// When true, navigates via the root-level `/recipe/:id` route instead of
  /// the tab-nested `/recipes/:id`. Use this when the card is shown outside
  /// the Recipes tab (e.g. on another user's profile, explore, search).
  final bool useRootRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(color: AppTheme.gray200),
      ),
      child: InkWell(
        borderRadius: AppTheme.borderRadiusMedium,
        onTap: () => useRootRoute
            ? context.push('/recipe/${recipe.id}')
            : context.push('/recipes/${recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: recipe.photos.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cloudinaryUrl(recipe.photos.first,
                              width: 500, height: 312),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.gray100,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              const _PhotoPlaceholder(),
                        )
                      : const _PhotoPlaceholder(),
                ),
                if (recipe.isPrivate)
                  Positioned(
                    top: AppTheme.spacing8,
                    right: AppTheme.spacing8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: AppTheme.borderRadiusFull,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: AppTheme.spacing4),
                          Text(
                            'Private',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    recipe.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Author
                  if (recipe.authorName != null) ...[
                    const SizedBox(height: AppTheme.spacing2),
                    GestureDetector(
                      onTap: () => context.push('/user/${recipe.authorId}'),
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

                  const SizedBox(height: AppTheme.spacing8),

                  // Tags row
                  _TagsRow(recipe: recipe),

                  const SizedBox(height: AppTheme.spacing8),

                  // Engagement row
                  Row(
                    children: [
                      _LikeButton(recipe: recipe),
                      const SizedBox(width: AppTheme.spacing16),
                      Icon(
                        Icons.autorenew_rounded,
                        size: 16,
                        color: AppTheme.gray400,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        '${recipe.forksCount}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.gray500,
                        ),
                      ),
                      const Spacer(),
                      if (recipe.cookTime != null || recipe.totalTime != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: AppTheme.gray400,
                            ),
                            const SizedBox(width: AppTheme.spacing4),
                            Text(
                              '${recipe.totalTime ?? recipe.cookTime} min',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppTheme.gray500,
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
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.gray100,
      child: const Center(
        child: Icon(
          Icons.restaurant_menu,
          size: 40,
          color: AppTheme.gray300,
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
      spacing: AppTheme.spacing4,
      runSpacing: AppTheme.spacing4,
      children: allTags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing2,
          ),
          decoration: BoxDecoration(
            color: AppTheme.gray50,
            borderRadius: AppTheme.borderRadiusFull,
            border: Border.all(color: AppTheme.gray200),
          ),
          child: Text(
            tag,
            style: context.textTheme.labelSmall?.copyWith(
              color: AppTheme.gray600,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton> {
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.recipe.isLiked ?? false;
    _likesCount = widget.recipe.likesCount;
  }

  @override
  void didUpdateWidget(covariant _LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recipe.id != oldWidget.recipe.id) {
      _isLiked = widget.recipe.isLiked ?? false;
      _likesCount = widget.recipe.likesCount;
    }
  }

  void _toggle() {
    final wasLiked = _isLiked;
    if (mounted) {
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
    }
    final future = wasLiked
        ? ref.read(recipeActionProvider.notifier).unlike(widget.recipe.id)
        : ref.read(recipeActionProvider.notifier).like(widget.recipe.id);
    future.catchError((_) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesCount += wasLiked ? 1 : -1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppTheme.borderRadiusFull,
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: _isLiked ? AppTheme.likeColor : AppTheme.gray400,
          ),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            '$_likesCount',
            style: context.textTheme.bodySmall?.copyWith(
              color: _isLiked ? AppTheme.likeColor : AppTheme.gray500,
              fontWeight: _isLiked ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
