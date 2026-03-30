import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/extensions.dart';
import '../paywall/paywall_bottom_sheet.dart';

/// Bottom sheet that accepts a recipe URL, calls the import API endpoint,
/// and — on success — pre-fills the recipe creation form by setting
/// [importedRecipeDataProvider] and navigating to `/recipes/create`.
class ImportRecipeSheet extends ConsumerStatefulWidget {
  const ImportRecipeSheet({super.key});

  /// Convenience helper to show this sheet from any screen.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ImportRecipeSheet(),
    );
  }

  @override
  ConsumerState<ImportRecipeSheet> createState() => _ImportRecipeSheetState();
}

class _ImportRecipeSheetState extends ConsumerState<ImportRecipeSheet> {
  final _urlController = TextEditingController();
  bool _isImporting = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() => _error = 'Please enter a URL.');
      return;
    }

    // Basic client-side URL sanity check before calling the API.
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (!uri.scheme.startsWith('http'))) {
      setState(
        () => _error = 'Please enter a valid http:// or https:// URL.',
      );
      return;
    }

    // Check free tier recipe limit before bothering the API.
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final myRecipes = ref.read(myRecipesProvider).valueOrNull ?? [];
    if (currentUser != null && !currentUser.isPremium && myRecipes.length >= 10) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        PaywallBottomSheet.show(
          context,
          reason: PaywallReason.recipeLimitReached,
        );
      }
      return;
    }

    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/recipes/import',
        data: {'url': rawUrl},
      );

      if (!mounted) return;

      if (result.isFailure || result.data == null) {
        setState(() {
          _isImporting = false;
          _error = result.error ?? 'Failed to import recipe. '
              'Make sure the URL points to a recipe page that uses '
              'structured data (schema.org).';
        });
        return;
      }

      final recipeData = result.data!['recipe'] as Map<String, dynamic>?;
      if (recipeData == null) {
        setState(() {
          _isImporting = false;
          _error = 'No recipe data found on that page.';
        });
        return;
      }

      // Store the imported data and navigate to the create form.
      ref.read(importedRecipeDataProvider.notifier).state = recipeData;

      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/recipes/create');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _error = 'An unexpected error occurred. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingSm,
            AppTheme.spacingMd,
            AppTheme.spacingMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Title
              Text(
                'Import Recipe from URL',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                'Paste a link to any recipe page. We extract the title, '
                'ingredients, and steps — you can edit everything before saving.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // URL input
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                autofocus: true,
                enabled: !_isImporting,
                decoration: InputDecoration(
                  hintText: 'https://example.com/best-pasta-recipe',
                  prefixIcon: const Icon(Icons.link),
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _import(),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Import button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isImporting ? null : _import,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isImporting ? 'Importing…' : 'Import Recipe'),
                ),
              ),

              if (!_isImporting) ...[
                const SizedBox(height: AppTheme.spacingSm),
                Center(
                  child: Text(
                    'Works best with sites that use structured recipe data\n'
                    '(Allrecipes, Food Network, NYT Cooking, etc.)',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
