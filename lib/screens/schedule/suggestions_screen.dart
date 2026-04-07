import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/schedule_entry.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/extensions.dart';

/// Screen listing pending meal suggestions for leads and approvers.
class SuggestionsScreen extends ConsumerWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Suggestions'),
      ),
      body: suggestionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: error.toString(),
          onRetry: () => ref.invalidate(suggestionsProvider),
        ),
        data: (suggestions) {
          if (suggestions.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(suggestionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              itemCount: suggestions.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.spacing12),
              itemBuilder: (_, index) {
                return _SuggestionCard(entry: suggestions[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Suggestion Card ─────────────────────────────────────────────────────────

class _SuggestionCard extends ConsumerStatefulWidget {
  const _SuggestionCard({required this.entry});

  final ScheduleEntry entry;

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard> {
  bool _isProcessed = false;

  void _approve() {
    if (mounted) setState(() => _isProcessed = true);
    ref.read(scheduleActionProvider.notifier).approveSuggestion(widget.entry.id);
  }

  void _deny() {
    if (mounted) setState(() => _isProcessed = true);
    ref.read(scheduleActionProvider.notifier).denySuggestion(widget.entry.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessed) return const SizedBox.shrink();

    final entry = widget.entry;
    final dayLabel = DateFormat('EEE, MMM d').format(entry.date);
    final slotLabel =
        '${entry.mealSlot[0].toUpperCase()}${entry.mealSlot.substring(1)}';

    return Dismissible(
      key: ValueKey(entry.id),
      background: _SwipeBackground(
        color: AppTheme.success,
        icon: Icons.check,
        label: 'Approve',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: AppTheme.error,
        icon: Icons.close,
        label: 'Deny',
        alignment: Alignment.centerRight,
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          ref.read(scheduleActionProvider.notifier).approveSuggestion(entry.id);
        } else {
          ref.read(scheduleActionProvider.notifier).denySuggestion(entry.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(color: AppTheme.gray200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal info
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: AppTheme.borderRadiusSmall,
                    ),
                    child: Icon(
                      entry.isRecipe
                          ? Icons.ramen_dining_rounded
                          : Icons.edit_note,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      entry.displayLabel,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray900,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing12),

              // Date and slot chip
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      borderRadius: AppTheme.borderRadiusFull,
                      border: Border.all(color: AppTheme.gray200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: AppTheme.gray500,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          '$slotLabel on $dayLabel',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppTheme.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (entry.suggestedBy != null) ...[
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  'Suggested by a kitchen member',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppTheme.gray400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacing16),

              // Divider
              Divider(color: AppTheme.gray100, height: 1),

              const SizedBox(height: AppTheme.spacing12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _deny,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Deny'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                        vertical: AppTheme.spacing8,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  FilledButton.icon(
                    onPressed: _approve,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                        vertical: AppTheme.spacing8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Swipe Background ────────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
                Icons.inbox_outlined,
                size: 36,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'No Pending Suggestions',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'When kitchen members suggest meals, they will appear here for your approval.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
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
