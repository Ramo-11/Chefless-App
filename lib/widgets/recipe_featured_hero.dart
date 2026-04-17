import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../utils/app_icons.dart';
import '../utils/cloudinary_url.dart';
import '../utils/extensions.dart';
import 'recipe_compact_row.dart';
import 'recipe_image_placeholder.dart';
import 'recipe_share_options_sheet.dart';

/// Single editorial hero for the home feed (gradient overlay + typography).
class RecipeFeaturedHero extends ConsumerStatefulWidget {
  const RecipeFeaturedHero({
    super.key,
    required this.recipe,
    this.useRootRoute = true,
  });

  final Recipe recipe;
  final bool useRootRoute;

  @override
  ConsumerState<RecipeFeaturedHero> createState() =>
      _RecipeFeaturedHeroState();
}

class _RecipeFeaturedHeroState extends ConsumerState<RecipeFeaturedHero>
    with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likesCount;
  late final AnimationController _likePop;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.recipe.isLiked ?? false;
    _likesCount = widget.recipe.likesCount;
    _likePop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _likePop.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RecipeFeaturedHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recipe.id != oldWidget.recipe.id) {
      _isLiked = widget.recipe.isLiked ?? false;
      _likesCount = widget.recipe.likesCount;
    }
  }

  void _toggleLike() {
    final wasLiked = _isLiked;
    if (mounted) {
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
    }
    HapticFeedback.lightImpact();
    _likePop.forward(from: 0);
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

  void _open() {
    HapticFeedback.selectionClick();
    if (widget.useRootRoute) {
      context.push('/recipe/${widget.recipe.id}');
    } else {
      context.push('/recipes/${widget.recipe.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final hasPhoto = recipe.photos.isNotEmpty;
    final imageUrl = hasPhoto
        ? cloudinaryUrl(recipe.photos.first, width: 900, height: 560)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing4,
        AppTheme.spacing16,
        AppTheme.spacing20,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowHero,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppTheme.borderRadiusXL,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _open,
            borderRadius: AppTheme.borderRadiusXL,
            splashColor: Colors.white.withValues(alpha: 0.10),
            highlightColor: Colors.white.withValues(alpha: 0.05),
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
                            width: 26,
                            height: 26,
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
                          const _HeroPlaceholder(),
                    )
                  else
                    const _HeroPlaceholder(),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.45, 1.0],
                          colors: [
                            Color(0x00000000),
                            Color(0x14000000),
                            Color(0x66000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppTheme.spacing20,
                    right: AppTheme.spacing20,
                    bottom: AppTheme.spacing20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPlayful,
                            borderRadius: AppTheme.borderRadiusFull,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentPlayful
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'FEATURED',
                                style:
                                    context.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        Text(
                          recipe.title,
                          style: AppTheme.displayTitleSmall(
                            color: Colors.white,
                          ).copyWith(
                            fontSize: 26,
                            height: 1.1,
                            letterSpacing: -0.6,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 16,
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
                              'by ${recipe.authorName}',
                              style:
                                  context.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTheme.spacing12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _HeroInfoPill(
                              icon: Icons.favorite_rounded,
                              text: '$_likesCount',
                            ),
                            if (recipe.totalTime != null ||
                                recipe.cookTime != null)
                              _HeroInfoPill(
                                icon: Icons.schedule_rounded,
                                text: formatRecipeDurationMinutes(
                                  recipe.totalTime ?? recipe.cookTime,
                                )!,
                              ),
                            if (recipe.difficulty != null)
                              _HeroInfoPill(
                                icon: Icons.bar_chart_rounded,
                                text: recipe.difficulty![0].toUpperCase() +
                                    recipe.difficulty!.substring(1),
                              ),
                            if (recipe.servings != null)
                              _HeroInfoPill(
                                icon: Icons.restaurant_rounded,
                                text: '${recipe.servings} servings',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: AppTheme.spacing12,
                    right: AppTheme.spacing12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ScaleTransition(
                          scale: TweenSequence<double>([
                            TweenSequenceItem(
                              tween: Tween<double>(begin: 1, end: 1.28).chain(
                                CurveTween(curve: Curves.easeOutBack),
                              ),
                              weight: 45,
                            ),
                            TweenSequenceItem(
                              tween: Tween<double>(begin: 1.28, end: 1).chain(
                                CurveTween(curve: Curves.easeIn),
                              ),
                              weight: 55,
                            ),
                          ]).animate(_likePop),
                          child: _HeroActionButton(
                            icon: _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            onTap: _toggleLike,
                            color: _isLiked
                                ? AppTheme.likeColor
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _HeroActionButton(
                          icon: AppIcons.share,
                          onTap: () => showRecipeShareOptions(
                            context: context,
                            recipeId: recipe.id,
                            recipeTitle: recipe.title,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recipe.isPrivate)
                    Positioned(
                      top: AppTheme.spacing12 + 44,
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
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF1A1A1A),
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 19, color: color),
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

class _HeroInfoPill extends StatelessWidget {
  const _HeroInfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
