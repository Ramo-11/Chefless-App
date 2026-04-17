import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/kitchen.dart';
import '../../models/recipe.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/schedule_provider.dart';

/// Bottom sheet for adding a meal entry to the schedule.
///
/// Three tabs: My Recipes, Kitchen Members, Freeform.
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
  TabController? _tabController;
  final _freeformController = TextEditingController();
  bool _isSubmitting = false;
  bool? _lastHasKitchen;
  TimeOfDay? _scheduledTime;

  String? _selectedMemberId;

  void _ensureTabController(bool hasKitchen) {
    if (_lastHasKitchen == hasKitchen && _tabController != null) return;
    _tabController?.dispose();
    _tabController = TabController(
      length: hasKitchen ? 3 : 2,
      vsync: this,
    );
    _lastHasKitchen = hasKitchen;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _freeformController.dispose();
    super.dispose();
  }

  String? get _formattedTime {
    if (_scheduledTime == null) return null;
    final h = _scheduledTime!.hour.toString().padLeft(2, '0');
    final m = _scheduledTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => _scheduledTime = picked);
    }
  }

  Future<void> _submitRecipe(Recipe recipe) async {
    if (_isSubmitting) return;
    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

    bool success;
    if (widget.replacingEntryId != null) {
      await ref
          .read(scheduleActionProvider.notifier)
          .deleteEntry(widget.replacingEntryId!);
      success = await ref.read(scheduleActionProvider.notifier).addEntry(
            date: dateStr,
            mealSlot: widget.mealSlot,
            recipeId: recipe.id,
            scheduledTime: _formattedTime,
          );
    } else {
      success = await ref.read(scheduleActionProvider.notifier).addEntry(
            date: dateStr,
            mealSlot: widget.mealSlot,
            recipeId: recipe.id,
            scheduledTime: _formattedTime,
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

    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

    bool success;
    if (widget.replacingEntryId != null) {
      await ref
          .read(scheduleActionProvider.notifier)
          .deleteEntry(widget.replacingEntryId!);
      success = await ref.read(scheduleActionProvider.notifier).addEntry(
            date: dateStr,
            mealSlot: widget.mealSlot,
            freeformText: text,
            scheduledTime: _formattedTime,
          );
    } else {
      success = await ref.read(scheduleActionProvider.notifier).addEntry(
            date: dateStr,
            mealSlot: widget.mealSlot,
            freeformText: text,
            scheduledTime: _formattedTime,
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

  bool _entryBecomesSuggestion(Kitchen? kitchen, String? userId) {
    if (kitchen == null || userId == null) return false;
    if (kitchen.scheduleAddPolicy != 'lead_only') return false;
    final isLead = kitchen.leadId == userId;
    final isEditor = kitchen.membersWithScheduleEdit.contains(userId);
    return !(isLead || isEditor);
  }

  @override
  Widget build(BuildContext context) {
    final kitchenAsync = ref.watch(myKitchenProvider);
    final hasKitchen = kitchenAsync.valueOrNull != null;
    final kitchen = kitchenAsync.valueOrNull?.kitchen;
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
    final willSuggest = _entryBecomesSuggestion(kitchen, currentUserId);
    _ensureTabController(hasKitchen);

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
            const SizedBox(height: AppTheme.spacing12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.replacingEntryId != null
                              ? 'Replace Meal'
                              : (willSuggest ? 'Suggest a Meal' : 'Add a Meal'),
                          style: AppTheme.displayTitleSmall().copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPlayfulLight,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull,
                            ),
                          ),
                          child: Text(
                            '$slotLabel  ·  $dayLabel',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                              color: AppTheme.accentPlayful,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: AppTheme.gray50,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      splashColor:
                          AppTheme.accentPlayful.withValues(alpha: 0.1),
                      highlightColor:
                          AppTheme.accentPlayful.withValues(alpha: 0.05),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppTheme.gray600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (willSuggest) ...[
              const SizedBox(height: AppTheme.spacing12),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing20,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.infoLight,
                    borderRadius: AppTheme.borderRadiusMedium,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: AppTheme.info,
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          'This will be sent as a suggestion. The kitchen '
                          'lead or an approver must confirm before it appears '
                          'on the schedule.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.gray700,
                            letterSpacing: -0.1,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacing12),

            // Time picker (soft, no harsh border)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: AppTheme.borderRadiusMedium,
                  splashColor:
                      AppTheme.accentPlayful.withValues(alpha: 0.08),
                  highlightColor:
                      AppTheme.accentPlayful.withValues(alpha: 0.04),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      borderRadius: AppTheme.borderRadiusMedium,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: _scheduledTime != null
                              ? AppTheme.accentPlayful
                              : AppTheme.gray500,
                        ),
                        const SizedBox(width: AppTheme.spacing10),
                        Expanded(
                          child: Text(
                            _scheduledTime != null
                                ? _scheduledTime!.format(context)
                                : 'Set a time (optional)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: _scheduledTime != null
                                  ? AppTheme.gray900
                                  : AppTheme.gray500,
                            ),
                          ),
                        ),
                        if (_scheduledTime != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _scheduledTime = null),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppTheme.gray500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Tab bar — premium pill indicator
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.gray100.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.accentPlayful,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPlayful.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.gray600,
                  labelPadding: EdgeInsets.zero,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                  tabs: [
                    const Tab(text: 'My Recipes', height: 36),
                    if (hasKitchen) const Tab(text: 'Members', height: 36),
                    const Tab(text: 'Freeform', height: 36),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),

            Expanded(
              child: _isSubmitting
                  ? const _BrandedLoader()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _MyRecipesTab(
                          scrollController: scrollController,
                          onSelect: _submitRecipe,
                        ),
                        if (hasKitchen)
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
                          willSuggest: willSuggest,
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

// ── Branded Loader ─────────────────────────────────────────────────────────

class _BrandedLoader extends StatelessWidget {
  const _BrandedLoader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(AppTheme.accentPlayful),
        ),
      ),
    );
  }
}

// ── My Recipes Tab ─────────────────────────────────────────────────────────

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
      loading: () => const _BrandedLoader(),
      error: (error, _) => _SheetErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(myRecipesProvider),
      ),
      data: (recipes) {
        final shared = recipes.where((r) => !r.isPrivate).toList();

        if (shared.isEmpty) {
          return const _SheetEmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No shared recipes',
            subtitle:
                'Your shared recipes will appear here. Make sure your recipes are not set to private.',
          );
        }

        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            AppTheme.spacing24,
          ),
          itemCount: shared.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppTheme.spacing10),
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

