import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../models/user.dart';
import '../../providers/kitchen_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/extensions.dart';

/// Bottom sheet for adding a meal entry to the schedule.
///
/// Supports three tabs: My Recipes, Kitchen Members, and Freeform text.
class AddMealSheet extends ConsumerStatefulWidget {
  const AddMealSheet({
    super.key,
    required this.date,
    required this.mealSlot,
    this.replacingEntryId,
  });

  final DateTime date;
  final String mealSlot;
  final String? replacingEntryId;

  @override
  ConsumerState<AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<AddMealSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _freeformController = TextEditingController();
  bool _isSubmitting = false;

  // For the kitchen members tab: selected member
  String? _selectedMemberId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _freeformController.dispose();
    super.dispose();
  }

  Future<void> _submitRecipe(Recipe recipe) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final dateStr =
        DateTime(widget.date.year, widget.date.month, widget.date.day)
            .toIso8601String();

    bool success;
    if (widget.replacingEntryId != null) {
      // Delete old entry, then add new one
      await ref
          .read(scheduleActionProvider.notifier)
          .deleteEntry(widget.replacingEntryId!);
      success = await ref.read(scheduleActionProvider.notifier).addEntry(
            date: dateStr,
            mealSlot: widget.mealSlot,
            recipeId: recipe.id,
          );
    } else {
      success = await ref.read(scheduleActionProvider.notifier).addEntry(
            date: dateStr,
            mealSlot: widget.mealSlot,
            recipeId: recipe.id,
          );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        _showError();
      }
    }
  }

  Future<void> _submitFreeform() async {
    final text = _freeformController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final dateStr =
        DateTime(widget.date.year, widget.date.month, widget.date.day)
            .toIso8601String();

    bool success;
    if (widget.replacingEntryId != null) {
      await ref
          .read(scheduleActionProvider.notifier)
          .deleteEntry(widget.replacingEntryId!);
      success = await ref.read(scheduleActionProvider.notifier).addEntry(
            date: dateStr,
            mealSlot: widget.mealSlot,
            freeformText: text,
          );
    } else {
      success = await ref.read(scheduleActionProvider.notifier).addEntry(
            date: dateStr,
            mealSlot: widget.mealSlot,
            freeformText: text,
          );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        _showError();
      }
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to add meal. Please try again.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE, MMM d').format(widget.date);
    final slotLabel =
        '${widget.mealSlot[0].toUpperCase()}${widget.mealSlot.substring(1)}';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: AppTheme.spacingSm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.replacingEntryId != null
                              ? 'Replace Meal'
                              : 'Add Meal',
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$slotLabel - $dayLabel',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'My Recipes'),
                Tab(text: 'Members'),
                Tab(text: 'Freeform'),
              ],
            ),

            // Tab content
            Expanded(
              child: _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _MyRecipesTab(
                          scrollController: scrollController,
                          onSelect: _submitRecipe,
                        ),
                        _KitchenMembersTab(
                          scrollController: scrollController,
                          selectedMemberId: _selectedMemberId,
                          onMemberSelected: (id) {
                            setState(() => _selectedMemberId = id);
                          },
                          onSelect: _submitRecipe,
                        ),
                        _FreeformTab(
                          controller: _freeformController,
                          onSubmit: _submitFreeform,
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── My Recipes Tab ──────────────────────────────────────────────────────────

class _MyRecipesTab extends ConsumerWidget {
  const _MyRecipesTab({
    required this.scrollController,
    required this.onSelect,
  });

  final ScrollController scrollController;
  final void Function(Recipe) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(myRecipesProvider);

    return recipesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load recipes',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            OutlinedButton(
              onPressed: () => ref.invalidate(myRecipesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (recipes) {
        // Only show shared recipes (non-private).
        final shared = recipes.where((r) => !r.isPrivate).toList();

        if (shared.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 48,
                    color: context.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No shared recipes',
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    'Your shared recipes will appear here. Make sure your recipes are not set to private.',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          itemCount: shared.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppTheme.spacingSm),
          itemBuilder: (_, index) {
            return _RecipeListTile(
              recipe: shared[index],
              onTap: () => onSelect(shared[index]),
            );
          },
        );
      },
    );
  }
}

