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
import '../../utils/extensions.dart';
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
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          // Suggestions button — only visible for leads/approvers.
          _SuggestionsButton(kitchenAsync: kitchenAsync),
        ],
      ),
      body: kitchenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
            tooltip: 'Previous week',
          ),
          Text(
            label,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Next week',
          ),
        ],
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

    return scheduleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorBody(
        message: error.toString(),
        onRetry: () => ref.invalidate(
          weekScheduleProvider(WeekScheduleParams(weekStart: weekStart)),
        ),
      ),
      data: (entries) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingXl),
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
  });

  final DateTime date;
  final List<ScheduleEntry> entries;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    final dayLabel = DateFormat('EEE, MMM d').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          color: isToday
              ? context.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
          child: Text(
            isToday ? '$dayLabel (Today)' : dayLabel,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isToday
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface,
            ),
          ),
        ),

        // Meal slots
        ...List.generate(_defaultMealSlots.length, (slotIndex) {
          final slot = _defaultMealSlots[slotIndex];
          final entry = _entryForSlot(slot);
          return _MealSlotRow(
            date: date,
            slot: slot,
            entry: entry,
          );
        }),

        // Any custom slots that aren't in default list
        ..._customSlotEntries().map((entry) {
          return _MealSlotRow(
            date: date,
            slot: entry.mealSlot,
            entry: entry,
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

  Iterable<ScheduleEntry> _customSlotEntries() {
    return entries.where((e) =>
        !_defaultMealSlots.contains(e.mealSlot.toLowerCase()));
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
  });

  final DateTime date;
  final String slot;
  final ScheduleEntry? entry;

  String get _slotDisplayName =>
      '${slot[0].toUpperCase()}${slot.substring(1)}';

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
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            // Slot label
            SizedBox(
              width: 80,
              child: Text(
                _slotDisplayName,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(width: AppTheme.spacingSm),

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                child: Text(
                  entry.displayLabel,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              if (entry.isRecipe)
                ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: const Text('View recipe'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/recipes/${entry.recipeId}');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
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
                leading: Icon(
                  Icons.delete_outline,
                  color: context.colorScheme.error,
                ),
                title: Text(
                  'Remove',
                  style: TextStyle(color: context.colorScheme.error),
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
              const SizedBox(height: AppTheme.spacingSm),
            ],
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
              style: TextStyle(color: context.colorScheme.error),
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
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 36,
                height: 36,
                color: context.colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (context, url, error) => Container(
                width: 36,
                height: 36,
                color: context.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.restaurant_menu,
                  size: 18,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (entry.isRecipe)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest,
              borderRadius: AppTheme.borderRadiusSmall,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 18,
              color: context.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colorScheme.tertiaryContainer,
              borderRadius: AppTheme.borderRadiusSmall,
            ),
            child: Icon(
              Icons.edit_note,
              size: 18,
              color: context.colorScheme.onTertiaryContainer,
            ),
          ),

        const SizedBox(width: AppTheme.spacingSm),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.displayLabel,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.isRecipe && entry.recipeAuthorName != null)
                Text(
                  'by ${entry.recipeAuthorName}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        // Suggestion badge
        if (entry.status == 'suggested')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Suggested',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSecondaryContainer,
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
        Icon(
          Icons.add_circle_outline,
          size: 20,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Text(
          'Add meal',
          style: context.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.kitchen,
              size: 64,
              color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No Kitchen Yet',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Join or create a kitchen to start planning meals together with your family or friends.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton.icon(
              onPressed: () => context.push('/kitchen/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Kitchen'),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            OutlinedButton.icon(
              onPressed: () => context.push('/kitchen/join'),
              icon: const Icon(Icons.group_add),
              label: const Text('Join Kitchen'),
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
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Premium Feature',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Free accounts can only view the current and next week. Upgrade to Premium to plan further ahead.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            FilledButton.icon(
              onPressed: () {
                PaywallBottomSheet.show(
                  context,
                  reason: PaywallReason.scheduleLimitReached,
                );
              },
              icon: const Icon(Icons.star),
              label: const Text('Go Premium'),
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
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Something went wrong',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
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
