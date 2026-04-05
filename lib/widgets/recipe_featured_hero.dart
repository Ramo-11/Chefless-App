import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../utils/cloudinary_url.dart';
import '../utils/extensions.dart';
import 'recipe_image_placeholder.dart';

/// Single editorial hero for the home feed (gradient overlay + typography).
class RecipeFeaturedHero extends StatelessWidget {
  const RecipeFeaturedHero({
    super.key,
    required this.recipe,
    this.useRootRoute = true,
  });

  final Recipe recipe;
  final bool useRootRoute;

  void _open(BuildContext context) {
    if (useRootRoute) {
      context.push('/recipe/${recipe.id}');
    } else {
      context.push('/recipes/${recipe.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = recipe.photos.isNotEmpty;
    final imageUrl = hasPhoto
        ? cloudinaryUrl(recipe.photos.first, width: 800, height: 500)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: AppTheme.borderRadiusXL,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppTheme.borderRadiusXL,
              boxShadow: AppTheme.shadowFeatured,
            ),
            child: ClipRRect(
              borderRadius: AppTheme.borderRadiusXL,
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasPhoto && imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppTheme.gray200,
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const _HeroPlaceholder(),
                      )
                    else
                      const _HeroPlaceholder(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppTheme.spacing16,
                      right: AppTheme.spacing16,
                      bottom: AppTheme.spacing16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing8,
                              vertical: AppTheme.spacing4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPlayful.withValues(
                                alpha: 0.92,
                              ),
                              borderRadius: AppTheme.borderRadiusFull,
                            ),
                            child: Text(
                              'Featured',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            recipe.title,
                            style: AppTheme.displayTitleSmall(
                              color: Colors.white,
                            ).copyWith(
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (recipe.authorName != null) ...[
                            const SizedBox(height: AppTheme.spacing6),
                            GestureDetector(
                              onTap: () =>
                                  context.push('/user/${recipe.authorId}'),
                              child: Text(
                                '@${recipe.authorName}',
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (recipe.isPrivate)
                      Positioned(
                        top: AppTheme.spacing12,
                        right: AppTheme.spacing12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing8,
                            vertical: AppTheme.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
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
          ),
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const RecipeImagePlaceholder();
  }
}
