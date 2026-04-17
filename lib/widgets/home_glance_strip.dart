import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/schedule_entry.dart';
import '../providers/home_ui_preferences_provider.dart';
import '../providers/kitchen_provider.dart';
import '../providers/schedule_provider.dart';
import '../utils/calendar_week.dart';
import '../utils/extensions.dart';

/// Compact “at a glance” strip: kitchen + today’s planned meals (when available).
class HomeGlanceStrip extends ConsumerWidget {
  const HomeGlanceStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchenAsync = ref.watch(myKitchenProvider);
    final weekStart = mondayOfWeekContaining(DateTime.now());

    return kitchenAsync.when(
      data: (detail) {
        if (detail == null) {
          final dismissedAsync =
              ref.watch(homeNoKitchenPromptDismissedProvider);
          return dismissedAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (Object _, StackTrace _) => _NoKitchenCard(
              onOpenKitchen: () => context.go('/kitchen'),
              onDismiss: () => ref
                  .read(homeNoKitchenPromptDismissedProvider.notifier)
                  .dismiss(),
            ),
            data: (dismissed) {
              if (dismissed) return const SizedBox.shrink();
              return _NoKitchenCard(
                onOpenKitchen: () => context.go('/kitchen'),
                onDismiss: () => ref
                    .read(homeNoKitchenPromptDismissedProvider.notifier)
                    .dismiss(),
              );
            },
          );
        }
        final scheduleAsync = ref.watch(
          weekScheduleProvider(WeekScheduleParams(weekStart: weekStart)),
        );
        return scheduleAsync.when(
          data: (entries) {
            final today = DateTime.now();
            final todayEntries = entries
                .where((e) => isSameCalendarDay(e.date, today))
                .toList()
              ..sort((a, b) =>
                  a.mealSlot.toLowerCase().compareTo(b.mealSlot.toLowerCase()));
            return _KitchenScheduleCard(
              kitchenName: detail.kitchen.name,
              todayEntries: todayEntries,
              onOpenSchedule: () => context.go('/schedule'),
              onOpenKitchen: () => context.go('/kitchen'),
            );
          },
          loading: () => _GlanceLoadingCard(kitchenName: detail.kitchen.name),
          error: (Object _, StackTrace _) => _KitchenScheduleCard(
            kitchenName: detail.kitchen.name,
            todayEntries: const [],
            onOpenSchedule: () => context.go('/schedule'),
            onOpenKitchen: () => context.go('/kitchen'),
            scheduleFailed: true,
          ),
        );
      },
      loading: () => const _GlanceSkeleton(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _NoKitchenCard extends StatelessWidget {
  const _NoKitchenCard({
    required this.onOpenKitchen,
    required this.onDismiss,
  });

  final VoidCallback onOpenKitchen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Material(
          color: AppTheme.surfaceElevated,
          elevation: 0,
          shadowColor: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenKitchen,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    AppTheme.spacing12,
                    AppTheme.spacing8,
                    AppTheme.spacing12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.accentPlayfulLight.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.kitchen_outlined,
                          color: AppTheme.accentPlayful,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set up your kitchen',
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryDeep,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Schedules, shopping, and shared recipes start here.',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppTheme.gray500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppTheme.gray400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              style: IconButton.styleFrom(
                foregroundColor: AppTheme.gray500,
                minimumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.close_rounded, size: 22),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _KitchenScheduleCard extends StatelessWidget {
  const _KitchenScheduleCard({
    required this.kitchenName,
    required this.todayEntries,
    required this.onOpenSchedule,
    required this.onOpenKitchen,
    this.scheduleFailed = false,
  });

  final String kitchenName;
  final List<ScheduleEntry> todayEntries;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenKitchen;
  final bool scheduleFailed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Material(
          color: AppTheme.surfaceElevated,
          elevation: 0,
          shadowColor: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing14,
              AppTheme.spacing12,
              AppTheme.spacing14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onOpenKitchen,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPlayfulLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.kitchen_rounded,
                                  size: 16,
                                  color: AppTheme.accentPlayful,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Flexible(
                                child: Text(
                                  kitchenName,
                                  style:
                                      context.textTheme.titleSmall?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryDeep,
                                    letterSpacing: -0.25,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppTheme.gray400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: AppTheme.accentPlayfulLight,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onOpenSchedule,
                        splashColor: AppTheme.accentPlayful
                            .withValues(alpha: 0.18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 14,
                                color: AppTheme.accentPlayful,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Schedule',
                                style: context.textTheme.labelMedium
                                    ?.copyWith(
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
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing10),
                if (scheduleFailed)
                  Text(
                    'Could not load today’s meals.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray500,
                    ),
                  )
                else if (todayEntries.isEmpty)
                  Text(
                    'Nothing on the calendar today — tap Schedule to plan.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppTheme.gray500,
                      height: 1.35,
                    ),
                  )
                else
                  Wrap(
                    spacing: AppTheme.spacing8,
                    runSpacing: AppTheme.spacing8,
                    children: todayEntries.take(4).map((e) {
                      final label =
                          '${_slotLabel(e.mealSlot)} · ${e.displayLabel}';
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceWarm,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          label,
                          style: context.textTheme.labelMedium?.copyWith(
                            fontSize: 12.5,
                            color: AppTheme.textPrimaryDeep,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _slotLabel(String slot) {
  if (slot.isEmpty) return 'Meal';
  return slot[0].toUpperCase() + slot.substring(1);
}

class _GlanceLoadingCard extends StatelessWidget {
  const _GlanceLoadingCard({required this.kitchenName});

  final String kitchenName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Material(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(AppTheme.accentPlayful),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    'Loading $kitchenName…',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray600,
                      fontWeight: FontWeight.w500,
                    ),
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

class _GlanceSkeleton extends StatelessWidget {
  const _GlanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.shadowCard,
        ),
      ),
    );
  }
}
