import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/shimmer_loading.dart';
import '../paywall/paywall_bottom_sheet.dart';
import 'add_meal_sheet.dart';

enum _ScheduleSurface { week, month }

const _defaultMealSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime _weekStart;
  _ScheduleSurface _surface = _ScheduleSurface.week;
  late DateTime _monthCursor;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOfWeek(DateTime.now());
    final n = DateTime.now();
    _monthCursor = DateTime(n.year, n.month);
  }

  static DateTime _mondayOfWeek(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  void _goToPreviousWeek() {
    HapticFeedback.lightImpact();
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    HapticFeedback.lightImpact();
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
  }

  void _goToPreviousMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _monthCursor =
          DateTime(_monthCursor.year, _monthCursor.month - 1);
    });
  }

  void _goToNextMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _monthCursor =
          DateTime(_monthCursor.year, _monthCursor.month + 1);
    });
  }

  void _jumpToToday() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      _weekStart = _mondayOfWeek(now);
      _monthCursor = DateTime(now.year, now.month);
    });
  }

  bool _isWeekLocked(DateTime weekStart, bool isPremium) {
    if (isPremium) return false;
    final currentMonday = _mondayOfWeek(DateTime.now());
    final difference = weekStart.difference(currentMonday).inDays;
    return difference < 0 || difference > 7;
  }

  bool get _isOnCurrentSpan {
    final now = DateTime.now();
    if (_surface == _ScheduleSurface.week) {
      return _isSameDay(_weekStart, _mondayOfWeek(now));
    }
    return _monthCursor.year == now.year && _monthCursor.month == now.month;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final kitchenAsync = ref.watch(myKitchenProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text(
          'Schedule',
          style: AppTheme.displayTitleMedium(),
        ),
        actions: [
          const NotificationBellIcon(),
          const ProfileShortcutIcon(),
          _SuggestionsButton(kitchenAsync: kitchenAsync),
          const MainTabMoreButton(topic: AppHelpTopic.schedule),
        ],
      ),
      body: currentUserAsync.when(
        loading: () => const _ScheduleLoadingSkeleton(),
        error: (error, _) => _ScheduleErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (user) {
          if (user == null) return const SizedBox.shrink();

          final isPremium = user.isPremiumActive;
          final locked = _isWeekLocked(_weekStart, isPremium);

          return RefreshIndicator(
            color: AppTheme.accentPlayful,
            onRefresh: () async {
              ref.invalidate(
                weekScheduleProvider(
                  WeekScheduleParams(weekStart: _weekStart),
                ),
              );
              ref.invalidate(
                monthScheduleProvider(
                  MonthScheduleParams(
                    year: _monthCursor.year,
                    month: _monthCursor.month,
                  ),
                ),
              );
              ref.invalidate(myKitchenProvider);
            },
            child: Column(
              children: [
                _ScheduleHeader(
                  surface: _surface,
                  weekStart: _weekStart,
                  monthCursor: _monthCursor,
                  isOnCurrentSpan: _isOnCurrentSpan,
                  onPrevious: _surface == _ScheduleSurface.week
                      ? _goToPreviousWeek
                      : _goToPreviousMonth,
                  onNext: _surface == _ScheduleSurface.week
                      ? _goToNextWeek
                      : _goToNextMonth,
                  onJumpToToday: _jumpToToday,
                  onSurfaceChanged: (next) {
                    if (next == _ScheduleSurface.month && !isPremium) {
                      PaywallBottomSheet.show(
                        context,
                        reason: PaywallReason.scheduleLimitReached,
                      );
                      return;
                    }
                    HapticFeedback.selectionClick();
                    setState(() => _surface = next);
                  },
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(
                        _surface == _ScheduleSurface.week
                            ? 'wk-${_weekStart.toIso8601String()}'
                            : 'mo-${_monthCursor.year}-${_monthCursor.month}',
                      ),
                      child: _surface == _ScheduleSurface.week
                          ? (locked
                              ? const _PremiumLockOverlay()
                              : _WeekView(weekStart: _weekStart))
                          : _MonthSchedulePanel(monthCursor: _monthCursor),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Schedule Header (unified nav + surface toggle) ─────────────────────────

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({
    required this.surface,
    required this.weekStart,
    required this.monthCursor,
    required this.isOnCurrentSpan,
    required this.onPrevious,
    required this.onNext,
    required this.onJumpToToday,
    required this.onSurfaceChanged,
  });

  final _ScheduleSurface surface;
  final DateTime weekStart;
  final DateTime monthCursor;
  final bool isOnCurrentSpan;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJumpToToday;
  final ValueChanged<_ScheduleSurface> onSurfaceChanged;

  String get _title {
    if (surface == _ScheduleSurface.week) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final fmt = DateFormat('MMM d');
      return '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}';
    }
    return DateFormat.yMMMM().format(monthCursor);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
            tooltip: 'Previous',
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: GestureDetector(
                  key: ValueKey(_title),
                  behavior: HitTestBehavior.opaque,
                  onTap: isOnCurrentSpan ? null : onJumpToToday,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _title,
                          style: AppTheme.displayTitleSmall().copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (!isOnCurrentSpan) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Tap to jump to today',
                            style: context.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              color: AppTheme.accentPlayful,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
            tooltip: 'Next',
          ),
          const SizedBox(width: AppTheme.spacing8),
          _SurfaceToggle(
            surface: surface,
            onChanged: onSurfaceChanged,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          splashColor: AppTheme.accentPlayful.withValues(alpha: 0.10),
          highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.05),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: AppTheme.gray700),
          ),
        ),
      ),
    );
  }
}

