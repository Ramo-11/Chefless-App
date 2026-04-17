import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/schedule_entry.dart';
import '../../providers/schedule_provider.dart';

/// Screen listing pending meal suggestions for leads and approvers.
class SuggestionsScreen extends ConsumerWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text(
          'Suggestions',
          style: AppTheme.displayTitleMedium(),
        ),
      ),
      body: suggestionsAsync.when(
        loading: () => const _BrandedLoader(),
        error: (error, _) => _SuggestionsErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(suggestionsProvider),
        ),
        data: (suggestions) {
          if (suggestions.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.accentPlayful,
              onRefresh: () async => ref.invalidate(suggestionsProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [_EmptyState()],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.accentPlayful,
            onRefresh: () async => ref.invalidate(suggestionsProvider),
            child: Column(
              children: [
                _SuggestionsHeader(count: suggestions.length),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing16,
                      AppTheme.spacing4,
                      AppTheme.spacing16,
                      AppTheme.spacing32,
                    ),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spacing12),
                    itemBuilder: (_, index) {
                      return _SuggestionCard(entry: suggestions[index]);
                    },
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

class _SuggestionsHeader extends StatelessWidget {
  const _SuggestionsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing4,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.accentPlayful,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '$count pending',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              count == 1
                  ? 'Review and approve to add it to the schedule.'
                  : 'Review and approve to add them to the schedule.',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
                color: AppTheme.gray600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion Card ────────────────────────────────────────────────────────

class _SuggestionCard extends ConsumerStatefulWidget {
  const _SuggestionCard({required this.entry});

  final ScheduleEntry entry;

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard>
    with SingleTickerProviderStateMixin {
  bool _isProcessed = false;
  bool _wasApproved = false;

  void _approve() {
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() {
        _isProcessed = true;
        _wasApproved = true;
      });
    }
    ref.read(scheduleActionProvider.notifier).approveSuggestion(widget.entry.id);
  }

  void _deny() {
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() {
        _isProcessed = true;
        _wasApproved = false;
      });
    }
    ref.read(scheduleActionProvider.notifier).denySuggestion(widget.entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final dayLabel = DateFormat('EEE, MMM d').format(entry.date);
    final slotLabel =
        '${entry.mealSlot[0].toUpperCase()}${entry.mealSlot.substring(1)}';

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            sizeFactor: anim,
            axisAlignment: -1,
            child: child,
          ),
        ),
        child: _isProcessed
            ? _ProcessedCard(
                key: const ValueKey('processed'),
                approved: _wasApproved,
              )
            : _ActiveCard(
                key: const ValueKey('active'),
                entry: entry,
                slotLabel: slotLabel,
                dayLabel: dayLabel,
                onApprove: _approve,
                onDeny: _deny,
              ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    super.key,
    required this.entry,
    required this.slotLabel,
    required this.dayLabel,
    required this.onApprove,
    required this.onDeny,
  });

  final ScheduleEntry entry;
  final String slotLabel;
  final String dayLabel;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPlayfulLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    entry.isRecipe
                        ? Icons.ramen_dining_rounded
                        : Icons.edit_note,
                    size: 20,
                    color: AppTheme.accentPlayful,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.displayLabel,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppTheme.gray900,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.suggestedBy != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Suggested by a kitchen member',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.1,
                              color: AppTheme.gray500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.gray50,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12.5,
                    color: AppTheme.gray500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$slotLabel  ·  $dayLabel',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: AppTheme.gray700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onDeny,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Deny'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.errorLight,
                      foregroundColor: AppTheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.borderRadiusMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentPlayful,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.borderRadiusMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessedCard extends StatelessWidget {
  const _ProcessedCard({super.key, required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    final color = approved ? AppTheme.success : AppTheme.gray500;
    final bg = approved ? AppTheme.successLight : AppTheme.gray50;
    final label = approved ? 'Added to schedule' : 'Denied';
    final icon = approved
        ? Icons.check_circle_rounded
        : Icons.do_not_disturb_on_outlined;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppTheme.borderRadiusXL,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing14,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppTheme.spacing10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing40,
        AppTheme.spacing64,
        AppTheme.spacing40,
        AppTheme.spacing40,
      ),
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
            child: const Icon(
              Icons.inbox_outlined,
              size: 30,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          Text(
            'All caught up',
            style: AppTheme.displayTitleSmall().copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'When kitchen members suggest meals, they will appear here for your approval.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
              color: AppTheme.gray500,
              height: 1.5,
            ),
          ),
        ],
      ),
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

// ── Error View (classified) ────────────────────────────────────────────────

class _SuggestionsErrorView extends StatelessWidget {
  const _SuggestionsErrorView({
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
      body: "We couldn't load suggestions. Please retry.",
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
                letterSpacing: -0.1,
                color: AppTheme.gray500,
                height: 1.4,
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
