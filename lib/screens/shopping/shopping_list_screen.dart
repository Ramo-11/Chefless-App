import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shopping_list.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/app_help_content.dart';
import '../../utils/app_icons.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_top_bar.dart';
import 'generate_list_sheet.dart';

/// Filter mode for the shopping list screen.
enum _ListFilter { all, shared, private_ }

/// The Shopping Lists tab — shows all shopping lists for the user.
class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() =>
      _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  _ListFilter _filter = _ListFilter.all;

  List<ShoppingList> _applyFilter(List<ShoppingList> lists) {
    switch (_filter) {
      case _ListFilter.all:
        return lists;
      case _ListFilter.shared:
        return lists.where((l) => l.isShared).toList();
      case _ListFilter.private_:
        return lists.where((l) => !l.isShared).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(shoppingListsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final hasKitchen = currentUser?.kitchenId != null;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
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
        onPressed: () => _showCreateSheet(context, ref, hasKitchen),
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
              onCreate: () => _showCreateSheet(context, ref, hasKitchen),
              onGenerate: () => _openGenerateSheet(context),
            );
          }

          final filtered = _applyFilter(lists);
          final hasShared = lists.any((l) => l.isShared);
          final hasPrivate = lists.any((l) => !l.isShared);
          final showFilters = hasShared && hasPrivate;

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
              itemCount: filtered.length + (showFilters ? 2 : 1),
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppTheme.spacing12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ShoppingOverviewCard(lists: lists);
                }

                if (showFilters && index == 1) {
                  return _FilterChips(
                    filter: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  );
                }

                final listIndex = index - (showFilters ? 2 : 1);
                final list = filtered[listIndex];
                return _ShoppingListTile(
                  shoppingList: list,
                  hasKitchen: hasKitchen,
                  onTap: () => context.push('/shopping/${list.id}'),
                  onAction: (action) =>
                      _handleListAction(context, ref, list, action),
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

  void _showCreateSheet(
    BuildContext context,
    WidgetRef ref,
    bool hasKitchen,
  ) {
    final controller = TextEditingController();
    bool isPrivate = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
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
                    onSubmitted: (_) => _submitCreate(
                      sheetContext,
                      ref,
                      controller,
                      isPrivate: isPrivate,
                    ),
                  ),
                  if (hasKitchen) ...[
                    const SizedBox(height: AppTheme.spacing16),
                    _VisibilityToggle(
                      isPrivate: isPrivate,
                      onChanged: (v) =>
                          setSheetState(() => isPrivate = v),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacing20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _submitCreate(
                        sheetContext,
                        ref,
                        controller,
                        isPrivate: isPrivate,
                      ),
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
      },
    );
  }

  void _submitCreate(
    BuildContext dialogContext,
    WidgetRef ref,
    TextEditingController controller, {
    bool isPrivate = false,
  }) {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(dialogContext).pop();
    ref
        .read(shoppingListActionProvider.notifier)
        .createList(name: name, isPrivate: isPrivate ? true : null)
        .then(
      (listId) {
        if (listId != null && dialogContext.mounted) {
          dialogContext.push('/shopping/$listId');
        }
      },
    );
  }

  void _handleListAction(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
    _ListAction action,
  ) {
    switch (action) {
      case _ListAction.rename:
        _showRenameSheet(context, ref, list);
      case _ListAction.duplicate:
        ref
            .read(shoppingListActionProvider.notifier)
            .duplicateList(list.id)
            .then((newId) {
          if (newId != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('List duplicated'),
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () => context.push('/shopping/$newId'),
                ),
              ),
            );
          }
        });
      case _ListAction.toggleVisibility:
        final willBePrivate = list.isShared;
        ref
            .read(shoppingListActionProvider.notifier)
            .updateListVisibility(list.id, isPrivate: willBePrivate);
      case _ListAction.share:
        _shareAsText(context, list);
      case _ListAction.delete:
        _confirmDelete(context, ref, list);
    }
  }

  void _showRenameSheet(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) {
    final controller =
        TextEditingController(text: list.name ?? 'Untitled List');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

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
              Text('Rename list', style: AppTheme.displayTitleSmall()),
              const SizedBox(height: AppTheme.spacing20),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'List name'),
                onSubmitted: (_) {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(shoppingListActionProvider.notifier)
                      .updateListName(list.id, name);
                },
              ),
              const SizedBox(height: AppTheme.spacing20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(sheetContext).pop();
                    ref
                        .read(shoppingListActionProvider.notifier)
                        .updateListName(list.id, name);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentPlayful,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareAsText(BuildContext context, ShoppingList list) {
    final buffer = StringBuffer();
    buffer.writeln(list.name ?? 'Shopping List');
    buffer.writeln('${'─' * 24}');

    final unchecked =
        list.items.where((i) => !i.isChecked).toList()..sort((a, b) => a.name.compareTo(b.name));
    final checked =
        list.items.where((i) => i.isChecked).toList()..sort((a, b) => a.name.compareTo(b.name));

    for (final item in unchecked) {
      final qty = item.quantity != null
          ? ' (${item.quantity == item.quantity!.roundToDouble() ? item.quantity!.toInt() : item.quantity}${item.unit != null ? ' ${item.unit}' : ''})'
          : '';
      buffer.writeln('☐ ${item.name}$qty');
    }
    for (final item in checked) {
      buffer.writeln('☑ ${item.name}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List copied to clipboard')),
      );
    }
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
        ref.read(shoppingListActionProvider.notifier).deleteList(list.id);
      }
    });
  }
}

