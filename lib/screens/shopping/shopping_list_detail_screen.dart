import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shopping_list.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/app_icons.dart';
import '../../utils/extensions.dart';

void _showShoppingItemPhotoViewer(BuildContext context, String imageUrl) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (dialogContext) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(AppTheme.spacing24),
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(AppTheme.spacing24),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(dialogContext).top + AppTheme.spacing8,
              right: AppTheme.spacing8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.gray900.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      );
    },
  );
}

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
  late TextEditingController _quickAddController;
  late FocusNode _quickAddFocus;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quickAddController = TextEditingController();
    _quickAddFocus = FocusNode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quickAddController.dispose();
    _quickAddFocus.dispose();
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

  void _quickAdd() {
    final name = _quickAddController.text.trim();
    if (name.isEmpty) {
      _showShoppingItemSheet(null);
      return;
    }
    _quickAddController.clear();
    ref.read(shoppingListActionProvider.notifier).addItem(
          widget.listId,
          name: name,
        );
    // Keep focus for rapid entry
    _quickAddFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(shoppingListDetailProvider(widget.listId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final hasKitchen = currentUser?.kitchenId != null;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: _isEditingName
            ? TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
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
                  style: AppTheme.displayTitleSmall(),
                ),
              ),
        actions: [
          if (_isEditingName) ...[
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _cancelNameEdit,
              tooltip: 'Cancel editing',
            ),
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: _saveNameEdit,
              tooltip: 'Save name',
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                _groupByCategory
                    ? Icons.view_agenda_outlined
                    : Icons.category_outlined,
              ),
              onPressed: () {
                if (mounted) {
                  setState(() => _groupByCategory = !_groupByCategory);
                }
              },
              tooltip:
                  _groupByCategory ? 'Show flat list' : 'Group by category',
            ),
            _DetailMoreMenu(
              listAsync: listAsync,
              listId: widget.listId,
              hasKitchen: hasKitchen,
              onAddItem: () => _showShoppingItemSheet(null),
              onUncheckAll: () {
                ref
                    .read(shoppingListActionProvider.notifier)
                    .uncheckAll(widget.listId);
              },
              onClearCompleted: () => _confirmClearCompleted(context),
              onToggleVisibility: () {
                final list = listAsync.valueOrNull;
                if (list == null) return;
                ref
                    .read(shoppingListActionProvider.notifier)
                    .updateListVisibility(
                      widget.listId,
                      isPrivate: list.isShared,
                    );
              },
              onShareAsText: () {
                final list = listAsync.valueOrNull;
                if (list == null) return;
                _shareAsText(context, list);
              },
              onDuplicate: () {
                ref
                    .read(shoppingListActionProvider.notifier)
                    .duplicateList(widget.listId)
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
              },
              onDelete: () => _confirmDeleteList(context),
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
          return Column(
            children: [
              // Overview card
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing12,
                  AppTheme.spacing16,
                  AppTheme.spacing8,
                ),
                child: _ShoppingListOverviewCard(
                  shoppingList: list,
                  groupByCategory: _groupByCategory,
                ),
              ),

              // Items list
              Expanded(
                child: list.items.isEmpty
                    ? const SingleChildScrollView(child: _EmptyItemsState())
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(
                              shoppingListDetailProvider(widget.listId));
                        },
                        child: _groupByCategory
                            ? _GroupedItemsList(
                                shoppingList: list,
                                listId: widget.listId,
                                onEditItem: _showShoppingItemSheet,
                                onViewItemImage: (url) =>
                                    _showShoppingItemPhotoViewer(context, url),
                              )
                            : _FlatItemsList(
                                shoppingList: list,
                                listId: widget.listId,
                                onEditItem: _showShoppingItemSheet,
                                onViewItemImage: (url) =>
                                    _showShoppingItemPhotoViewer(context, url),
                              ),
                      ),
              ),

              // Quick-add bar
              _QuickAddBar(
                controller: _quickAddController,
                focusNode: _quickAddFocus,
                onSubmit: _quickAdd,
              ),
            ],
          );
        },
      ),
    );
  }

  void _shareAsText(BuildContext context, ShoppingList list) {
    final buffer = StringBuffer();
    buffer.writeln(list.name ?? 'Shopping List');
    buffer.writeln('${'─' * 24}');

    final unchecked = list.items.where((i) => !i.isChecked).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final checked = list.items.where((i) => i.isChecked).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

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

  void _showShoppingItemSheet(ShoppingItem? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final quantityController = TextEditingController(
      text: existing?.quantity != null
          ? (existing!.quantity == existing.quantity!.roundToDouble()
              ? existing.quantity!.toInt().toString()
              : existing.quantity.toString())
          : '',
    );
    final unitController = TextEditingController(text: existing?.unit ?? '');
    final categoryController =
        TextEditingController(text: existing?.category ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    String? currentImageUrl = existing?.imageUrl;
    bool isUploadingImage = false;
    final isEditing = existing != null;

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      isEditing ? 'Edit Item' : 'Add Item',
                      style: AppTheme.displayTitleSmall(),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    TextField(
                      controller: nameController,
                      autofocus: !isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Item name',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
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
                        const SizedBox(width: AppTheme.spacing12),
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
                    const SizedBox(height: AppTheme.spacing12),
                    TextField(
                      controller: categoryController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    TextField(
                      controller: notesController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
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
                                decoration: BoxDecoration(
                                  color: AppTheme.gray100,
                                  borderRadius: AppTheme.borderRadiusMedium,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: AppTheme.gray400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: AppTheme.spacing6,
                            right: AppTheme.spacing6,
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(() => currentImageUrl = null);
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.gray900.withValues(alpha: 0.6),
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
                                    setSheetState,
                                    (v) => isUploadingImage = v);
                                if (url != null) {
                                  setSheetState(
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
                    const SizedBox(height: AppTheme.spacing20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty) return;
                              Navigator.of(sheetContext).pop();

                              final qty = double.tryParse(
                                  quantityController.text.trim());
                              final unit = unitController.text.trim();
                              final category =
                                  categoryController.text.trim();
                              final notes = notesController.text.trim();

                              final notifier = ref
                                  .read(shoppingListActionProvider.notifier);
                              if (existing == null) {
                                notifier.addItem(
                                  widget.listId,
                                  name: name,
                                  quantity: qty,
                                  unit: unit.isNotEmpty ? unit : null,
                                  category: category.isNotEmpty
                                      ? category
                                      : null,
                                  notes:
                                      notes.isNotEmpty ? notes : null,
                                  imageUrl: currentImageUrl,
                                );
                              } else {
                                final item = existing;
                                notifier.updateItem(
                                  widget.listId,
                                  item.id,
                                  name: name != item.name ? name : null,
                                  quantity: qty,
                                  unit: unit.isNotEmpty ? unit : null,
                                  category:
                                      category.isNotEmpty ? category : null,
                                  notes:
                                      notes.isNotEmpty ? notes : null,
                                  imageUrl: currentImageUrl,
                                  clearQuantity:
                                      qty == null && item.quantity != null,
                                  clearUnit:
                                      unit.isEmpty && item.unit != null,
                                  clearCategory: category.isEmpty &&
                                      item.category != null,
                                  clearNotes:
                                      notes.isEmpty && item.notes != null,
                                  clearImageUrl: currentImageUrl == null &&
                                      item.imageUrl != null,
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.accentPlayful,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isEditing ? 'Save' : 'Add'),
                          ),
                        ),
                      ],
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

  Future<ImageSource?> _chooseImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickItemImage(
    void Function(void Function()) setDialogState,
    void Function(bool) setUploading,
  ) async {
    try {
      final source = await _chooseImageSource();
      if (source == null) return null;

      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);

      if (image == null) return null;

      setDialogState(() => setUploading(true));

      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/recipes/upload-photo',
        data: {'image': dataUri},
      );

      setDialogState(() => setUploading(false));

      if (result.isSuccess && result.data != null) {
        return result.data!['secureUrl'] as String?;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to upload photo')),
        );
      }
      return null;
    } catch (e) {
      setDialogState(() => setUploading(false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload photo')),
        );
      }
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
              style: TextStyle(color: AppTheme.error),
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

  void _confirmDeleteList(BuildContext context) {
    final listAsync = ref.read(shoppingListDetailProvider(widget.listId));
    final listName = listAsync.valueOrNull?.name ?? 'Untitled';

    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete shopping list'),
        content: Text(
          'Are you sure you want to delete "$listName"? This cannot be undone.',
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
            .deleteList(widget.listId)
            .then((success) {
          if (success && context.mounted) {
            context.pop();
          }
        });
      }
    });
  }
}

// ── Detail More Menu ────────────────────────────────────────────────────────

class _DetailMoreMenu extends StatelessWidget {
  const _DetailMoreMenu({
    required this.listAsync,
    required this.listId,
    required this.hasKitchen,
    required this.onAddItem,
    required this.onUncheckAll,
    required this.onClearCompleted,
    required this.onToggleVisibility,
    required this.onShareAsText,
    required this.onDuplicate,
    required this.onDelete,
  });

  final AsyncValue<ShoppingList> listAsync;
  final String listId;
  final bool hasKitchen;
  final VoidCallback onAddItem;
  final VoidCallback onUncheckAll;
  final VoidCallback onClearCompleted;
  final VoidCallback onToggleVisibility;
  final VoidCallback onShareAsText;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final list = listAsync.valueOrNull;
    final hasChecked = list != null && list.checkedCount > 0;
    final hasItems = list != null && list.totalCount > 0;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: 'More options',
      onSelected: (value) {
        switch (value) {
          case 'add':
            onAddItem();
          case 'uncheck':
            onUncheckAll();
          case 'clear':
            onClearCompleted();
          case 'visibility':
            onToggleVisibility();
          case 'share':
            onShareAsText();
          case 'duplicate':
            onDuplicate();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'add',
          child: ListTile(
            leading: Icon(Icons.add_rounded, size: 20),
            title: Text('Add item'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (hasItems)
          const PopupMenuItem(
            value: 'uncheck',
            child: ListTile(
              leading: Icon(Icons.check_box_outline_blank_rounded, size: 20),
              title: Text('Uncheck all'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (hasChecked)
          PopupMenuItem(
            value: 'clear',
            child: ListTile(
              leading: Icon(Icons.cleaning_services_outlined,
                  size: 20, color: AppTheme.warning),
              title: Text('Clear completed',
                  style: TextStyle(color: AppTheme.warning)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuDivider(),
        if (hasKitchen)
          PopupMenuItem(
            value: 'visibility',
            child: ListTile(
              leading: Icon(
                list?.isShared == true
                    ? Icons.lock_outline_rounded
                    : Icons.people_outline_rounded,
                size: 20,
              ),
              title: Text(
                  list?.isShared == true ? 'Make private' : 'Share with kitchen'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (hasItems)
          const PopupMenuItem(
            value: 'share',
            child: ListTile(
              leading: Icon(AppIcons.share, size: 20),
              title: Text('Copy as text'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            leading: Icon(Icons.copy_outlined, size: 20),
            title: Text('Duplicate list'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
            title: Text('Delete list',
                style: TextStyle(color: AppTheme.error)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

// ── Quick Add Bar ───────────────────────────────────────────────────────────

class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.spacing16,
        right: AppTheme.spacing8,
        top: AppTheme.spacing8,
        bottom: bottomInset > 0 ? AppTheme.spacing8 : AppTheme.spacing8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(top: BorderSide(color: AppTheme.gray100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Item name',
                hintStyle: TextStyle(color: AppTheme.gray400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.gray200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.gray200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppTheme.accentPlayful, width: 1.5),
                ),
                filled: true,
                fillColor: AppTheme.gray50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing12,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: AppTheme.spacing4),
          IconButton(
            onPressed: onSubmit,
            icon: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.accentPlayful,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            tooltip:
                'Add this name to the list. If the field is empty, opens the full form (photo, quantity, notes).',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overview Card ───────────────────────────────────────────────────────────

class _ShoppingListOverviewCard extends StatelessWidget {
  const _ShoppingListOverviewCard({
    required this.shoppingList,
    required this.groupByCategory,
  });

  final ShoppingList shoppingList;
  final bool groupByCategory;

  @override
  Widget build(BuildContext context) {
    final total = shoppingList.totalCount;
    final checked = shoppingList.checkedCount;
    final remaining = (total - checked).clamp(0, total);
    final progress = total > 0 ? checked / total : 0.0;

    return Container(
      width: double.infinity,
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
            AppTheme.accentPlayfulLight.withValues(alpha: 0.68),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with privacy badge
          Row(
            children: [
              Expanded(
                child: Text(
                  shoppingList.generatedFromSchedule
                      ? 'Generated from your schedule'
                      : 'Your current shopping list',
                  style: AppTheme.displayTitleSmall(),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
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
                      size: 12,
                      color: shoppingList.isShared
                          ? AppTheme.primaryColor
                          : AppTheme.gray500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      shoppingList.isShared ? 'Shared' : 'Private',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: shoppingList.isShared
                            ? AppTheme.primaryColor
                            : AppTheme.gray500,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            remaining == 0 && total > 0
                ? 'Everything on this list is checked off.'
                : total == 0
                    ? 'Add items to get started.'
                    : '$remaining item${remaining == 1 ? '' : 's'} left to pick up.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
              height: 1.45,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: AppTheme.spacing12),
            // Progress bar
            ClipRRect(
              borderRadius: AppTheme.borderRadiusFull,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppTheme.gray200,
                color:
                    progress >= 1.0 ? AppTheme.success : AppTheme.accentPlayful,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
          ] else
            const SizedBox(height: AppTheme.spacing16),
          Wrap(
            spacing: AppTheme.spacing12,
            runSpacing: AppTheme.spacing8,
            children: [
              _OverviewCount(label: 'Total', value: '$total'),
              _OverviewCount(label: 'Done', value: '$checked'),
              _OverviewCount(
                label: 'View',
                value: groupByCategory ? 'Grouped' : 'Flat',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewCount extends StatelessWidget {
  const _OverviewCount({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: RichText(
        text: TextSpan(
          style: context.textTheme.labelMedium?.copyWith(
            color: AppTheme.gray600,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(color: AppTheme.textPrimaryDeep),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flat Items List (no grouping) ───────────────────────────────────────────

class _FlatItemsList extends ConsumerWidget {
  const _FlatItemsList({
    required this.shoppingList,
    required this.listId,
    required this.onEditItem,
    required this.onViewItemImage,
  });

  final ShoppingList shoppingList;
  final String listId;
  final void Function(ShoppingItem?) onEditItem;
  final void Function(String imageUrl) onViewItemImage;

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
      padding: const EdgeInsets.only(bottom: AppTheme.spacing32),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return _ShoppingItemTile(
          item: sorted[index],
          listId: listId,
          onEdit: onEditItem,
          onViewImage: onViewItemImage,
        );
      },
    );
  }
}

// ── Grouped Items List ──────────────────────────────────────────────────────

class _GroupedItemsList extends ConsumerWidget {
  const _GroupedItemsList({
    required this.shoppingList,
    required this.listId,
    required this.onEditItem,
    required this.onViewItemImage,
  });

  final ShoppingList shoppingList;
  final String listId;
  final void Function(ShoppingItem?) onEditItem;
  final void Function(String imageUrl) onViewItemImage;

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
      padding: const EdgeInsets.only(bottom: AppTheme.spacing32),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final category = sortedKeys[index];
        final items = categorized[category]!;

        return _CategorySection(
          category: category,
          items: items,
          listId: listId,
          onEditItem: onEditItem,
          onViewItemImage: onViewItemImage,
        );
      },
    );
  }
}

// ── Category Section ────────────────────────────────────────────────────────

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.category,
    required this.items,
    required this.listId,
    required this.onEditItem,
    required this.onViewItemImage,
  });

  final String category;
  final List<ShoppingItem> items;
  final String listId;
  final void Function(ShoppingItem?) onEditItem;
  final void Function(String imageUrl) onViewItemImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing20,
            vertical: AppTheme.spacing8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.accentPlayfulLight.withValues(alpha: 0.75),
          ),
          child: Row(
            children: [
              Text(
                category.toUpperCase(),
                style: context.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray500,
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing6,
                  vertical: AppTheme.spacing2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: AppTheme.borderRadiusFull,
                ),
                child: Text(
                  '${items.length}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: AppTheme.gray600,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) {
          return _ShoppingItemTile(
            item: item,
            listId: listId,
            onEdit: onEditItem,
            onViewImage: onViewItemImage,
          );
        }),
      ],
    );
  }
}

// ── Shopping Item Tile ──────────────────────────────────────────────────────

class _ShoppingItemTile extends ConsumerStatefulWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.listId,
    required this.onEdit,
    required this.onViewImage,
  });

  final ShoppingItem item;
  final String listId;
  final void Function(ShoppingItem?) onEdit;
  final void Function(String imageUrl) onViewImage;

  @override
  ConsumerState<_ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends ConsumerState<_ShoppingItemTile> {
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.item.isChecked;
  }

  @override
  void didUpdateWidget(covariant _ShoppingItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id ||
        widget.item.isChecked != oldWidget.item.isChecked) {
      _isChecked = widget.item.isChecked;
    }
  }

  void _toggle() {
    final wasChecked = _isChecked;
    if (mounted) setState(() => _isChecked = !_isChecked);
    ref
        .read(shoppingListActionProvider.notifier)
        .toggleItem(widget.listId, widget.item.id)
        .then((success) {
      if (!success && mounted) {
        setState(() => _isChecked = wasChecked);
      }
    });
  }

  String get _quantityLabel {
    if (widget.item.quantity == null) return '';
    final qty = widget.item.quantity!;
    final qtyStr =
        qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
    if (widget.item.unit != null && widget.item.unit!.isNotEmpty) {
      return '$qtyStr ${widget.item.unit}';
    }
    return qtyStr;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasNotes = item.notes != null && item.notes!.isNotEmpty;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacing24),
        color: AppTheme.error,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (_) async {
        ref
            .read(shoppingListActionProvider.notifier)
            .removeItem(widget.listId, item.id);
        return true;
      },
      child: InkWell(
        onTap: _toggle,
        onLongPress: () => widget.onEdit(item),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: _isChecked ? AppTheme.gray50 : AppTheme.surfaceElevated,
            border: Border(
              bottom: BorderSide(color: AppTheme.gray100),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _isChecked,
                    onChanged: (_) => _toggle(),
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.spacing12),

              // Image thumbnail
              if (hasImage) ...[
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spacing12),
                  child: GestureDetector(
                    onTap: () => widget.onViewImage(item.imageUrl!),
                    behavior: HitTestBehavior.opaque,
                    child: ClipRRect(
                      borderRadius: AppTheme.borderRadiusSmall,
                      child: Image.network(
                        item.imageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.gray100,
                            borderRadius: AppTheme.borderRadiusSmall,
                          ),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 16,
                            color: AppTheme.gray400,
                          ),
                        ),
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
                              color: _isChecked
                                  ? AppTheme.gray400
                                  : AppTheme.gray900,
                              decoration: _isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppTheme.gray400,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_quantityLabel.isNotEmpty) ...[
                          const SizedBox(width: AppTheme.spacing8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing6,
                              vertical: AppTheme.spacing2,
                            ),
                            decoration: BoxDecoration(
                              color: _isChecked
                                  ? AppTheme.gray100
                                  : AppTheme.accentPlayfulLight,
                              borderRadius: AppTheme.borderRadiusFull,
                            ),
                            child: Text(
                              _quantityLabel,
                              style: context.textTheme.labelSmall?.copyWith(
                                color: _isChecked
                                    ? AppTheme.gray400
                                    : AppTheme.accentPlayful,
                                fontWeight: FontWeight.w500,
                                decoration: _isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppTheme.gray400,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (hasNotes) ...[
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        item.notes!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color:
                              _isChecked ? AppTheme.gray300 : AppTheme.gray500,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              if (hasImage) ...[
                IconButton(
                  onPressed: () => widget.onViewImage(item.imageUrl!),
                  icon: Icon(
                    Icons.photo_outlined,
                    size: 18,
                    color: AppTheme.accentPlayful,
                  ),
                  tooltip: 'View photo',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],

              // Edit button
              IconButton(
                onPressed: () => widget.onEdit(item),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppTheme.gray300,
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

// ── Empty Items State ───────────────────────────────────────────────────────

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing40,
        vertical: AppTheme.spacing24,
      ),
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
              Icons.checklist_rounded,
              size: 36,
              color: AppTheme.accentPlayful,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            'No items yet',
            style: AppTheme.displayTitleSmall(),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Use the bar below: type a name and tap + to add fast, or tap + on its own to add with photo, quantity, and notes. You can also use the ⋮ menu.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
              height: 1.5,
            ),
          ),
        ],
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
              'Couldn\'t load this list',
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
