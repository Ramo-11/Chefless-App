import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shopping_list.dart';
import '../../providers/shopping_list_provider.dart';
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => context.push('/search'),
          tooltip: 'Search',
        ),
        title: const Text('Shopping Lists'),
        actions: [
          const NotificationBellIcon(),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _openGenerateSheet(context),
            tooltip: 'Generate from schedule',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'shoppingListFab',
        onPressed: () => _showCreateDialog(context, ref),
        tooltip: 'Create shopping list',
        child: const Icon(Icons.add),
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: error.toString(),
          onRetry: () => ref.invalidate(shoppingListsProvider),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(shoppingListsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.only(
                top: AppTheme.spacing8,
                left: AppTheme.spacing16,
                right: AppTheme.spacing16,
                bottom: 80, // Space for FAB
              ),
              itemCount: lists.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.spacing8),
              itemBuilder: (context, index) {
                final list = lists[index];
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

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Shopping List'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'List name',
              hintText: 'e.g. Weekly groceries',
            ),
            onSubmitted: (_) =>
                _submitCreate(dialogContext, ref, controller),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  _submitCreate(dialogContext, ref, controller),
              child: const Text('Create'),
            ),
          ],
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
            color: Colors.white,
            borderRadius: AppTheme.borderRadiusMedium,
            border: Border.all(color: AppTheme.gray200),
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
                      : AppTheme.gray50,
                  borderRadius: AppTheme.borderRadiusMedium,
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
                            : AppTheme.primaryColor,
                      ),
                    ),
                    Icon(
                      shoppingList.generatedFromSchedule
                          ? Icons.auto_awesome
                          : Icons.shopping_cart_outlined,
                      size: 14,
                      color: progress >= 1.0
                          ? AppTheme.success
                          : AppTheme.gray500,
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
                                : AppTheme.gray50,
                            borderRadius: AppTheme.borderRadiusFull,
                          ),
                          child: Text(
                            '${shoppingList.checkedCount}/${shoppingList.totalCount}',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: progress >= 1.0
                                  ? AppTheme.success
                                  : AppTheme.gray600,
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
                Icons.shopping_cart_outlined,
                size: 36,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'No Shopping Lists',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.gray900,
                letterSpacing: -0.5,
              ),
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