// ── Visibility Toggle ────────────────────────────────────────────────────────

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({
    required this.isPrivate,
    required this.onChanged,
  });

  final bool isPrivate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: AppTheme.borderRadiusLarge,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              label: 'Shared',
              icon: Icons.people_outline_rounded,
              isSelected: !isPrivate,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ToggleOption(
              label: 'Just me',
              icon: Icons.lock_outline_rounded,
              isSelected: isPrivate,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spacing12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: AppTheme.borderRadiusMedium,
          boxShadow: isSelected ? AppTheme.shadowSm : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.accentPlayful : AppTheme.gray400,
            ),
            const SizedBox(width: AppTheme.spacing6),
            Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.gray900 : AppTheme.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter Chips ─────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.onChanged,
  });

  final _ListFilter filter;
  final ValueChanged<_ListFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'All',
          isSelected: filter == _ListFilter.all,
          onTap: () => onChanged(_ListFilter.all),
        ),
        const SizedBox(width: AppTheme.spacing8),
        _FilterChip(
          label: 'Shared',
          icon: Icons.people_outline_rounded,
          isSelected: filter == _ListFilter.shared,
          onTap: () => onChanged(_ListFilter.shared),
        ),
        const SizedBox(width: AppTheme.spacing8),
        _FilterChip(
          label: 'Private',
          icon: Icons.lock_outline_rounded,
          isSelected: filter == _ListFilter.private_,
          onTap: () => onChanged(_ListFilter.private_),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentPlayful : Colors.white,
          borderRadius: AppTheme.borderRadiusFull,
          border: Border.all(
            color:
                isSelected ? AppTheme.accentPlayful : AppTheme.gray200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.gray500,
              ),
              const SizedBox(width: AppTheme.spacing4),
            ],
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.gray600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overview Card ───────────────────────────────────────────────────────────

class _ShoppingOverviewCard extends StatelessWidget {
  const _ShoppingOverviewCard({required this.lists});

  final List<ShoppingList> lists;

  @override
  Widget build(BuildContext context) {
    final generatedCount =
        lists.where((list) => list.generatedFromSchedule).length;
    final completedCount = lists
        .where(
            (list) => list.totalCount > 0 && list.checkedCount == list.totalCount)
        .length;

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

// ── List Actions ────────────────────────────────────────────────────────────

enum _ListAction { rename, duplicate, toggleVisibility, share, delete }

// ── Shopping List Tile ──────────────────────────────────────────────────────

class _ShoppingListTile extends StatelessWidget {
  const _ShoppingListTile({
    required this.shoppingList,
    required this.hasKitchen,
    required this.onTap,
    required this.onAction,
  });

  final ShoppingList shoppingList;
  final bool hasKitchen;
  final VoidCallback onTap;
  final void Function(_ListAction) onAction;

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing20,
                  AppTheme.spacing16,
                  AppTheme.spacing20,
                  AppTheme.spacing8,
                ),
                child: Text(
                  shoppingList.name ?? 'Untitled List',
                  style: AppTheme.displayTitleSmall(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ActionTile(
                icon: Icons.edit_outlined,
                label: 'Rename',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAction(_ListAction.rename);
                },
              ),
              _ActionTile(
                icon: Icons.copy_outlined,
                label: 'Duplicate',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAction(_ListAction.duplicate);
                },
              ),
              if (hasKitchen)
                _ActionTile(
                  icon: shoppingList.isShared
                      ? Icons.lock_outline_rounded
                      : Icons.people_outline_rounded,
                  label: shoppingList.isShared
                      ? 'Make private'
                      : 'Share with kitchen',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onAction(_ListAction.toggleVisibility);
                  },
                ),
              _ActionTile(
                icon: AppIcons.share,
                label: 'Copy as text',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAction(_ListAction.share);
                },
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.delete_outline,
                label: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onAction(_ListAction.delete);
                },
              ),
              const SizedBox(height: AppTheme.spacing8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, yyyy');
    final progress = shoppingList.totalCount > 0
        ? shoppingList.checkedCount / shoppingList.totalCount
        : 0.0;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showActionSheet(context),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shoppingList.name ?? 'Untitled List',
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
                      // Privacy badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing6,
                          vertical: AppTheme.spacing2,
                        ),
                        decoration: BoxDecoration(
                          color: shoppingList.isShared
                              ? AppTheme.primaryLight
                              : AppTheme.gray100,
                          borderRadius: AppTheme.borderRadiusFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              shoppingList.isShared
                                  ? Icons.people_outline_rounded
                                  : Icons.lock_outline_rounded,
                              size: 10,
                              color: shoppingList.isShared
                                  ? AppTheme.primaryColor
                                  : AppTheme.gray500,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              shoppingList.isShared ? 'Shared' : 'Private',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: shoppingList.isShared
                                    ? AppTheme.primaryColor
                                    : AppTheme.gray500,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          dateFormatter.format(shoppingList.createdAt),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppTheme.gray400,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // More button
            IconButton(
              onPressed: () => _showActionSheet(context),
              icon: Icon(
                Icons.more_vert_rounded,
                color: AppTheme.gray400,
                size: 20,
              ),
              tooltip: 'More options',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action Tile (for bottom sheet) ──────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.error : AppTheme.gray900;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: context.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing20,
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

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
              'Couldn\'t load shopping lists',
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
