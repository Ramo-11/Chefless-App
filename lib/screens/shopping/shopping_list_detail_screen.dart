import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shopping_list.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/extensions.dart';

/// Detail view for a single shopping list, with items optionally grouped
/// by category. Supports notes, images, item editing, and group toggle.
class ShoppingListDetailScreen extends ConsumerStatefulWidget {
  const ShoppingListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ShoppingListDetailScreen> createState() =>
      _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState
    extends ConsumerState<ShoppingListDetailScreen> {
  bool _isEditingName = false;
  bool _groupByCategory = true;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditingName(String currentName) {
    _nameController.text = currentName;
    setState(() => _isEditingName = true);
  }

  void _saveNameEdit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      ref
          .read(shoppingListActionProvider.notifier)
          .updateListName(widget.listId, name);
    }
    setState(() => _isEditingName = false);
  }

  void _cancelNameEdit() {
    setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(shoppingListDetailProvider(widget.listId));

    return Scaffold(
      appBar: AppBar(
        title: _isEditingName
            ? TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _saveNameEdit(),
              )
            : GestureDetector(
                onTap: () {
                  final list = listAsync.valueOrNull;
                  if (list != null) {
                    _startEditingName(list.name ?? 'Untitled List');
                  }
                },
                child: Text(
                  listAsync.valueOrNull?.name ?? 'Shopping List',
                ),
              ),
        actions: [
          if (_isEditingName) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelNameEdit,
              tooltip: 'Cancel editing',
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveNameEdit,
              tooltip: 'Save name',
            ),
          ] else ...[
            // Group toggle
            IconButton(
              icon: Icon(
                _groupByCategory
                    ? Icons.view_agenda_outlined
                    : Icons.category_outlined,
              ),
              onPressed: () {
                if (mounted) {
                  setState(
                      () => _groupByCategory = !_groupByCategory);
                }
              },
              tooltip:
                  _groupByCategory ? 'Show flat list' : 'Group by category',
            ),
            if (listAsync.valueOrNull != null &&
                listAsync.valueOrNull!.checkedCount > 0)
              IconButton(
                icon: const Icon(Icons.cleaning_services_outlined),
                onPressed: () => _confirmClearCompleted(context),
                tooltip: 'Clear completed',
              ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddItemDialog(context),
              tooltip: 'Add item',
            ),
          ],
        ],
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: error.toString(),
          onRetry: () => ref.invalidate(
            shoppingListDetailProvider(widget.listId),
          ),
        ),
        data: (list) {
          if (list.items.isEmpty) {
            return const _EmptyItemsState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(shoppingListDetailProvider(widget.listId));
            },
            child: _groupByCategory
                ? _GroupedItemsList(
                    shoppingList: list,
                    listId: widget.listId,
                    onEditItem: _showEditItemDialog,
                  )
                : _FlatItemsList(
                    shoppingList: list,
                    listId: widget.listId,
                    onEditItem: _showEditItemDialog,
                  ),
          );
        },
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    final categoryController = TextEditingController();
    final notesController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g. Chicken breast',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          hintText: '2',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: TextField(
                        controller: unitController,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'lbs',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: categoryController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                    hintText: 'e.g. Produce',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: notesController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Get organic if available',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogContext).pop();
                final qty = double.tryParse(quantityController.text.trim());
                final unit = unitController.text.trim();
                final category = categoryController.text.trim();
                final notes = notesController.text.trim();
                ref.read(shoppingListActionProvider.notifier).addItem(
                      widget.listId,
                      name: name,
                      quantity: qty,
                      unit: unit.isNotEmpty ? unit : null,
                      category: category.isNotEmpty ? category : null,
                      notes: notes.isNotEmpty ? notes : null,
                    );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((_) {
      nameController.dispose();
      quantityController.dispose();
      unitController.dispose();
      categoryController.dispose();
      notesController.dispose();
    });
  }

  void _showEditItemDialog(ShoppingItem item) {
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(
      text: item.quantity != null
          ? (item.quantity == item.quantity!.roundToDouble()
              ? item.quantity!.toInt().toString()
              : item.quantity.toString())
          : '',
    );
    final unitController = TextEditingController(text: item.unit ?? '');
    final categoryController =
        TextEditingController(text: item.category ?? '');
    final notesController = TextEditingController(text: item.notes ?? '');
    String? currentImageUrl = item.imageUrl;
    bool isUploadingImage = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: TextField(
                            controller: unitController,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextField(
                      controller: categoryController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    TextField(
                      controller: notesController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    // Image section
                    if (currentImageUrl != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: AppTheme.borderRadiusMedium,
                            child: Image.network(
                              currentImageUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 120,
                                color: context
                                    .colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(
                                    () => currentImageUrl = null);
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () async {
                                final url = await _pickItemImage(
                                    setDialogState,
                                    (v) => isUploadingImage = v);
                                if (url != null) {
                                  setDialogState(
                                      () => currentImageUrl = url);
                                }
                              },
                        icon: isUploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined,
                                size: 18),
                        label: Text(
                            isUploadingImage ? 'Uploading...' : 'Add Photo'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(dialogContext).pop();

                    final qty =
                        double.tryParse(quantityController.text.trim());
                    final unit = unitController.text.trim();
                    final category = categoryController.text.trim();
                    final notes = notesController.text.trim();

                    ref.read(shoppingListActionProvider.notifier).updateItem(
                          widget.listId,
                          item.id,
                          name: name != item.name ? name : null,
                          quantity: qty,
                          unit: unit.isNotEmpty ? unit : null,
                          category: category.isNotEmpty ? category : null,
                          notes: notes.isNotEmpty ? notes : null,
                          imageUrl: currentImageUrl,
                          clearQuantity: qty == null && item.quantity != null,
                          clearUnit:
                              unit.isEmpty && item.unit != null,
                          clearCategory:
                              category.isEmpty && item.category != null,
                          clearNotes:
                              notes.isEmpty && item.notes != null,
                          clearImageUrl: currentImageUrl == null &&
                              item.imageUrl != null,
                        );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      quantityController.dispose();
      unitController.dispose();
      categoryController.dispose();
      notesController.dispose();
    });
  }

  Future<String?> _pickItemImage(
    void Function(void Function()) setDialogState,
    void Function(bool) setUploading,
  ) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (image == null) return null;

    setDialogState(() => setUploading(true));

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final bytes = await image.readAsBytes();
      final fileName = image.name;

      final result = await apiService.post(
        '/recipes/upload-photo',
        data: {
          'file': bytes.toList(),
          'fileName': fileName,
        },
      );

      setDialogState(() => setUploading(false));

      if (result.isSuccess && result.data != null) {
        return result.data!['url'] as String;
      }
      return null;
    } catch (_) {
      setDialogState(() => setUploading(false));
      return null;
    }
  }

  void _confirmClearCompleted(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear completed items'),
        content: const Text(
          'Remove all checked items from this list? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Clear',
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref
            .read(shoppingListActionProvider.notifier)
            .clearCompleted(widget.listId);
      }
    });
  }
}

