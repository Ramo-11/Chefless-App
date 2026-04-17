import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/cookbook.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cookbook_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/image_picker_helper.dart';

/// Create or edit a cookbook (folder) in one screen.
class CookbookFormScreen extends ConsumerStatefulWidget {
  const CookbookFormScreen({super.key, this.cookbookId});

  final String? cookbookId;

  bool get isEditing => cookbookId != null;

  @override
  ConsumerState<CookbookFormScreen> createState() => _CookbookFormScreenState();
}

class _CookbookFormScreenState extends ConsumerState<CookbookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _coverPhoto;
  bool _isPrivate = false;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _populate(Cookbook cookbook) {
    if (_isInitialized) return;
    _isInitialized = true;
    _nameController.text = cookbook.name;
    _descriptionController.text = cookbook.description ?? '';
    _coverPhoto = cookbook.coverPhoto;
    _isPrivate = cookbook.isPrivate;
  }

  Future<void> _pickCoverPhoto() async {
    final cropped = await pickAndCropImage(
      aspect: CropAspect.cover,
      maxSize: 1600,
      quality: 88,
    );
    if (cropped == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await cropped.readAsBytes();
      if (bytes.length > 25 * 1024 * 1024) {
        if (mounted) _showMessage('Photo is too large. Max 25 MB.');
        return;
      }

      final ext = cropped.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/recipes/upload-photo',
        data: {'image': dataUri, 'folder': 'cookbooks'},
      );

      if (!mounted) return;
      if (result.isSuccess && result.data != null) {
        setState(() => _coverPhoto = result.data!['secureUrl'] as String);
      } else {
        _showMessage(result.error ?? 'Failed to upload photo.');
      }
    } catch (e) {
      if (mounted) _showMessage('Failed to upload photo.');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final notifier = ref.read(cookbookActionProvider.notifier);
    Cookbook? cookbook;

    if (widget.isEditing) {
      cookbook = await notifier.update(
        cookbookId: widget.cookbookId!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        clearDescription: _descriptionController.text.trim().isEmpty,
        coverPhoto: _coverPhoto,
        clearCoverPhoto: _coverPhoto == null,
        isPrivate: _isPrivate,
      );
    } else {
      cookbook = await notifier.create(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        coverPhoto: _coverPhoto,
        isPrivate: _isPrivate,
      );
    }

    if (!mounted) return;
    if (cookbook != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing
              ? 'Cookbook updated.'
              : 'Cookbook created.'),
        ),
      );
      if (widget.isEditing) {
        context.pop(cookbook);
      } else {
        context.pushReplacement('/cookbook/${cookbook.id}');
      }
    } else {
      setState(() => _isSaving = false);
      final state = ref.read(cookbookActionProvider);
      _showMessage(
        state.error?.toString().replaceFirst('Exception: ', '') ??
            'Failed to save cookbook.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final asyncCookbook =
          ref.watch(cookbookDetailProvider(widget.cookbookId!));
      return asyncCookbook.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          appBar: AppBar(title: const Text('Edit Cookbook')),
          body: Center(child: Text(err.toString())),
        ),
        data: (cookbook) {
          _populate(cookbook);
          return _buildScaffold(context);
        },
      );
    }
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Cookbook' : 'New Cookbook'),
        backgroundColor: AppTheme.surfaceWarm,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          children: [
            _CoverPhotoPicker(
              coverPhoto: _coverPhoto,
              isUploading: _isUploadingPhoto,
              onPick: _pickCoverPhoto,
              onClear: _coverPhoto == null
                  ? null
                  : () {
                      if (mounted) setState(() => _coverPhoto = null);
                    },
            ),
            const SizedBox(height: AppTheme.spacing20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Cookbook name',
                hintText: 'e.g. Weeknight Dinners',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What ties these recipes together?',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 2,
              maxLength: 500,
            ),
            const SizedBox(height: AppTheme.spacing12),
            SwitchListTile(
              title: const Text('Private cookbook'),
              subtitle: const Text(
                'Only visible to you. Public cookbooks appear on your profile.',
              ),
              value: _isPrivate,
              onChanged: (value) {
                if (mounted) setState(() => _isPrivate = value);
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPhotoPicker extends StatelessWidget {
  const _CoverPhotoPicker({
    required this.coverPhoto,
    required this.isUploading,
    required this.onPick,
    this.onClear,
  });

  final String? coverPhoto;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: AppTheme.borderRadiusXL,
        color: AppTheme.gray100,
        image: coverPhoto != null
            ? DecorationImage(
                image: NetworkImage(coverPhoto!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          if (coverPhoto == null)
            Center(
              child: InkWell(
                onTap: isUploading ? null : onPick,
                borderRadius: AppTheme.borderRadiusFull,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUploading
                            ? Icons.hourglass_top_rounded
                            : Icons.add_photo_alternate_outlined,
                        size: 36,
                        color: AppTheme.gray500,
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        isUploading ? 'Uploading…' : 'Add cover photo',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.gray600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (coverPhoto != null)
            Positioned(
              top: AppTheme.spacing12,
              right: AppTheme.spacing12,
              child: Row(
                children: [
                  if (onClear != null)
                    _CircleIconButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: onClear!,
                      tooltip: 'Remove cover',
                    ),
                  const SizedBox(width: AppTheme.spacing8),
                  _CircleIconButton(
                    icon: Icons.edit_outlined,
                    onTap: isUploading ? () {} : onPick,
                    tooltip: 'Change cover',
                  ),
                ],
              ),
            ),
          if (isUploading && coverPhoto != null)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
