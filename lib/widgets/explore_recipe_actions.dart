import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe.dart';
import '../providers/auth_provider.dart';
import '../providers/recipe_provider.dart';
import 'recipe_share_options_sheet.dart';
import '../utils/app_icons.dart';
import '../utils/extensions.dart';
import 'recipe_like_button.dart';

/// Like, remix count, share, and remix action for Home feed rows.
///
/// [compact] tucks share/remix into an overflow menu for calmer list rhythm;
/// the featured hero row should use the default full layout.
class ExploreRecipeActions extends ConsumerStatefulWidget {
  const ExploreRecipeActions({
    super.key,
    required this.recipe,
    this.compact = false,
  });

  final Recipe recipe;
  final bool compact;

  @override
  ConsumerState<ExploreRecipeActions> createState() =>
      _ExploreRecipeActionsState();
}

class _ExploreRecipeActionsState extends ConsumerState<ExploreRecipeActions> {
  bool _remixBusy = false;

  Future<void> _remix() async {
    final uid = ref.read(currentUserProvider).valueOrNull?.id;
    if (uid == null) return;
    if (widget.recipe.authorId == uid) return;
    setState(() => _remixBusy = true);
    final created =
        await ref.read(recipeActionProvider.notifier).remix(widget.recipe.id);
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
    final uid = ref.watch(currentUserProvider).valueOrNull?.id;
    final isOwner = uid != null && widget.recipe.authorId == uid;
    final mealLabel =
        widget.recipe.labels.isNotEmpty ? widget.recipe.labels.first : null;
    final dietLabel = widget.recipe.dietaryTags.isNotEmpty
        ? widget.recipe.dietaryTags.first
        : null;

    final bottomPad = widget.compact ? 8.0 : 12.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mealLabel != null || dietLabel != null)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (mealLabel != null)
                  Chip(
                    label: Text(mealLabel, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (dietLabel != null)
                  Chip(
                    label: Text(dietLabel, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          Row(
            children: [
              RecipeLikeButton(recipe: widget.recipe, dense: true),
              const SizedBox(width: 8),
              Icon(Icons.autorenew, size: 14, color: AppTheme.gray500),
              const SizedBox(width: 4),
              Text(
                '${widget.recipe.forksCount}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: AppTheme.gray600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!isOwner)
                TextButton.icon(
                  onPressed: _remixBusy ? null : _remix,
                  icon: _remixBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.autorenew, size: 18),
                  label: const Text('Remix'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentPlayful,
                  ),
                ),
              IconButton(
                tooltip: 'Share',
                onPressed: _share,
                icon: const Icon(AppIcons.share, size: 20),
                color: AppTheme.gray700,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
