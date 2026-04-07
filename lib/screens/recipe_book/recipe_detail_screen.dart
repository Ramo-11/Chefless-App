import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/fraction_utils.dart';
import '../../widgets/ingredient_scaling.dart';
import '../../widgets/photo_carousel.dart';
import '../../widgets/report_sheet.dart';
import '../../widgets/signature_overlay.dart';
import '../../widgets/user_avatar.dart';
import 'share_recipe_sheet.dart';

const _scheduleRecipeDefaultSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

/// Full recipe detail screen with photo carousel, ingredients, steps,
/// serving adjuster, and action bar.
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _adjustedServings;
  bool? _localIsLiked;
  int? _localLikesCount;
  bool? _localIsPrivate;
  bool _isUpdatingPrivacy = false;

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return recipeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 28,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                Text(
                  'Failed to load recipe',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing24),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(recipeDetailProvider(widget.recipeId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (recipe) {
        final servings = _adjustedServings ?? recipe.servings ?? recipe.baseServings;
        final isOwner = currentUser?.id == recipe.authorId;
        final isLiked = _localIsLiked ?? (recipe.isLiked ?? false);
        final likesCount = _localLikesCount ?? recipe.likesCount;
        final isPrivate = _localIsPrivate ?? recipe.isPrivate;
        final isScaled = _adjustedServings != null &&
            _adjustedServings != recipe.baseServings;

        // Build the signature overlay if applicable.
        Widget? signatureOverlay;
        if (recipe.showSignature && currentUser?.signature != null) {
          signatureOverlay =
              SignatureOverlay(signatureUrl: currentUser!.signature!);
        }

        void onLikeToggle() {
          final currentCount = _localLikesCount ?? recipe.likesCount;
          if (mounted) {
            setState(() {
              _localIsLiked = !isLiked;
              _localLikesCount = currentCount + (isLiked ? -1 : 1);
            });
          }
          if (isLiked) {
            ref.read(recipeActionProvider.notifier).unlike(recipe.id);
          } else {
            ref.read(recipeActionProvider.notifier).like(recipe.id);
          }
        }

        return Scaffold(
          backgroundColor: AppTheme.surfaceWarm,
          body: CustomScrollView(
            slivers: [
              // ── Hero photo ────────────────────────────────────────
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.4,
                pinned: true,
                stretch: true,
                backgroundColor: AppTheme.surfaceWarm,
                leading: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                actions: [
                  if (isOwner)
                    Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: AppTheme.spacing8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                          onPressed: () => context.push('/recipe/${recipe.id}/edit'),
                          padding: EdgeInsets.zero,
                          tooltip: 'Edit recipe',
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: PhotoCarousel(
                    photos: recipe.photos,
                    height: 410,
                    overlayWidget: signatureOverlay,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title & Author ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing20,
                        AppTheme.spacing24,
                        AppTheme.spacing20,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.title,
                            style: AppTheme.displayTitleMedium().copyWith(
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing8),

                          // Author row
                          if (recipe.authorName != null && !isOwner)
                            GestureDetector(
                              onTap: () => context.push('/user/${recipe.authorId}'),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: AppTheme.spacing4,
                                  bottom: AppTheme.spacing4,
                                ),
                                child: Row(
                                  children: [
                                    UserAvatar(
                                      fullName: recipe.authorName!,
                                      profilePictureUrl: recipe.authorPhoto,
                                      size: 32,
                                    ),
                                    const SizedBox(width: AppTheme.spacing8),
                                    Expanded(
                                      child: Text(
                                        recipe.authorName!,
                                        style: context.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.gray700,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppTheme.gray400,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (recipe.authorName != null && isOwner)
                            Text(
                              'By you',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.gray500,
                              ),
                            ),

                          // Fork source
                          if (recipe.forkedFrom != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppTheme.spacing4),
                              child: GestureDetector(
                                onTap: () => context.push(
                                    '/recipe/${recipe.forkedFrom!.recipeId}'),
                                child: Text(
                                  'Remixed from @${recipe.forkedFrom!.authorName}',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),

                          // Status chips (only non-visibility badges)
                          if (recipe.isModifiedFork) ...[
                            const SizedBox(height: AppTheme.spacing12),
                            _RecipeStatusChip(
                              icon: Icons.autorenew_rounded,
                              label: 'Modified remix',
                              color: AppTheme.primaryColor,
                            ),
                          ],

                          // Tags
                          if (recipe.labels.isNotEmpty ||
                              recipe.dietaryTags.isNotEmpty ||
                              recipe.cuisineTags.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacing12),
                            _TagChips(recipe: recipe),
                          ],
                        ],
                      ),
                    ),

                    // ── Quick Stats Card ────────────────────────────
                    _QuickStatsCard(recipe: recipe),

                    // ── Description, Story & Actions Card ────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: AppTheme.borderRadiusXL,
                          boxShadow: AppTheme.shadowSubtle,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description
                            if (recipe.description != null &&
                                recipe.description!.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing4,
                                ),
                                child: Text(
                                  recipe.description!,
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.gray600,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacing12),
                            ],

                            // Story
                            if (recipe.story != null &&
                                recipe.story!.isNotEmpty) ...[
                              _CollapsibleStory(story: recipe.story!),
                              const SizedBox(height: AppTheme.spacing12),
                            ],

                            // Visibility row
                            if ((recipe.description != null &&
                                    recipe.description!.isNotEmpty) ||
                                (recipe.story != null &&
                                    recipe.story!.isNotEmpty))
                              Divider(color: AppTheme.gray100, height: AppTheme.spacing4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing4,
                                vertical: AppTheme.spacing4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isPrivate
                                        ? Icons.lock_outline_rounded
                                        : Icons.public_rounded,
                                    size: 16,
                                    color: isPrivate
                                        ? AppTheme.accentPlayful
                                        : AppTheme.success,
                                  ),
                                  const SizedBox(width: AppTheme.spacing6),
                                  Expanded(
                                    child: Text(
                                      isPrivate ? 'Private' : 'Public',
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: AppTheme.gray700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isOwner)
                                    SizedBox(
                                      height: 28,
                                      child: FittedBox(
                                        child: Switch(
                                          value: !isPrivate,
                                          onChanged: _isUpdatingPrivacy
                                              ? null
                                              : (_) =>
                                                  _togglePrivacy(recipe, isPrivate),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Divider before actions
                            Divider(color: AppTheme.gray100, height: AppTheme.spacing4),

                            // Action row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _InlineAction(
                                  icon: isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_outline_rounded,
                                  label: '$likesCount',
                                  color: isLiked ? AppTheme.likeColor : null,
                                  onTap: onLikeToggle,
                                ),
                                _InlineAction(
                                  icon: isOwner
                                      ? Icons.copy_outlined
                                      : Icons.autorenew_rounded,
                                  label: isOwner
                                      ? 'Copy'
                                      : '${recipe.forksCount}',
                                  onTap: isOwner
                                      ? () => _onDuplicate(recipe)
                                      : () => _onFork(recipe),
                                ),
                                _InlineAction(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Plan',
                                  onTap: () => _showScheduleSheet(recipe),
                                ),
                                _InlineAction(
                                  icon: Icons.share_outlined,
                                  label: 'Share',
                                  onTap: () => _onShare(recipe),
                                ),
                                if (isOwner)
                                  _InlineAction(
                                    icon: Icons.delete_outline_rounded,
                                    label: 'Delete',
                                    color: AppTheme.error,
                                    onTap: () => _confirmDelete(recipe),
                                  ),
                                if (!isOwner)
                                  _InlineAction(
                                    icon: Icons.flag_outlined,
                                    label: 'Report',
                                    onTap: () => _showReportSheet(recipe),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // ── Ingredients Card ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacing20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: AppTheme.borderRadiusXL,
                          boxShadow: AppTheme.shadowSubtle,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.restaurant_outlined,
                                  size: 20,
                                  color: AppTheme.accentPlayful,
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                                Expanded(
                                  child: Text(
                                    'Ingredients',
                                    style: AppTheme.displayTitleSmall(),
                                  ),
                                ),
                                IngredientScaling(
                                  currentServings: servings,
                                  baseServings: recipe.baseServings,
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() => _adjustedServings = value);
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (isScaled) ...[
                              const SizedBox(height: AppTheme.spacing8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing12,
                                  vertical: AppTheme.spacing4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: AppTheme.borderRadiusFull,
                                ),
                                child: Text(
                                  'Scaled to $servings servings (base: ${recipe.baseServings})',
                                  style: context.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppTheme.spacing16),
                            _IngredientsList(
                              ingredients: recipe.ingredients,
                              baseServings: recipe.baseServings,
                              currentServings: servings,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing16),

                    // ── Steps Card ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacing20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: AppTheme.borderRadiusXL,
                          boxShadow: AppTheme.shadowSubtle,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.format_list_numbered_rounded,
                                  size: 20,
                                  color: AppTheme.accentPlayful,
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                                Text(
                                  'Steps',
                                  style: AppTheme.displayTitleSmall(),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacing16),
                            _StepsList(steps: recipe.steps),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportSheet(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ReportSheet(
        targetType: 'recipe',
        targetId: recipe.id,
      ),
    );
  }

  void _confirmDelete(Recipe recipe) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${recipe.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pop();
              ref
                  .read(recipeActionProvider.notifier)
                  .deleteRecipe(recipe.id);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onFork(Recipe recipe) async {
    final forked =
        await ref.read(recipeActionProvider.notifier).fork(recipe.id);
    if (forked != null && mounted) {
      context.push('/recipe/${forked.id}');
    }
  }

  Future<void> _onDuplicate(Recipe recipe) async {
    final forked =
        await ref.read(recipeActionProvider.notifier).fork(recipe.id);
    if (forked != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated "${recipe.title}"'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => context.push('/recipe/${forked.id}'),
          ),
        ),
      );
    }
  }

  void _onShare(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ShareRecipeSheet(recipeId: recipe.id),
    );
  }

  Future<void> _showScheduleSheet(Recipe recipe) async {
    var kitchenDetail = ref.read(myKitchenProvider).valueOrNull;
    if (kitchenDetail == null) {
      try {
        kitchenDetail = await ref.read(myKitchenProvider.future);
      } catch (_) {
        kitchenDetail = null;
      }
    }
    if (kitchenDetail == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Join or create a kitchen to use meal scheduling.'),
          action: SnackBarAction(
            label: 'Kitchen',
            onPressed: () => context.push('/kitchen'),
          ),
        ),
      );
      return;
    }

    final mealSlots = {
      ..._scheduleRecipeDefaultSlots,
      ...kitchenDetail.kitchen.customMealSlots
          .map((slot) => slot.trim())
          .where((slot) => slot.isNotEmpty),
    }.toList();

    DateTime selectedDate = DateTime.now();
    String selectedSlot = mealSlots.first;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final dayLabel = DateFormat('EEE, MMM d').format(selectedDate);
            return Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacing20,
                right: AppTheme.spacing20,
                top: AppTheme.spacing8,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
                    AppTheme.spacing20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'Add to schedule',
                    style: AppTheme.displayTitleSmall(),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'Plan "${recipe.title}" for a day and meal slot in your kitchen calendar.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray500,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing20),
                  InkWell(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: sheetContext,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 180),
                              ),
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDate = picked);
                            }
                          },
                    borderRadius: AppTheme.borderRadiusLarge,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: AppTheme.borderRadiusLarge,
                        border: Border.all(color: AppTheme.gray200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentPlayfulLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: AppTheme.accentPlayful,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Day',
                                  style: context.textTheme.labelMedium?.copyWith(
                                    color: AppTheme.gray500,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacing2),
                                Text(
                                  dayLabel,
                                  style: context.textTheme.titleSmall?.copyWith(
                                    color: AppTheme.textPrimaryDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.gray400,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    'Meal slot',
                    style: context.textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimaryDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Wrap(
                    spacing: AppTheme.spacing8,
                    runSpacing: AppTheme.spacing8,
                    children: mealSlots.map((slot) {
                      final isSelected = slot == selectedSlot;
                      final label =
                          '${slot[0].toUpperCase()}${slot.substring(1)}';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: isSubmitting
                            ? null
                            : (_) => setSheetState(() => selectedSlot = slot),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacing20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              final success = await ref
                                  .read(scheduleActionProvider.notifier)
                                  .addEntry(
                                    date: DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                    ).toIso8601String(),
                                    mealSlot: selectedSlot,
                                    recipeId: recipe.id,
                                  );

                              if (!mounted) return;
                              if (success) {
                                Navigator.of(sheetContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added "${recipe.title}" to $dayLabel.',
                                    ),
                                    action: SnackBarAction(
                                      label: 'View',
                                      onPressed: () => context.go('/schedule'),
                                    ),
                                  ),
                                );
                              } else {
                                setSheetState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to add meal to schedule.'),
                                  ),
                                );
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(isSubmitting ? 'Adding...' : 'Add to Schedule'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentPlayful,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _togglePrivacy(Recipe recipe, bool currentValue) async {
    if (_isUpdatingPrivacy) return;

    final nextValue = !currentValue;
    if (mounted) {
      setState(() {
        _isUpdatingPrivacy = true;
        _localIsPrivate = nextValue;
      });
    }

    final updated = await ref
        .read(recipeActionProvider.notifier)
        .update(recipe.id, {'isPrivate': nextValue});

    if (!mounted) return;
    if (updated == null) {
      setState(() => _localIsPrivate = currentValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update recipe visibility.')),
      );
    } else {
      setState(() => _localIsPrivate = updated.isPrivate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isPrivate
                ? 'Recipe is now private.'
                : 'Recipe is now public.',
          ),
        ),
      );
    }
    setState(() => _isUpdatingPrivacy = false);
  }
}

class _CollapsibleStory extends StatefulWidget {
  const _CollapsibleStory({required this.story});

  final String story;

  @override
  State<_CollapsibleStory> createState() => _CollapsibleStoryState();
}

class _CollapsibleStoryState extends State<_CollapsibleStory>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.gray200),
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: _isExpanded
                ? const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusMedium),
                    topRight: Radius.circular(AppTheme.radiusMedium),
                  )
                : AppTheme.borderRadiusMedium,
            onTap: () {
              if (mounted) setState(() => _isExpanded = !_isExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      'Read the story behind this recipe',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                0,
                AppTheme.spacing16,
                AppTheme.spacing16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: AppTheme.gray100),
                  const SizedBox(height: AppTheme.spacing12),
                  Text(
                    widget.story,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray600,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _TagChips extends StatelessWidget {
  const _TagChips({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final hasLabels = recipe.labels.isNotEmpty;
    final hasDietary = recipe.dietaryTags.isNotEmpty;
    final hasCuisine = recipe.cuisineTags.isNotEmpty;

    if (!hasLabels && !hasDietary && !hasCuisine) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AppTheme.spacing6,
      runSpacing: AppTheme.spacing6,
      children: [
        if (hasLabels)
          ...recipe.labels.map((tag) => _buildChip(context, tag, AppTheme.gray50, AppTheme.gray700)),
        if (hasDietary)
          ...recipe.dietaryTags.map((tag) => _buildChip(context, tag, AppTheme.primaryLight, AppTheme.primaryDark)),
        if (hasCuisine)
          ...recipe.cuisineTags.map((tag) => _buildChip(context, tag, AppTheme.gray100, AppTheme.gray600)),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String tag,
      Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: Text(
        tag,
        style: context.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final stats = <_StatItem>[];

    if (recipe.totalTime != null) {
      stats.add(_StatItem(
        icon: Icons.schedule_rounded,
        value: '${recipe.totalTime}',
        unit: 'min',
      ));
    } else {
      if (recipe.prepTime != null) {
        stats.add(_StatItem(
          icon: Icons.timer_outlined,
          value: '${recipe.prepTime}',
          unit: 'prep',
        ));
      }
      if (recipe.cookTime != null) {
        stats.add(_StatItem(
          icon: Icons.local_fire_department_outlined,
          value: '${recipe.cookTime}',
          unit: 'cook',
        ));
      }
    }
    if (recipe.difficulty != null) {
      stats.add(_StatItem(
        icon: Icons.signal_cellular_alt,
        value: recipe.difficulty!,
        unit: '',
      ));
    }
    if (recipe.calories != null) {
      stats.add(_StatItem(
        icon: Icons.bolt_outlined,
        value: '${recipe.calories}',
        unit: 'cal',
      ));
    }
    if (recipe.costEstimate != null) {
      stats.add(_StatItem(
        icon: Icons.attach_money_rounded,
        value: recipe.costEstimate!,
        unit: '',
      ));
    }

    if (stats.isEmpty) return const SizedBox(height: AppTheme.spacing16);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing20,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing16,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowSubtle,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.gray200,
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      stats[i].icon,
                      size: 18,
                      color: AppTheme.accentPlayful,
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    Text(
                      stats[i].value,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryDeep,
                      ),
                    ),
                    if (stats[i].unit.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        stats[i].unit,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: AppTheme.gray500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String value;
  final String unit;
}

class _RecipeStatusChip extends StatelessWidget {
  const _RecipeStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Owner/Viewer action panels removed — consolidated into _BottomBar.

class _IngredientsList extends StatefulWidget {
  const _IngredientsList({
    required this.ingredients,
    required this.baseServings,
    required this.currentServings,
  });

  final List<Ingredient> ingredients;
  final int baseServings;
  final int currentServings;

  @override
  State<_IngredientsList> createState() => _IngredientsListState();
}

class _IngredientsListState extends State<_IngredientsList> {
  final Set<int> _checked = {};

  @override
  Widget build(BuildContext context) {
    if (widget.ingredients.isEmpty) {
      return Text(
        'No ingredients listed.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: AppTheme.gray500,
        ),
      );
    }

    // Group ingredients by their group field.
    final grouped = <String?, List<Ingredient>>{};
    for (final ingredient in widget.ingredients) {
      grouped.putIfAbsent(ingredient.group, () => []).add(ingredient);
    }

    final widgets = <Widget>[];
    var flatIndex = 0;
    for (final entry in grouped.entries) {
      if (entry.key != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spacing16,
              bottom: AppTheme.spacing8,
            ),
            child: Text(
              entry.key!,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
      }

      for (final ingredient in entry.value) {
        final idx = flatIndex;
        final isChecked = _checked.contains(idx);
        final scaledQty = scaleQuantity(
            ingredient.quantity, widget.baseServings, widget.currentServings);
        widgets.add(
          InkWell(
            borderRadius: AppTheme.borderRadiusSmall,
            onTap: () {
              setState(() {
                if (isChecked) {
                  _checked.remove(idx);
                } else {
                  _checked.add(idx);
                }
              });
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: isChecked,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _checked.add(idx);
                          } else {
                            _checked.remove(idx);
                          }
                        });
                      },
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: context.textTheme.bodyMedium?.copyWith(
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : null,
                          color: isChecked
                              ? AppTheme.gray400
                              : AppTheme.gray900,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${formatQuantity(scaledQty)} ${ingredient.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          TextSpan(
                            text: '  ${ingredient.name}',
                            style: TextStyle(
                              color: isChecked
                                  ? AppTheme.gray400
                                  : AppTheme.gray700,
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
        );
        flatIndex++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _StepsList extends StatefulWidget {
  const _StepsList({required this.steps});

  final List<RecipeStep> steps;

  @override
  State<_StepsList> createState() => _StepsListState();
}

class _StepsListState extends State<_StepsList> {
  final Set<int> _completed = {};

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return Text(
        'No steps listed.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: AppTheme.gray500,
        ),
      );
    }

    final sorted = List<RecipeStep>.from(widget.steps)
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      children: sorted.map((step) {
        final isDone = _completed.contains(step.order);
        return InkWell(
          borderRadius: AppTheme.borderRadiusSmall,
          onTap: () {
            setState(() {
              if (isDone) {
                _completed.remove(step.order);
              } else {
                _completed.add(step.order);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: isDone,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _completed.add(step.order);
                        } else {
                          _completed.remove(step.order);
                        }
                      });
                    },
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.instruction,
                        style: context.textTheme.bodyMedium?.copyWith(
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                          color: isDone
                              ? AppTheme.gray400
                              : AppTheme.gray800,
                          height: 1.5,
                        ),
                      ),
                      if (step.photo != null) ...[
                        const SizedBox(height: AppTheme.spacing8),
                        ClipRRect(
                          borderRadius: AppTheme.borderRadiusMedium,
                          child: Image.network(
                            step.photo!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppTheme.borderRadiusMedium,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: color ?? AppTheme.gray500,
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: color ?? AppTheme.gray500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
