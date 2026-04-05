import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../utils/extensions.dart';

/// Tappable like control with optimistic updates (shared by feed cards and rows).
class RecipeLikeButton extends ConsumerStatefulWidget {
  const RecipeLikeButton({
    super.key,
    required this.recipe,
    this.iconSize = 18,
    this.dense = false,
  });

  final Recipe recipe;
  final double iconSize;
  final bool dense;

  @override
  ConsumerState<RecipeLikeButton> createState() => _RecipeLikeButtonState();
}

class _RecipeLikeButtonState extends ConsumerState<RecipeLikeButton> {
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.recipe.isLiked ?? false;
    _likesCount = widget.recipe.likesCount;
  }

  @override
  void didUpdateWidget(covariant RecipeLikeButton oldWidget) {
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
    final padding = widget.dense
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppTheme.borderRadiusFull,
        onTap: _toggle,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                size: widget.iconSize,
                color: _isLiked ? AppTheme.likeColor : AppTheme.gray400,
              ),
              SizedBox(width: widget.dense ? 2 : AppTheme.spacing4),
              Text(
                '$_likesCount',
                style: context.textTheme.bodySmall?.copyWith(
                  color: _isLiked ? AppTheme.likeColor : AppTheme.gray500,
                  fontWeight: _isLiked ? FontWeight.w600 : FontWeight.w400,
                  fontSize: widget.dense ? 12 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