class _SurfaceToggle extends StatelessWidget {
  const _SurfaceToggle({
    required this.surface,
    required this.onChanged,
  });

  final _ScheduleSurface surface;
  final ValueChanged<_ScheduleSurface> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.gray100.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            label: 'Week',
            selected: surface == _ScheduleSurface.week,
            onTap: () => onChanged(_ScheduleSurface.week),
          ),
          _ToggleSegment(
            label: 'Month',
            selected: surface == _ScheduleSurface.month,
            onTap: () => onChanged(_ScheduleSurface.month),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.10),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentPlayful : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.accentPlayful.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: selected ? Colors.white : AppTheme.gray600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Week View ──────────────────────────────────────────────────────────────

class _WeekView extends ConsumerWidget {
  const _WeekView({required this.weekStart});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(
      weekScheduleProvider(WeekScheduleParams(weekStart: weekStart)),
    );
    final kitchenAsync = ref.watch(myKitchenProvider);
    final customSlots =
        kitchenAsync.valueOrNull?.kitchen.customMealSlots ?? const [];

    return scheduleAsync.when(
      loading: () => const _ScheduleLoadingSkeleton(),
      error: (error, _) => _ScheduleErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(
          weekScheduleProvider(WeekScheduleParams(weekStart: weekStart)),
        ),
      ),
      data: (entries) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing4,
            AppTheme.spacing16,
            AppTheme.spacing16,
          ),
          itemCount: 8,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppTheme.spacing14),
          itemBuilder: (context, index) {
            if (index == 7) return const _ScheduleEndMarker();
            final day = weekStart.add(Duration(days: index));
            final dayEntries = entries
                .where((e) =>
                    e.date.year == day.year &&
                    e.date.month == day.month &&
                    e.date.day == day.day)
                .toList();
            return _DayCard(
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

// ── Day Card ───────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.entries,
    required this.customSlots,
  });

  final DateTime date;
  final List<ScheduleEntry> entries;
  final List<String> customSlots;

  ScheduleEntry? _entryForSlot(String slot) {
    final matches =
        entries.where((e) => e.mealSlot.toLowerCase() == slot.toLowerCase());
    return matches.isNotEmpty ? matches.first : null;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    final isPast = date.isBefore(DateTime.now()) && !isToday;
    final knownSlotNames = {
      ..._defaultMealSlots.map((s) => s.toLowerCase()),
      ...customSlots.map((s) => s.toLowerCase()),
    };
    final orphanEntries = entries.where(
      (e) => !knownSlotNames.contains(e.mealSlot.toLowerCase()),
    );

    final allSlots = <_SlotRef>[
      for (final s in _defaultMealSlots) _SlotRef(s, isCustom: false),
      for (final s in customSlots) _SlotRef(s, isCustom: true),
      for (final e in orphanEntries) _SlotRef(e.mealSlot, isCustom: true),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowCard,
      ),
      child: ClipRRect(
        borderRadius: AppTheme.borderRadiusXL,
        child: Column(
          children: [
            _DayHeader(date: date, isToday: isToday, isPast: isPast),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing4,
                AppTheme.spacing4,
                AppTheme.spacing4,
                AppTheme.spacing8,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < allSlots.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing12,
                        ),
                        child: Container(
                          height: 1,
                          color: AppTheme.gray100.withValues(alpha: 0.6),
                        ),
                      ),
                    _MealSlotRow(
                      date: date,
                      slot: allSlots[i].slot,
                      entry: _entryForSlot(allSlots[i].slot),
                      isCustom: allSlots[i].isCustom,
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

class _SlotRef {
  const _SlotRef(this.slot, {required this.isCustom});
  final String slot;
  final bool isCustom;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.isToday,
    required this.isPast,
  });

  final DateTime date;
  final bool isToday;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat('EEE').format(date).toUpperCase();
    final monthDay = DateFormat('MMM d').format(date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing14,
        AppTheme.spacing12,
        AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: isToday
            ? AppTheme.accentPlayfulLight
            : AppTheme.surfaceElevated,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday
                  ? AppTheme.accentPlayful
                  : AppTheme.gray50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isToday
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppTheme.gray500,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.4,
                    color: isToday ? Colors.white : AppTheme.gray900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('EEEE').format(date),
                  style: AppTheme.displayTitleSmall().copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isPast ? AppTheme.gray500 : AppTheme.textPrimaryDeep,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  monthDay,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                    color: isToday
                        ? AppTheme.accentPlayful
                        : AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accentPlayful,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: const Text(
                'TODAY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Meal Slot Row ──────────────────────────────────────────────────────────

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
  final bool isCustom;

  String get _slotDisplayName => slot.isNotEmpty
      ? '${slot[0].toUpperCase()}${slot.substring(1).toLowerCase()}'
      : slot;

  IconData get _slotIcon {
    switch (slot.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_twilight_rounded;
      case 'lunch':
        return Icons.wb_sunny_outlined;
      case 'dinner':
        return Icons.nightlight_outlined;
      case 'snack':
        return Icons.cookie_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          if (entry != null) {
            _showEntryOptions(context, ref, entry!);
          } else {
            _openAddMealSheet(context);
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Row(
                  children: [
                    Icon(
                      _slotIcon,
                      size: 16,
                      color: AppTheme.gray400,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _slotDisplayName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: AppTheme.gray700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isCustom)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'custom',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                  color: AppTheme.accentPlayful
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: entry != null
                    ? _EntryContent(entry: entry!)
                    : const _AddMealAction(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddMealSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddMealSheet(date: date, mealSlot: slot),
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
                    style: AppTheme.displayTitleSmall().copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                if (entry.isRecipe)
                  _SheetAction(
                    icon: Icons.restaurant_menu,
                    iconBg: AppTheme.accentPlayfulLight,
                    iconColor: AppTheme.accentPlayful,
                    label: 'View recipe',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/recipe/${entry.recipeId}');
                    },
                  ),
                _SheetAction(
                  icon: Icons.swap_horiz,
                  iconBg: AppTheme.gray50,
                  iconColor: AppTheme.gray600,
                  label: 'Replace',
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
                _SheetAction(
                  icon: Icons.delete_outline,
                  iconBg: AppTheme.errorLight,
                  iconColor: AppTheme.error,
                  label: 'Remove',
                  isDestructive: true,
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
            child: const Text(
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

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: AppTheme.borderRadiusSmall,
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? AppTheme.error : AppTheme.gray900,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── Entry Content ──────────────────────────────────────────────────────────

class _EntryContent extends StatelessWidget {
  const _EntryContent({required this.entry});

  final ScheduleEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EntryThumbnail(entry: entry),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.displayLabel,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppTheme.gray900,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.isRecipe && entry.recipeAuthorName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'by ${entry.recipeAuthorName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray500,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (entry.scheduledTime != null || entry.prepTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: AppTheme.spacing8,
                    runSpacing: 2,
                    children: [
                      if (entry.scheduledTime != null)
                        _MetaChip(
                          icon: Icons.schedule_rounded,
                          label: entry.scheduledTime!,
                        ),
                      if (entry.prepTime != null)
                        _MetaChip(
                          icon: Icons.timer_outlined,
                          label: '${entry.prepTime}m',
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (entry.status == 'suggested') const _SuggestedBadge(),
      ],
    );
  }
}

class _EntryThumbnail extends StatelessWidget {
  const _EntryThumbnail({required this.entry});

  final ScheduleEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.isRecipe && entry.recipePhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: entry.recipePhoto!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (_, _) => _placeholderBox(),
          errorWidget: (_, _, _) => _recipeFallback(),
        ),
      );
    }
    if (entry.isRecipe) return _recipeFallback();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.accentPlayfulLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.edit_note,
        size: 20,
        color: AppTheme.accentPlayful,
      ),
    );
  }

  Widget _placeholderBox() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _recipeFallback() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.ramen_dining_rounded,
        size: 20,
        color: AppTheme.gray400,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.gray500),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: AppTheme.gray600,
          ),
        ),
      ],
    );
  }
}

