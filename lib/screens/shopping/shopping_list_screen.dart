import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shopping_list.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/extensions.dart';
import 'generate_list_sheet.dart';

/// The Shopping Lists tab — shows all shopping lists for the user.
class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(shoppingListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _openGenerateSheet(context),
            tooltip: 'Generate from schedule',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: AppTheme.spacingSm,
                bottom: 80, // Space for FAB
              ),
              itemCount: lists.length,
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
    ).then((_) => controller.dispose());
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
              style: TextStyle(color: context.colorScheme.error),
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
        padding: const EdgeInsets.only(right: AppTheme.spacingLg),
        color: context.colorScheme.error,
        child: Icon(
          Icons.delete_outline,
          color: context.colorScheme.onError,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Let the dialog handle actual deletion
      },
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingXs,
        ),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor:
                    context.colorScheme.surfaceContainerHighest,
                color: progress >= 1.0
                    ? context.colorScheme.primary
                    : context.colorScheme.secondary,
              ),
            ),
            Icon(
              shoppingList.generatedFromSchedule
                  ? Icons.auto_awesome
                  : Icons.shopping_cart_outlined,
              size: 18,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        title: Text(
          shoppingList.name ?? 'Untitled List',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${shoppingList.checkedCount}/${shoppingList.totalCount} items  ·  ${dateFormatter.format(shoppingList.createdAt)}',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: context.colorScheme.onSurfaceVariant,
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
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: context.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No Shopping Lists',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Create a shopping list or generate one from your kitchen schedule.',
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
