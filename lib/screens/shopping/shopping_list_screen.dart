import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shopping_list.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/app_help_content.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_top_bar.dart';
import 'generate_list_sheet.dart';

/// The Shopping Lists tab — shows all shopping lists for the user.
class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(shoppingListsProvider);

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
          'Shopping',
          style: AppTheme.displayTitleMedium(),
        ),
        actions: [
          const NotificationBellIcon(),
          const ProfileShortcutIcon(),
          MainTabMoreButton(
            topic: AppHelpTopic.shopping,
            primaryActionLabel: 'Generate from schedule',
            primaryActionIcon: Icons.calendar_month_rounded,
            onPrimaryAction: () => _openGenerateSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'shoppingListFab',
        backgroundColor: AppTheme.accentPlayful,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateSheet(context, ref),
        tooltip: 'Create shopping list',
        icon: const Icon(Icons.add_rounded),
        label: const Text('New List'),
      ),
      body: listsAsync.when(
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
          onRetry: () => ref.invalidate(shoppingListsProvider),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return _EmptyState(
              onCreate: () => _showCreateSheet(context, ref),
              onGenerate: () => _openGenerateSheet(context),
            );
          }

          return RefreshIndicator(
            color: AppTheme.accentPlayful,
            onRefresh: () async {
              ref.invalidate(shoppingListsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.only(
                top: AppTheme.spacing12,
                left: AppTheme.spacing16,
                right: AppTheme.spacing16,
                bottom: 96,
              ),
              itemCount: lists.length + 1,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.spacing12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ShoppingOverviewCard(lists: lists);
                }

                final list = lists[index - 1];
                return _ShoppingListTile(
                  shoppingList: list,
                  onTap: () => context.push('/shopping/${list.id}'),
                  onDelete: () => _confirmDelete(context, ref, list),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openGenerateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const GenerateListSheet(),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
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
                'New shopping list',
                style: AppTheme.displayTitleSmall(),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'Create a fresh list for groceries, prep, or anything you need for the kitchen.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'List name',
                  hintText: 'e.g. Weekly groceries',
                ),
                onSubmitted: (_) => _submitCreate(sheetContext, ref, controller),
              ),
              const SizedBox(height: AppTheme.spacing20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _submitCreate(sheetContext, ref, controller),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentPlayful,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create List'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submitCreate(
    BuildContext dialogContext,
    WidgetRef ref,
    TextEditingController controller,
  ) {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(dialogContext).pop();
    ref.read(shoppingListActionProvider.notifier).createList(name: name).then(
      (listId) {
        if (listId != null && dialogContext.mounted) {
          dialogContext.push('/shopping/$listId');
        }
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete shopping list'),
        content: Text(
          'Are you sure you want to delete "${list.name ?? 'Untitled'}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref
            .read(shoppingListActionProvider.notifier)
            .deleteList(list.id);
      }
    });
  }
}

class _ShoppingOverviewCard extends StatelessWidget {
  const _ShoppingOverviewCard({required this.lists});

  final List<ShoppingList> lists;

  @override
  Widget build(BuildContext context) {
    final generatedCount = lists.where((list) => list.generatedFromSchedule).length;
    final completedCount =
        lists.where((list) => list.totalCount > 0 && list.checkedCount == list.totalCount).length;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowSm,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.accentPlayfulLight.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kitchen shopping',
            style: AppTheme.displayTitleSmall(),
          ),
          const SizedBox(height: AppTheme.spacing6),
          Text(
            'Keep grocery runs, prep lists, and schedule-generated ingredients in one calm place.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Wrap(
            spacing: AppTheme.spacing12,
            runSpacing: AppTheme.spacing8,
            children: [
              _MetaPill(
                icon: Icons.receipt_long_rounded,
                label: '${lists.length} list${lists.length == 1 ? '' : 's'}',
              ),
              _MetaPill(
                icon: Icons.auto_awesome_rounded,
                label: '$generatedCount from schedule',
              ),
              _MetaPill(
                icon: Icons.check_circle_outline_rounded,
                label: '$completedCount completed',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: AppTheme.accentPlayful.withValues(alpha: 0.82),
          ),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: AppTheme.gray600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shopping List Tile ───────────────────────────────────────────────────────

class _ShoppingListTile extends StatelessWidget {
  const _ShoppingListTile({
    required this.shoppingList,
    required this.onTap,
    required this.onDelete,
  });

  final ShoppingList shoppingList;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, yyyy');
    final progress = shoppingList.totalCount > 0
        ? shoppingList.checkedCount / shoppingList.totalCount
        : 0.0;

    return Dismissible(
      key: ValueKey(shoppingList.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacing24),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: AppTheme.borderRadiusMedium,
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Let the dialog handle actual deletion
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadiusMedium,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: AppTheme.borderRadiusXL,
            boxShadow: AppTheme.shadowSm,
            border: Border.all(color: AppTheme.gray100),
          ),
          child: Row(
            children: [
              // Progress indicator with icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: progress >= 1.0
                      ? AppTheme.successLight
                      : AppTheme.accentPlayfulLight,
                  borderRadius: AppTheme.borderRadiusLarge,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                        backgroundColor: AppTheme.gray200,
                        color: progress >= 1.0
                            ? AppTheme.success
                            : AppTheme.accentPlayful,
                      ),
                    ),
                    Icon(
                      shoppingList.generatedFromSchedule
                          ? Icons.auto_awesome
                          : Icons.shopping_cart_outlined,
                      size: 14,
                      color: progress >= 1.0
                          ? AppTheme.success
                          : AppTheme.accentPlayful.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppTheme.spacing16),

              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shoppingList.name ?? 'Untitled List',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray900,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing6,
                            vertical: AppTheme.spacing2,
                          ),
                          decoration: BoxDecoration(
                            color: progress >= 1.0
                                ? AppTheme.successLight
                                : AppTheme.accentPlayfulLight,
                            borderRadius: AppTheme.borderRadiusFull,
                          ),
                          child: Text(
                            '${shoppingList.checkedCount}/${shoppingList.totalCount}',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: progress >= 1.0
                                  ? AppTheme.success
                                  : AppTheme.accentPlayful,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Text(
                          dateFormatter.format(shoppingList.createdAt),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppTheme.gray400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                color: AppTheme.gray300,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onCreate,
    required this.onGenerate,
  });

  final VoidCallback onCreate;
  final VoidCallback onGenerate;

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
              decoration: const BoxDecoration(
                color: AppTheme.accentPlayfulLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_basket_outlined,
                size: 36,
                color: AppTheme.accentPlayful,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'No shopping lists yet',
              style: AppTheme.displayTitleSmall(),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Create a shopping list or generate one from your kitchen schedule.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentPlayful,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create list'),
                ),
                OutlinedButton(
                  onPressed: onGenerate,
                  child: const Text('Generate from schedule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Body ───────────────────────────────────────────────────────────────

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
              'Couldn’t load shopping lists',
              style: AppTheme.displayTitleSmall(),
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