// ── Kitchen Members Tab ────────────────────────────────────────────────────

class _KitchenMembersTab extends ConsumerWidget {
  const _KitchenMembersTab({
    required this.scrollController,
    required this.selectedMemberId,
    required this.onMemberSelected,
    required this.onSelect,
  });

  final ScrollController scrollController;
  final String? selectedMemberId;
  final void Function(String?) onMemberSelected;
  final void Function(Recipe) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenAsync = ref.watch(myKitchenProvider);

    return kitchenAsync.when(
      loading: () => const _BrandedLoader(),
      error: (error, _) => _SheetErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(myKitchenProvider),
      ),
      data: (kitchenDetail) {
        if (kitchenDetail == null) {
          return const _SheetEmptyState(
            icon: Icons.kitchen_outlined,
            title: 'No kitchen yet',
            subtitle: "You're not part of a kitchen.",
          );
        }

        final members = kitchenDetail.members;

        if (selectedMemberId == null) {
          return _MemberPicker(members: members, onSelect: onMemberSelected);
        }

        return _MemberRecipesList(
          memberId: selectedMemberId!,
          scrollController: scrollController,
          onSelect: onSelect,
          onBack: () => onMemberSelected(null),
        );
      },
    );
  }
}

class _MemberPicker extends StatelessWidget {
  const _MemberPicker({required this.members, required this.onSelect});

