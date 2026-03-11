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
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              itemCount: suggestions.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.spacingSm),
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

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.entry});

  final ScheduleEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayLabel = DateFormat('EEE, MMM d').format(entry.date);
    final slotLabel =
        '${entry.mealSlot[0].toUpperCase()}${entry.mealSlot.substring(1)}';

    return Dismissible(
      key: ValueKey(entry.id),
      background: _SwipeBackground(
        color: Colors.green.shade600,
        icon: Icons.check,
        label: 'Approve',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: context.colorScheme.error,
        icon: Icons.close,
        label: 'Deny',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          return ref
              .read(scheduleActionProvider.notifier)
              .approveSuggestion(entry.id);
        } else {
          return ref
              .read(scheduleActionProvider.notifier)
              .denySuggestion(entry.id);
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal info
              Row(
                children: [
                  Icon(
                    entry.isRecipe
                        ? Icons.restaurant_menu
                        : Icons.edit_note,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      entry.displayLabel,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingSm),

              // Date and slot
              Text(
                '$slotLabel on $dayLabel',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),

              if (entry.suggestedBy != null) ...[
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  'Suggested by a kitchen member',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacingMd),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(scheduleActionProvider.notifier)
                          .denySuggestion(entry.id);
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Deny'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colorScheme.error,
                      side: BorderSide(color: context.colorScheme.error),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(scheduleActionProvider.notifier)
                          .approveSuggestion(entry.id);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: AppTheme.spacingSm),
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
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No Pending Suggestions',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'When kitchen members suggest meals, they will appear here for your approval.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
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
