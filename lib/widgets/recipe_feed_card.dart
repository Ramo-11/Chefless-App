import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import '../utils/app_icons.dart';
import '../utils/cloudinary_url.dart';
import '../utils/extensions.dart';
import 'recipe_compact_row.dart' show difficultyLabelColor;
import 'recipe_image_placeholder.dart';
import 'recipe_share_options_sheet.dart';

/// Full-width photo card for the home feed.
class RecipeFeedCard extends ConsumerStatefulWidget {
  const RecipeFeedCard({
    super.key,
    required this.recipe,
    this.useRootRoute = true,
  });

  final Recipe recipe;
  final bool useRootRoute;

  @override
  ConsumerState<RecipeFeedCard> createState() => _RecipeFeedCardState();
}

class _RecipeFeedCardState extends ConsumerState<RecipeFeedCard>
    with SingleTickerProviderStateMixin {
  bool _remixBusy = false;
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
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _likePop.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RecipeFeedCard oldWidget) {
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

  Future<void> _remix() async {
    final uid = ref.read(currentUserProvider).valueOrNull?.id;
    if (uid == null || widget.recipe.authorId == uid) return;
    HapticFeedback.lightImpact();
    setState(() => _remixBusy = true);
    final created = await ref
        .read(recipeActionProvider.notifier)
        .remix(widget.recipe.id);
    if (!mounted) return;
    setState(() => _remixBusy = false);
    if (created != null) {
      context.push('/recipe/${created.id}');
    }
  }

  void _share() {
    showRecipeShareOptions(
      context: context,
      recipeId: widget.recipe.id,
      recipeTitle: widget.recipe.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final hasPhoto = recipe.photos.isNotEmpty;
    final imageUrl = hasPhoto
        ? cloudinaryUrl(recipe.photos.first, width: 800, height: 500)
        : null;
    final uid = ref.watch(currentUserProvider).valueOrNull?.id;
    final isOwner = uid != null && recipe.authorId == uid;

    final categoryLabel = recipe.labels.isNotEmpty
        ? recipe.labels.first.toUpperCase()
        : recipe.dietaryTags.isNotEmpty
            ? recipe.dietaryTags.first.toUpperCase()
            : null;

    final cookMinutes = recipe.totalTime ?? recipe.cookTime;
    final cookLabel = cookMinutes != null
        ? (cookMinutes < 60
            ? '${cookMinutes}m'
            : '${cookMinutes ~/ 60}h ${cookMinutes % 60 > 0 ? '${cookMinutes % 60}m' : ''}')
        : null;

    const radius = 20.0;
    const cardRadius = BorderRadius.all(Radius.circular(radius));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: cardRadius,
          boxShadow: AppTheme.shadowCard,
        ),
        child: Material(
          color: AppTheme.surfaceElevated,
          borderRadius: cardRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _open,
            borderRadius: cardRadius,
            splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
            highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(radius),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 11,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasPhoto && imageUrl != null)
                          CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: AppTheme.gray100,
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
                            errorWidget: (_, _, _) => _PhotoPlaceholder(),
                          )
                        else
                          _PhotoPlaceholder(),

                        // Bottom scrim for legibility of overlaid pills + title contrast.
                        const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x00000000),
                                  Color(0x14000000),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (categoryLabel != null)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                categoryLabel,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ),

                        Positioned(
                          top: 10,
                          right: 10,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ScaleTransition(
                                scale: TweenSequence<double>([
                                  TweenSequenceItem(
                                    tween: Tween<double>(begin: 1, end: 1.28)
                                        .chain(
                                      CurveTween(curve: Curves.easeOutBack),
                                    ),
                                    weight: 45,
                                  ),
                                  TweenSequenceItem(
                                    tween: Tween<double>(begin: 1.28, end: 1)
                                        .chain(
                                      CurveTween(curve: Curves.easeIn),
                                    ),
                                    weight: 55,
                                  ),
                                ]).animate(_likePop),
                                child: _OverlayIconButton(
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
                              _OverlayIconButton(
                                icon: AppIcons.share,
                                onTap: _share,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
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
                        const SizedBox(width: AppTheme.spacing8),
                      ],
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryDeep,
                            letterSpacing: -0.35,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (recipe.authorName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: GestureDetector(
                      onTap: () => context.push('/user/${recipe.authorId}'),
                      child: Text(
                        'by ${recipe.authorName!}',
                        style: context.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: AppTheme.gray500,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
                  child: Row(
                    children: [
                      _MetaChip(
                        icon: Icons.favorite_rounded,
                        label: _compactCount(_likesCount),
                        iconColor: _isLiked
                            ? AppTheme.likeColor
                            : AppTheme.gray400,
                      ),
                      if (cookLabel != null) ...[
                        const SizedBox(width: AppTheme.spacing16),
                        _MetaChip(
                          icon: Icons.schedule_rounded,
                          label: cookLabel,
                        ),
                      ],
                      const Spacer(),
                      if (!isOwner) _RemixPill(busy: _remixBusy, onTap: _remix),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _compactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) {
    final v = (n / 1000).toStringAsFixed(1);
    return '${v.endsWith('.0') ? v.substring(0, v.length - 2) : v}k';
  }
  if (n < 1000000) return '${(n / 1000).round()}k';
  return '${(n / 1000000).toStringAsFixed(1)}m';
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor ?? AppTheme.gray400),
        const SizedBox(width: 5),
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            fontSize: 12.5,
            color: AppTheme.gray600,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class _RemixPill extends StatelessWidget {
  const _RemixPill({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accentPlayfulLight,
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.18),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(AppTheme.accentPlayful),
                  ),
                )
              else
                const Icon(
                  Icons.autorenew_rounded,
                  size: 15,
                  color: AppTheme.accentPlayful,
                ),
              const SizedBox(width: 5),
              Text(
                'Remix',
                style: context.textTheme.labelMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentPlayful,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const RecipeImagePlaceholder();
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}
