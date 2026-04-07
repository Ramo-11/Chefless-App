import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/schedule_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/app_help_content.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_top_bar.dart';
import '../paywall/paywall_bottom_sheet.dart';
import 'add_meal_sheet.dart';

/// Default meal slots displayed for each day.
const _defaultMealSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

/// The Schedule tab — shows a week view of meal entries for the user's kitchen.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOfWeek(DateTime.now());
  }

  /// Returns the Monday of the week containing [date].
  static DateTime _mondayOfWeek(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  void _goToPreviousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
  }

  /// Whether [weekStart] is beyond the free tier limit (> 2 weeks from today).
  bool _isWeekLocked(DateTime weekStart, bool isPremium) {
    if (isPremium) return false;
    final now = DateTime.now();
    final currentMonday = _mondayOfWeek(now);
    final difference = weekStart.difference(currentMonday).inDays;
    return difference > 14;
  }

  @override
  Widget build(BuildContext context) {
    final kitchenAsync = ref.watch(myKitchenProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        leading: IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
          tooltip: 'Search',
        ),
        title: Text(
          'Schedule',
          style: AppTheme.displayTitleMedium(),
        ),
        actions: [
          const NotificationBellIcon(),
          const ProfileShortcutIcon(),
          // Suggestions button — only visible for leads/approvers.
          _SuggestionsButton(kitchenAsync: kitchenAsync),
          const MainTabMoreButton(topic: AppHelpTopic.schedule),
        ],
      ),
      body: kitchenAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        error: (error, _) => _ErrorBody(
          message: error.toString(),
          onRetry: () => ref.invalidate(myKitchenProvider),
        ),
        data: (kitchenDetail) {
          if (kitchenDetail == null) {
            return const _NoKitchenPrompt();
          }

          final isPremium = currentUserAsync.valueOrNull?.isPremium ?? false;
          final locked = _isWeekLocked(_weekStart, isPremium);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                weekScheduleProvider(
                  WeekScheduleParams(weekStart: _weekStart),
                ),
              );
              ref.invalidate(myKitchenProvider);
            },
            child: Column(
              children: [
                // Week navigation header
                _WeekNavigationHeader(
                  weekStart: _weekStart,
                  onPrevious: _goToPreviousWeek,
                  onNext: _goToNextWeek,
                ),

                // Week content
                Expanded(
                  child: locked
                      ? const _PremiumLockOverlay()
                      : _WeekView(weekStart: _weekStart),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Week Navigation Header ──────────────────────────────────────────────────

class _WeekNavigationHeader extends StatelessWidget {
  const _WeekNavigationHeader({
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final formatter = DateFormat('MMM d');
    final label = '${formatter.format(weekStart)} - ${formatter.format(weekEnd)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowSm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
              onPressed: onPrevious,
              tooltip: 'Previous week',
              style: IconButton.styleFrom(
                foregroundColor: AppTheme.gray700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accentPlayfulLight,
                borderRadius: AppTheme.borderRadiusFull,
              ),
              child: Text(
                label,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryDeep,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 24),
              onPressed: onNext,
              tooltip: 'Next week',
              style: IconButton.styleFrom(
                foregroundColor: AppTheme.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Week View ───────────────────────────────────────────────────────────────

class _WeekView extends ConsumerWidget {
  const _WeekView({required this.weekStart});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(
      weekScheduleProvider(WeekScheduleParams(weekStart: weekStart)),
    );
    // Custom slots come from the kitchen model — already loaded by the parent.
    final kitchenAsync = ref.watch(myKitchenProvider);
    final customSlots =
        kitchenAsync.valueOrNull?.kitchen.customMealSlots ?? const [];

    return scheduleAsync.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => _ErrorBody(
        message: error.toString(),
        onRetry: () => ref.invalidate(
          weekScheduleProvider(WeekScheduleParams(weekStart: weekStart)),
        ),
      ),
      data: (entries) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing32),
          itemCount: 7,
          itemBuilder: (context, dayIndex) {
            final day = weekStart.add(Duration(days: dayIndex));
            final dayEntries = entries
                .where((e) =>
                    e.date.year == day.year &&
                    e.date.month == day.month &&
                    e.date.day == day.day)
                .toList();

            return _DayColumn(
              date: day,
              entries: dayEntries,
              customSlots: customSlots,
            );
          },
        );
      },
    );
  }
}

// ── Day Column ──────────────────────────────────────────────────────────────

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.entries,
    required this.customSlots,
  });

  final DateTime date;
  final List<ScheduleEntry> entries;
  /// Custom slot names from the kitchen (e.g. ["Pre-Workout", "Late Night"]).
  final List<String> customSlots;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    final dayLabel = DateFormat('EEE, MMM d').format(date);

    // Collect any extra slots that have entries but aren't in the known lists.
    final knownSlotNames = {
      ..._defaultMealSlots.map((s) => s.toLowerCase()),
      ...customSlots.map((s) => s.toLowerCase()),
    };
    final orphanEntries = entries.where(
      (e) => !knownSlotNames.contains(e.mealSlot.toLowerCase()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: isToday ? AppTheme.primaryLight : AppTheme.gray50,
            border: Border(
              bottom: BorderSide(
                color: isToday
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : AppTheme.gray200,
              ),
            ),
          ),
          child: Row(
            children: [
              if (isToday)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: AppTheme.spacing8),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                isToday ? '$dayLabel (Today)' : dayLabel,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isToday ? AppTheme.primaryColor : AppTheme.gray800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),

        // Default meal slots (always shown, even when empty).
        ...List.generate(_defaultMealSlots.length, (slotIndex) {
          final slot = _defaultMealSlots[slotIndex];
          return _MealSlotRow(
            date: date,
            slot: slot,
            entry: _entryForSlot(slot),
          );
        }),

        // Custom meal slots defined by the kitchen lead (always shown, even when empty).
        ...customSlots.map((slot) {
          return _MealSlotRow(
            date: date,
            slot: slot,
            entry: _entryForSlot(slot),
            isCustom: true,
          );
        }),

        // Orphan entries: slots that existed before a custom slot was deleted.
        ...orphanEntries.map((entry) {
          return _MealSlotRow(
            date: date,
            slot: entry.mealSlot,
            entry: entry,
            isCustom: true,
          );
        }),
      ],
    );
  }

  ScheduleEntry? _entryForSlot(String slot) {
    final matches =
        entries.where((e) => e.mealSlot.toLowerCase() == slot.toLowerCase());
    return matches.isNotEmpty ? matches.first : null;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ── Meal Slot Row ───────────────────────────────────────────────────────────

class _MealSlotRow extends ConsumerWidget {
  const _MealSlotRow({
    required this.date,
    required this.slot,
    this.entry,
    this.isCustom = false,
  });

  final DateTime date;
  final String slot;
  final ScheduleEntry? entry;
  /// Whether this slot was created by the kitchen lead (vs a built-in default).
  final bool isCustom;

  String get _slotDisplayName =>
      slot.isNotEmpty
          ? '${slot[0].toUpperCase()}${slot.substring(1)}'
          : slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        if (entry != null) {
          _showEntryOptions(context, ref, entry!);
        } else {
          _openAddMealSheet(context, ref);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.gray100,
            ),
          ),
        ),
        child: Row(
          children: [
            // Slot label
            SizedBox(
              width: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _slotDisplayName,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray500,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isCustom)
                    Container(
                      margin: const EdgeInsets.only(top: AppTheme.spacing2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: AppTheme.borderRadiusFull,
                      ),
                      child: Text(
                        'custom',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: AppTheme.primaryDark,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: AppTheme.spacing12),

            // Entry content or add button
            Expanded(
              child: entry != null
                  ? _EntryContent(entry: entry!)
                  : _AddButton(colorScheme: context.colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddMealSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddMealSheet(
        date: date,
        mealSlot: slot,
      ),
    );
  }

  void _showEntryOptions(
    BuildContext context,
    WidgetRef ref,
    ScheduleEntry entry,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppTheme.spacing8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                  ),
                  child: Text(
                    entry.displayLabel,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                if (entry.isRecipe)
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: AppTheme.borderRadiusSmall,
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: const Text('View recipe'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/recipe/${entry.recipeId}');
                    },
                  ),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      size: 18,
                      color: AppTheme.gray600,
                    ),
                  ),
                  title: const Text('Replace'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => AddMealSheet(
                        date: date,
                        mealSlot: slot,
                        replacingEntryId: entry.id,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.errorLight,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTheme.error,
                    ),
                  ),
                  title: Text(
                    'Remove',
                    style: TextStyle(color: AppTheme.error),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final confirmed = await _confirmDelete(context);
                    if (confirmed && context.mounted) {
                      ref
                          .read(scheduleActionProvider.notifier)
                          .deleteEntry(entry.id);
                    }
                  },
                ),
                const SizedBox(height: AppTheme.spacing12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove meal'),
        content: const Text(
          'Are you sure you want to remove this meal from the schedule?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Entry Content ───────────────────────────────────────────────────────────

class _EntryContent extends StatelessWidget {
  const _EntryContent({required this.entry});

  final ScheduleEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Thumbnail for recipe entries
        if (entry.isRecipe && entry.recipePhoto != null)
          ClipRRect(
            borderRadius: AppTheme.borderRadiusSmall,
            child: CachedNetworkImage(
              imageUrl: entry.recipePhoto!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                child: const Icon(
                  Icons.ramen_dining_rounded,
                  size: 18,
                  color: AppTheme.gray400,
                ),
              ),
            ),
          )
        else if (entry.isRecipe)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.gray100,
              borderRadius: AppTheme.borderRadiusSmall,
            ),
            child: const Icon(
              Icons.ramen_dining_rounded,
              size: 18,
              color: AppTheme.gray400,
            ),
          )
        else
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: AppTheme.borderRadiusSmall,
            ),
            child: const Icon(
              Icons.edit_note,
              size: 18,
              color: AppTheme.primaryDark,
            ),
          ),

        const SizedBox(width: AppTheme.spacing12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.displayLabel,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.gray900,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.isRecipe && entry.recipeAuthorName != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing2),
                  child: Text(
                    'by ${entry.recipeAuthorName}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray400,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),

        // Suggestion badge
        if (entry.status == 'suggested')
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: AppTheme.spacing2,
            ),
            decoration: BoxDecoration(
              color: AppTheme.warningLight,
              borderRadius: AppTheme.borderRadiusFull,
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Suggested',
              style: context.textTheme.labelSmall?.copyWith(
                color: AppTheme.gray700,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Add Button ──────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.gray200,
              style: BorderStyle.solid,
            ),
            borderRadius: AppTheme.borderRadiusSmall,
          ),
          child: Icon(
            Icons.add,
            size: 18,
            color: AppTheme.gray300,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Text(
          'Add meal',
          style: context.textTheme.bodySmall?.copyWith(
            color: AppTheme.gray400,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ── No Kitchen Prompt ───────────────────────────────────────────────────────

class _NoKitchenPrompt extends StatelessWidget {
  const _NoKitchenPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.gray50,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.gray200),
              ),
              child: const Icon(
                Icons.kitchen,
                size: 36,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'No Kitchen Yet',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Join or create a kitchen to start planning meals together with your family or friends.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacing32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/kitchen/create'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Kitchen'),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/kitchen/join'),
                icon: const Icon(Icons.group_add, size: 18),
                label: const Text('Join Kitchen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Premium Lock Overlay ────────────────────────────────────────────────────

class _PremiumLockOverlay extends StatelessWidget {
  const _PremiumLockOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 36,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'Premium Feature',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Free accounts can only view the current and next week. Upgrade to Premium to plan further ahead.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacing32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  PaywallBottomSheet.show(
                    context,
                    reason: PaywallReason.scheduleLimitReached,
                  );
                },
                icon: const Icon(Icons.star, size: 18),
                label: const Text('Go Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestions Button ──────────────────────────────────────────────────────

class _SuggestionsButton extends ConsumerWidget {
  const _SuggestionsButton({required this.kitchenAsync});

  final AsyncValue<dynamic> kitchenAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show if user is in a kitchen.
    final kitchenDetail = kitchenAsync.valueOrNull;
    if (kitchenDetail == null) return const SizedBox.shrink();

    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) return const SizedBox.shrink();

    final kitchen = kitchenDetail.kitchen;
    final isLead = kitchen.leadId == currentUser.id;
    final hasApprovalPower =
        kitchen.membersWithApprovalPower.contains(currentUser.id);

    if (!isLead && !hasApprovalPower) return const SizedBox.shrink();

    final suggestionsAsync = ref.watch(suggestionsProvider);
    final count = suggestionsAsync.valueOrNull?.length ?? 0;

    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: AppTheme.primaryColor,
        textColor: Colors.white,
        child: const Icon(Icons.inbox),
      ),
      onPressed: () => context.push('/schedule/suggestions'),
      tooltip: 'Pending suggestions',
    );
  }
}

// ── Error Body ──────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: const Icon(
                Icons.error_outline,
                size: 28,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              'Something went wrong',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