  final List<CheflessUser> members;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const _SheetEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No members yet',
        subtitle: 'There are no members in this kitchen.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing24,
      ),
      itemCount: members.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppTheme.spacing10),
      itemBuilder: (_, index) {
        final member = members[index];
        return _MemberCard(member: member, onTap: () => onSelect(member.id));
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.onTap});

  final CheflessUser member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
          highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.accentPlayfulLight,
                  foregroundColor: AppTheme.accentPlayful,
                  backgroundImage: member.profilePicture != null
                      ? CachedNetworkImageProvider(member.profilePicture!)
                      : null,
                  child: member.profilePicture == null
                      ? Text(
                          member.fullName.isNotEmpty
                              ? member.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppTheme.gray900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${member.recipesCount} '
                        '${member.recipesCount == 1 ? 'recipe' : 'recipes'}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.gray400,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
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
      kitchenRecipesProvider(KitchenRecipesParams(memberId: memberId)),
    );

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: AppTheme.spacing8),
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('All members'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentPlayful,
              ),
            ),
          ),
        ),
        Expanded(
          child: recipesAsync.when(
            loading: () => const _BrandedLoader(),
            error: (error, _) => _SheetErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(
                kitchenRecipesProvider(
                  KitchenRecipesParams(memberId: memberId),
                ),
              ),
            ),
            data: (recipes) {
              if (recipes.isEmpty) {
                return const _SheetEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No shared recipes',
                  subtitle: 'This member has no shared recipes yet.',
                );
              }
              return ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  0,
                  AppTheme.spacing16,
                  AppTheme.spacing24,
                ),
                itemCount: recipes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.spacing10),
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

// ── Freeform Tab ───────────────────────────────────────────────────────────

class _FreeformTab extends StatelessWidget {
  const _FreeformTab({
    required this.controller,
    required this.onSubmit,
    required this.willSuggest,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool willSuggest;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        AppTheme.spacing12,
        AppTheme.spacing20,
        AppTheme.spacing24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you having?',
            style: AppTheme.displayTitleSmall().copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            'Enter a short description for this meal slot.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g., Leftovers, Eating out, Salad...',
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 100,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppTheme.spacing12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentPlayful,
              ),
              onPressed: onSubmit,
              child: Text(
                willSuggest ? 'Send as suggestion' : 'Add to schedule',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recipe List Tile ───────────────────────────────────────────────────────

class _RecipeListTile extends StatelessWidget {
  const _RecipeListTile({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
          highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: recipe.photos.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: recipe.photos.first,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _placeholder(),
                          errorWidget: (_, _, _) => _fallback(),
                        )
                      : _fallback(),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppTheme.gray900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (recipe.totalTime != null || recipe.cookTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 12.5,
                                color: AppTheme.gray500,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${recipe.totalTime ?? recipe.cookTime} min',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                  color: AppTheme.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPlayful,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPlayful.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.ramen_dining_rounded,
        size: 22,
        color: AppTheme.gray400,
      ),
    );
  }
}

// ── Sheet Empty / Error ────────────────────────────────────────────────────

class _SheetEmptyState extends StatelessWidget {
  const _SheetEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppTheme.gray500),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              title,
              style: AppTheme.displayTitleSmall().copyWith(fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray500,
                height: 1.4,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetErrorView extends StatelessWidget {
  const _SheetErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  ({IconData icon, String title, String body}) _classify() {
    final lower = message.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('failed host lookup')) {
      return (
        icon: Icons.wifi_off_rounded,
        title: 'No connection',
        body: 'Check your network and try again.',
      );
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return (
        icon: Icons.hourglass_empty_rounded,
        title: 'Taking too long',
        body: 'The request timed out. Give it another go.',
      );
    }
    return (
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      body: "We couldn't load this list. Please retry.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _classify();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(info.icon, size: 28, color: AppTheme.gray500),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              info.title,
              style: AppTheme.displayTitleSmall().copyWith(fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              info.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray500,
                height: 1.4,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