// ── Flat Items List (no grouping) ────────────────────────────────────────────

class _FlatItemsList extends ConsumerWidget {
  const _FlatItemsList({
    required this.shoppingList,
    required this.listId,
    required this.onEditItem,
  });

  final ShoppingList shoppingList;
  final String listId;
  final void Function(ShoppingItem) onEditItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sort: unchecked first, then checked, alphabetically within each group.
    final sorted = List<ShoppingItem>.from(shoppingList.items)
      ..sort((a, b) {
        if (a.isChecked != b.isChecked) {
          return a.isChecked ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXl),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return _ShoppingItemTile(
          item: sorted[index],
          listId: listId,
          onEdit: onEditItem,
        );
      },
    );
  }
}

// ── Grouped Items List ───────────────────────────────────────────────────────

class _GroupedItemsList extends ConsumerWidget {
  const _GroupedItemsList({
    required this.shoppingList,
    required this.listId,
    required this.onEditItem,
  });

  final ShoppingList shoppingList;
  final String listId;
  final void Function(ShoppingItem) onEditItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorized = <String, List<ShoppingItem>>{};
    const uncategorizedKey = 'Uncategorized';

    for (final item in shoppingList.items) {
      final cat = (item.category != null && item.category!.isNotEmpty)
          ? item.category!
          : uncategorizedKey;
      categorized.putIfAbsent(cat, () => []).add(item);
    }

