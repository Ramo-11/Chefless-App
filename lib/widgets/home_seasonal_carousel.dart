import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../utils/cloudinary_url.dart';
import '../utils/extensions.dart';
import 'recipe_image_placeholder.dart';

/// Horizontal editorial cards for the Seasonal feed.
class HomeSeasonalCarousel extends StatelessWidget {
  const HomeSeasonalCarousel({
    super.key,
    required this.recipes,
    this.useRootRoute = true,
  });

  final List<Recipe> recipes;
  final bool useRootRoute;

  void _open(BuildContext context, Recipe recipe) {
    HapticFeedback.selectionClick();
    if (useRootRoute) {
      context.push('/recipe/${recipe.id}');
    } else {
      context.push('/recipes/${recipe.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const SizedBox.shrink();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * 0.78).clamp(280.0, 360.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing24,
            AppTheme.spacing16,
            AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.accentPlayful,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                'Seasonal spotlight',
                style: AppTheme.displayTitleSmall().copyWith(
                  fontSize: 19,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Icon(
                Icons.eco_rounded,
                size: 16,
                color: AppTheme.accentPlayful.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              left: AppTheme.spacing16,
              right: AppTheme.spacing8,
              bottom: AppTheme.spacing8,
              top: AppTheme.spacing4,
            ),
            itemCount: recipes.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppTheme.spacing12),
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final hasPhoto = recipe.photos.isNotEmpty;
              final imageUrl = hasPhoto
                  ? cloudinaryUrl(recipe.photos.first, width: 600, height: 420)
                  : null;

              return SizedBox(
                width: cardWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.borderRadiusXL,
                    boxShadow: AppTheme.shadowCard,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: AppTheme.borderRadiusXL,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(context, recipe),
                      borderRadius: AppTheme.borderRadiusXL,
                      splashColor: Colors.white.withValues(alpha: 0.1),
                      highlightColor: Colors.white.withValues(alpha: 0.05),
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
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        AppTheme.accentPlayful,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const RecipeImagePlaceholder(),
                            )
                          else
                            const RecipeImagePlaceholder(),
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0.35, 1.0],
                                    colors: [
                                      Color(0x00000000),
                                      Color(0x7A000000),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: AppTheme.spacing16,
                            right: AppTheme.spacing16,
                            bottom: AppTheme.spacing14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  recipe.title,
                                  style: context.textTheme.titleMedium
                                      ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    letterSpacing: -0.3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.55),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (recipe.authorName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'by ${recipe.authorName}',
                                    style: context.textTheme.labelMedium
                                        ?.copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.88),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
