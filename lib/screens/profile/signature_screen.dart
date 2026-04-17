import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';

/// Draw a transparent-background-style signature and upload to the API.
class SignatureScreen extends ConsumerStatefulWidget {
  const SignatureScreen({super.key});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  late final SignatureController _controller;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _error;

  bool get _busy => _isSaving || _isDeleting;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black87,
      exportBackgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _afterSuccessfulMutation(String snackbarMessage) async {
    try {
      // ignore: unused_result — refresh side effect; return value unused.
      await ref.refresh(currentUserProvider.future);
    } catch (_) {
      // Server updated; profile will sync on next successful /auth/me fetch.
    }
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isDeleting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(snackbarMessage)),
    );
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.endsWith('/signature')) {
      context.go(loc.replaceFirst(RegExp(r'/signature$'), '/edit'));
    } else {
      context.pop();
    }
  }

  Future<void> _save() async {
    if (_controller.isEmpty) {
      setState(() => _error = 'Draw your signature first.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final bytes = await _controller.toPngBytes();
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _error = 'Could not export signature.';
          _isSaving = false;
        });
        return;
      }
      final b64 = base64Encode(bytes);
      final dataUri = 'data:image/png;base64,$b64';
      final apiService = await ref.read(apiServiceProvider.future);
      final result =
          await apiService.post('/users/me/signature', data: {'image': dataUri});
      if (result.isFailure) {
        setState(() {
          _error = result.error ?? 'Upload failed.';
          _isSaving = false;
        });
        return;
      }

      if (!mounted) return;
      await _afterSuccessfulMutation('Signature saved.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmRemoveSavedSignature() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove signature?'),
        content: const Text(
          'This deletes your saved recipe watermark from your account. '
          'You can add a new one anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/users/me/signature');
      if (!mounted) return;
      if (result.isFailure) {
        setState(() {
          _error = result.error ?? 'Could not remove signature.';
          _isDeleting = false;
        });
        return;
      }
      _controller.clear();
      await _afterSuccessfulMutation('Signature removed.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final savedPreviewUrl = user?.signature?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe signature'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => _controller.clear(),
            child: const Text('Clear pad'),
          ),
          TextButton(
            onPressed: _busy ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.accentPlayful,
                      ),
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        children: [
          Text(
            'Draw a simple mark — it can appear as a light watermark on your recipe photos when you enable it on each recipe.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray600,
              height: 1.45,
            ),
          ),
          if (savedPreviewUrl != null && savedPreviewUrl.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Saved signature',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.borderRadiusMedium,
                boxShadow: AppTheme.shadowSubtle,
              ),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Image.network(
                savedPreviewUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.gray400,
                    size: 40,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.accentPlayful,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _confirmRemoveSavedSignature,
                icon: _isDeleting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colorScheme.error,
                        ),
                      )
                    : Icon(Icons.delete_outline_rounded,
                        color: context.colorScheme.error),
                label: Text(
                  'Remove from account',
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            const Divider(color: AppTheme.gray200, height: AppTheme.spacing24),
          ],
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Draw a new signature',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.borderRadiusMedium,
              boxShadow: AppTheme.shadowSubtle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.white,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            Text(
              _error!,
              style: context.textTheme.bodySmall?.copyWith(color: AppTheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