class _SuggestedBadge extends StatelessWidget {
  const _SuggestedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppTheme.accentPlayful.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: const Text(
        'Suggested',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppTheme.accentPlayful,
        ),
      ),
    );
  }
}

class _AddMealAction extends StatelessWidget {
  const _AddMealAction();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.accentPlayfulLight,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.add_rounded,
            size: 20,
            color: AppTheme.accentPlayful,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Text(
          'Add meal',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: AppTheme.accentPlayful.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }
}

// ── End-of-week Marker ─────────────────────────────────────────────────────

class _ScheduleEndMarker extends StatelessWidget {
  const _ScheduleEndMarker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing40,
        vertical: AppTheme.spacing24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.gray200.withValues(alpha: 0.7),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.accentPlayful.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.gray200.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month Panel ────────────────────────────────────────────────────────────

class _MonthSchedulePanel extends ConsumerStatefulWidget {
  const _MonthSchedulePanel({required this.monthCursor});

  final DateTime monthCursor;

  @override
  ConsumerState<_MonthSchedulePanel> createState() =>
      _MonthSchedulePanelState();
}

class _MonthSchedulePanelState extends ConsumerState<_MonthSchedulePanel> {
  DateTime? _selectedDay;

  @override
  void didUpdateWidget(covariant _MonthSchedulePanel old) {
    super.didUpdateWidget(old);
    if (old.monthCursor != widget.monthCursor) {
      setState(() => _selectedDay = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = MonthScheduleParams(
      year: widget.monthCursor.year,
      month: widget.monthCursor.month,
    );
    final async = ref.watch(monthScheduleProvider(params));
    final kitchenAsync = ref.watch(myKitchenProvider);
    final customSlots =
        kitchenAsync.valueOrNull?.kitchen.customMealSlots ?? const [];

    return async.when(
      loading: () => const _ScheduleLoadingSkeleton(),
      error: (e, _) => _ScheduleErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(monthScheduleProvider(params)),
      ),
      data: (entries) {
        final byDayKey = <String, List<ScheduleEntry>>{};
        for (final e in entries) {
          final k = DateFormat('yyyy-MM-dd').format(e.date);
          byDayKey.putIfAbsent(k, () => []).add(e);
        }

        final first =
            DateTime(widget.monthCursor.year, widget.monthCursor.month, 1);
        final daysInMonth = DateTime(
                widget.monthCursor.year, widget.monthCursor.month + 1, 0)
            .day;
        final lead = first.weekday - 1;
        final totalCells = ((lead + daysInMonth + 6) ~/ 7) * 7;
        final today = DateTime.now();

        final selectedKey = _selectedDay != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDay!)
            : null;
        final selectedEntries =
            selectedKey != null ? byDayKey[selectedKey] ?? [] : <ScheduleEntry>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing4,
            AppTheme.spacing16,
            AppTheme.spacing32,
          ),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: AppTheme.borderRadiusXL,
                boxShadow: AppTheme.shadowCard,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing4,
                        vertical: AppTheme.spacing4,
                      ),
                      child: Row(
                        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                            .map(
                              (d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: AppTheme.gray500,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.92,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: totalCells,
                      itemBuilder: (context, i) {
                        final dayNum = i - lead + 1;
                        if (i < lead || dayNum > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        final day = DateTime(widget.monthCursor.year,
                            widget.monthCursor.month, dayNum);
                        final key = DateFormat('yyyy-MM-dd').format(day);
                        final dayEntries = byDayKey[key] ?? [];
                        final isToday = day.year == today.year &&
                            day.month == today.month &&
                            day.day == today.day;
                        final isSelected = _selectedDay != null &&
                            _selectedDay!.year == day.year &&
                            _selectedDay!.month == day.month &&
                            _selectedDay!.day == day.day;

                        return _MonthDayCell(
                          dayNum: dayNum,
                          mealCount: dayEntries.length,
                          isToday: isToday,
                          isSelected: isSelected,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedDay = isSelected ? null : day;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              child: _selectedDay == null
                  ? const _MonthHintCard(key: ValueKey('hint'))
                  : _MonthDayDetailCard(
                      key: ValueKey(
                        DateFormat('yyyy-MM-dd').format(_selectedDay!),
                      ),
                      date: _selectedDay!,
                      entries: selectedEntries,
                      customSlots: customSlots,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthHintCard extends StatelessWidget {
  const _MonthHintCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowSubtle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentPlayfulLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.touch_app_outlined,
                size: 18,
                color: AppTheme.accentPlayful,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pick a day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap any date to see scheduled meals.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      color: AppTheme.gray500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.dayNum,
    required this.mealCount,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int dayNum;
  final int mealCount;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.transparent;
    Color textColor = AppTheme.gray800;
    Color dotColor = AppTheme.accentPlayful;
    FontWeight weight = FontWeight.w600;

    if (isSelected) {
      bgColor = AppTheme.accentPlayful;
      textColor = Colors.white;
      dotColor = Colors.white.withValues(alpha: 0.85);
      weight = FontWeight.w700;
    } else if (isToday) {
      bgColor = AppTheme.accentPlayfulLight;
      textColor = AppTheme.accentPlayful;
      weight = FontWeight.w700;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.10),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            color: bgColor,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.accentPlayful.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: weight,
                  letterSpacing: -0.2,
                  color: textColor,
                ),
              ),
              if (mealCount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    mealCount.clamp(0, 4),
                    (i) => Container(
                      width: 5,
                      height: 5,
                      margin: EdgeInsets.only(left: i > 0 ? 3 : 0),
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthDayDetailCard extends StatelessWidget {
  const _MonthDayDetailCard({
    super.key,
    required this.date,
    required this.entries,
    required this.customSlots,
  });

  final DateTime date;
  final List<ScheduleEntry> entries;
  final List<String> customSlots;

  @override
  Widget build(BuildContext context) {
    // Reuse the day card layout for consistency.
    return _DayCard(
      date: date,
      entries: entries,
      customSlots: customSlots,
    );
  }
}

// ── Premium Lock Overlay ───────────────────────────────────────────────────

class _PremiumLockOverlay extends StatelessWidget {
  const _PremiumLockOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentPlayfulLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 36,
                color: AppTheme.accentPlayful,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              'Premium feature',
              style: AppTheme.displayTitleSmall().copyWith(fontSize: 19),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Free accounts can plan this week and next. Upgrade to '
              'Premium for the full month calendar and unlimited weeks.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray500,
                height: 1.5,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentPlayful,
                ),
                onPressed: () {
                  PaywallBottomSheet.show(
                    context,
                    reason: PaywallReason.scheduleLimitReached,
                  );
                },
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Go Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestions Button (custom badge) ──────────────────────────────────────

class _SuggestionsButton extends ConsumerWidget {
  const _SuggestionsButton({required this.kitchenAsync});

  final AsyncValue<dynamic> kitchenAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      icon: count > 0
          ? _ScheduleCountBadge(
              count: count,
              child: const Icon(Icons.inbox_outlined),
            )
          : const Icon(Icons.inbox_outlined),
      onPressed: () => context.push('/schedule/suggestions'),
      tooltip: 'Pending suggestions',
    );
  }
}

class _ScheduleCountBadge extends StatelessWidget {
  const _ScheduleCountBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -6,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: EdgeInsets.symmetric(horizontal: count > 9 ? 5 : 0),
            decoration: BoxDecoration(
              color: AppTheme.accentPlayful,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(color: AppTheme.surfaceWarm, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPlayful.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.1,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Loading Skeleton ───────────────────────────────────────────────────────

class _ScheduleLoadingSkeleton extends StatelessWidget {
  const _ScheduleLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerAnimator(
      builder: (context, value) {
        const base = Color(0xFFEFEAE2);
        const highlight = Color(0xFFF7F3EC);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing4,
            AppTheme.spacing16,
            AppTheme.spacing16,
          ),
          itemCount: 4,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppTheme.spacing14),
          itemBuilder: (_, _) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: AppTheme.borderRadiusXL,
                boxShadow: AppTheme.shadowSubtle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ShimmerBox(
                          baseColor: base,
                          highlightColor: highlight,
                          gradientValue: value,
                          width: 44,
                          height: 44,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(
                                baseColor: base,
                                highlightColor: highlight,
                                gradientValue: value,
                                width: 120,
                                height: 14,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              ShimmerBox(
                                baseColor: base,
                                highlightColor: highlight,
                                gradientValue: value,
                                width: 60,
                                height: 11,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    ...List.generate(
                      3,
                      (i) => Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                        child: Row(
                          children: [
                            ShimmerBox(
                              baseColor: base,
                              highlightColor: highlight,
                              gradientValue: value,
                              width: 70,
                              height: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            Expanded(
                              child: ShimmerBox(
                                baseColor: base,
                                highlightColor: highlight,
                                gradientValue: value,
                                height: 12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Error View (classified) ────────────────────────────────────────────────

class _ScheduleErrorView extends StatelessWidget {
  const _ScheduleErrorView({
    required this.message,
    required this.onRetry,
  });

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
    if (lower.contains('401') ||
        lower.contains('unauth') ||
        lower.contains('forbidden')) {
      return (
        icon: Icons.lock_outline_rounded,
        title: 'Session expired',
        body: 'Please sign in again to continue.',
      );
    }
    return (
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      body: "We couldn't load your schedule. Please retry.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _classify();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(info.icon, size: 30, color: AppTheme.gray500),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              info.title,
              style: AppTheme.displayTitleSmall().copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              info.body,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray500,
                height: 1.4,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