// ── Kitchen Members Tab ─────────────────────────────────────────────────────

class _KitchenMembersTab extends ConsumerWidget {
  const _KitchenMembersTab({
    required this.scrollController,
    required this.selectedMemberId,
    required this.onMemberSelected,
    required this.onSelect,
  });

  final ScrollController scrollController;
  final String? selectedMemberId;
  final void Function(String) onMemberSelected;
  final void Function(Recipe) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenAsync = ref.watch(myKitchenProvider);

    return kitchenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load kitchen members',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      ),
      data: (kitchenDetail) {
        if (kitchenDetail == null) {
          return const Center(child: Text('No kitchen found'));
        }

        final members = kitchenDetail.members;

        if (selectedMemberId == null) {
          return _MemberPicker(
            members: members,
            onSelect: onMemberSelected,
          );
        }

        return _MemberRecipesList(
          memberId: selectedMemberId!,
          scrollController: scrollController,
          onSelect: onSelect,
          onBack: () => onMemberSelected(''),
        );
      },
    );
  }
}

class _MemberPicker extends StatelessWidget {
  const _MemberPicker({
    required this.members,
    required this.onSelect,
  });

  final List<CheflessUser> members;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          'No members in this kitchen.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: members.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacingSm),
      itemBuilder: (_, index) {
        final member = members[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: member.profilePicture != null
                ? CachedNetworkImageProvider(member.profilePicture!)
                : null,
            child: member.profilePicture == null
                ? Text(member.fullName.isNotEmpty
                    ? member.fullName[0].toUpperCase()
                    : '?')
                : null,
          ),
          title: Text(member.fullName),
          subtitle: Text('${member.recipesCount} recipes'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onSelect(member.id),
          shape: const RoundedRectangleBorder(
            borderRadius: AppTheme.borderRadiusSmall,
          ),
        );
      },
    );
  }
}

class _MemberRecipesList extends ConsumerWidget {
  const _MemberRecipesList({
    required this.memberId,
    required this.scrollController,
    required this.onSelect,
    required this.onBack,
  });

  final String memberId;
  final ScrollController scrollController;
  final void Function(Recipe) onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(
      kitchenRecipesProvider(
        KitchenRecipesParams(memberId: memberId),
      ),
    );

    return Column(
      children: [
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('All members'),
          ),
        ),

        Expanded(
          child: recipesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Failed to load recipes',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ),
            data: (recipes) {
              if (recipes.isEmpty) {
                return Center(
                  child: Text(
                    'This member has no shared recipes.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                ),
                itemCount: recipes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppTheme.spacingSm),
                itemBuilder: (_, index) {
                  return _RecipeListTile(
                    recipe: recipes[index],
                    onTap: () => onSelect(recipes[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Freeform Tab ────────────────────────────────────────────────────────────

class _FreeformTab extends StatelessWidget {
  const _FreeformTab({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you having?',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Enter a short description for this meal slot.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g., Leftovers, Eating out, Salad...',
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 100,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSubmit,
              child: const Text('Add to Schedule'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Recipe List Tile ─────────────────────────────────────────────────

class _RecipeListTile extends StatelessWidget {
  const _RecipeListTile({
    required this.recipe,
    required this.onTap,
  });

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusSmall,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        decoration: BoxDecoration(
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          borderRadius: AppTheme.borderRadiusSmall,
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.all(Radius.circular(AppTheme.radiusSmall)),
              child: recipe.photos.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: recipe.photos.first,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 48,
                        height: 48,
                        color: context.colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => _recipePlaceholder(context),
                    )
                  : _recipePlaceholder(context),
            ),

            const SizedBox(width: AppTheme.spacingSm),

            // Title & metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (recipe.totalTime != null || recipe.cookTime != null)
                    Text(
                      '${recipe.totalTime ?? recipe.cookTime} min',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),

            Icon(
              Icons.add_circle_outline,
              color: context.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipePlaceholder(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: context.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant_menu,
        size: 24,
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
