import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../utils/cloudinary_url.dart';
import '../utils/extensions.dart';
import '../widgets/recipe_compact_row.dart';
import 'recipe_image_placeholder.dart';
import 'shimmer_loading.dart';

/// Horizontal strip of the user's recent recipes on the home screen.
///
/// Shows up to 8 most-recently-updated recipes. Hidden entirely when the
/// user has no recipes.
class HomeYourRecipesStrip extends ConsumerWidget {
  const HomeYourRecipesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(myRecipesProvider);

    return recipesAsync.when(
      loading: () => const _ShimmerStrip(),
      error: (_, __) => const SizedBox.shrink(),
      data: (recipes) {
        if (recipes.isEmpty) return const SizedBox.shrink();

        final sorted = List<Recipe>.from(recipes)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final display = sorted.take(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Recipes',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryDeep,
                      letterSpacing: -0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/recipes'),
                    child: Text(
                      'See All \u2192',
                      style: context.textTheme.labelLarge?.copyWith(
                        color: AppTheme.accentPlayful,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 162,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                itemCount: display.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppTheme.spacing12),
                itemBuilder: (context, index) {
                  return _RecipeCard(recipe: display[index]);
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
          ],
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = recipe.photos.isNotEmpty;
    final thumbUrl = hasPhoto
        ? cloudinaryUrl(recipe.photos.first, width: 240, height: 200)
        : null;
    final timeText =
        formatRecipeDurationMinutes(recipe.totalTime ?? recipe.cookTime);

    return GestureDetector(
      onTap: () => context.push('/recipes/${recipe.id}'),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(
            color: AppTheme.gray200.withValues(alpha: 0.7),
          ),
          boxShadow: AppTheme.shadowSubtle,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 100,
              width: 120,
              child: hasPhoto && thumbUrl != null
                  ? CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppTheme.gray100),
                      errorWidget: (_, __, ___) =>
                          const RecipeImagePlaceholder(compact: true),
                    )
                  : const RecipeImagePlaceholder(compact: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing8,
                AppTheme.spacing6,
                AppTheme.spacing8,
                AppTheme.spacing6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryDeep,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeText != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: AppTheme.gray400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          timeText,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: AppTheme.gray500,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading shimmer for the recipes strip.
class _ShimmerStrip extends StatelessWidget {
  const _ShimmerStrip();

  @override
  Widget build(BuildContext context) {
    return ShimmerAnimator(
      builder: (context, gradientValue) {
        const baseColor = AppTheme.gray100;
        const highlightColor = Color(0xFFF0EDE8);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing12,
              ),
              child: ShimmerBox(
                baseColor: baseColor,
                highlightColor: highlightColor,
                gradientValue: gradientValue,
                height: 18,
                width: 120,
                borderRadius: AppTheme.borderRadiusSmall,
              ),
            ),
            SizedBox(
              height: 162,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                itemCount: 4,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppTheme.spacing12),
                itemBuilder: (_, __) {
                  return Container(
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: AppTheme.borderRadiusMedium,
                      border: Border.all(
                        color: AppTheme.gray200.withValues(alpha: 0.7),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          gradientValue: gradientValue,
                          height: 100,
                          width: 120,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.spacing8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(
                                baseColor: baseColor,
                                highlightColor: highlightColor,
                                gradientValue: gradientValue,
                                height: 12,
                                width: 80,
                                borderRadius: AppTheme.borderRadiusSmall,
                              ),
                              const SizedBox(height: AppTheme.spacing4),
                              ShimmerBox(
                                baseColor: baseColor,
                                highlightColor: highlightColor,
                                gradientValue: gradientValue,
                                height: 10,
                                width: 50,
                                borderRadius: AppTheme.borderRadiusSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
          ],
        );
      },
    );
  }
}