    final sortedKeys = categorized.keys.toList()
      ..sort((a, b) {
        if (a == uncategorizedKey) return 1;
        if (b == uncategorizedKey) return -1;
        return a.compareTo(b);
      });

    for (final key in sortedKeys) {
      categorized[key]!.sort((a, b) {
        if (a.isChecked != b.isChecked) {
          return a.isChecked ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXl),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final category = sortedKeys[index];
        final items = categorized[category]!;

        return _CategorySection(
          category: category,
          items: items,
          listId: listId,
          onEditItem: onEditItem,
        );
      },
    );
  }
}

// ── Category Section ─────────────────────────────────────────────────────────

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.category,
    required this.items,
    required this.listId,
    required this.onEditItem,
  });

  final String category;
  final List<ShoppingItem> items;
  final String listId;
  final void Function(ShoppingItem) onEditItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          color: context.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          child: Text(
            category,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...items.map((item) {
          return _ShoppingItemTile(
            item: item,
            listId: listId,
            onEdit: onEditItem,
          );
        }),
      ],
    );
  }
}

// ── Shopping Item Tile ───────────────────────────────────────────────────────

class _ShoppingItemTile extends ConsumerWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.listId,
    required this.onEdit,
  });

  final ShoppingItem item;
  final String listId;
  final void Function(ShoppingItem) onEdit;

  String get _quantityLabel {
    if (item.quantity == null) return '';
    final qty = item.quantity!;
    final qtyStr =
        qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
    if (item.unit != null && item.unit!.isNotEmpty) {
      return '$qtyStr ${item.unit}';
    }
    return qtyStr;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNotes = item.notes != null && item.notes!.isNotEmpty;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    const checkedAlpha = 0.5;

    return Dismissible(
      key: ValueKey(item.id),
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
      onDismissed: (_) {
        ref
            .read(shoppingListActionProvider.notifier)
            .removeItem(listId, item.id);
      },
      child: InkWell(
        onTap: () {
          ref
              .read(shoppingListActionProvider.notifier)
              .toggleItem(listId, item.id);
        },
        onLongPress: () => onEdit(item),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    context.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: item.isChecked,
                    onChanged: (_) {
                      ref
                          .read(shoppingListActionProvider.notifier)
                          .toggleItem(listId, item.id);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.spacingSm),

              // Image thumbnail
              if (hasImage) ...[
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spacingSm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      item.imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        width: 40,
                        height: 40,
                        color: context.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 16),
                      ),
                    ),
                  ),
                ),
              ],

              // Name, quantity, notes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              decoration: item.isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.isChecked
                                  ? context.colorScheme.onSurfaceVariant
                                      .withValues(alpha: checkedAlpha)
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_quantityLabel.isNotEmpty) ...[
                          const SizedBox(width: AppTheme.spacingSm),
                          Text(
                            _quantityLabel,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: item.isChecked
                                  ? context.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4)
                                  : context.colorScheme.onSurfaceVariant,
                              decoration: item.isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (hasNotes) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.notes!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: item.isChecked
                              ? context.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4)
                              : context.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Edit button
              IconButton(
                onPressed: () => onEdit(item),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                tooltip: 'Edit item',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty Items State ────────────────────────────────────────────────────────

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist,
              size: 64,
              color: context.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No Items Yet',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Tap the + button to add items to your shopping list.',
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
