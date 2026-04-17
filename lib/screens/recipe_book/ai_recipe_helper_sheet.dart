import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/extensions.dart';
import '../paywall/paywall_bottom_sheet.dart';

/// Premium AI helper: generate recipe, substitutions, or format notes.
///
/// All three tabs check premium status and daily quota before calling the API.
/// Generate and Format show a preview before applying to the recipe form.
/// Substitutions display actionable results with copy support.
class AiRecipeHelperSheet extends ConsumerStatefulWidget {
  const AiRecipeHelperSheet({super.key});

  /// Shows the AI helper sheet. Checks premium first — if not premium,
  /// shows the paywall instead of the sheet.
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || !user.isPremiumActive) {
      PaywallBottomSheet.show(context, reason: PaywallReason.premiumFeature);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiRecipeHelperSheet(),
    );
  }

  @override
  ConsumerState<AiRecipeHelperSheet> createState() =>
      _AiRecipeHelperSheetState();
}

class _AiRecipeHelperSheetState extends ConsumerState<AiRecipeHelperSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _generateCtrl = TextEditingController();
  final _subIngCtrl = TextEditingController();
  final _subNeedCtrl = TextEditingController();
  final _formatCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _busyMessage;

  // Usage tracking
  int _usedToday = 0;
  int _dailyLimit = 20;
  bool _usageLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_error != null && mounted) setState(() => _error = null);
    });
    _loadUsage();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _generateCtrl.dispose();
    _subIngCtrl.dispose();
    _subNeedCtrl.dispose();
    _formatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsage() async {
    try {
      final api = await ref.read(apiServiceProvider.future);
      final result = await api.get('/ai/usage');
      if (result.isSuccess && result.data != null && mounted) {
        setState(() {
          _usedToday = result.data!['used'] as int? ?? 0;
          _dailyLimit = result.data!['limit'] as int? ?? 20;
          _usageLoaded = true;
        });
      }
    } catch (_) {
      // Non-critical — we still show the sheet, just without the counter.
    }
  }

  void _updateUsageFromResponse(Map<String, dynamic> data) {
    final usage = data['usage'] as Map<String, dynamic>?;
    if (usage != null && mounted) {
      setState(() {
        _usedToday = usage['used'] as int? ?? _usedToday;
        _dailyLimit = usage['limit'] as int? ?? _dailyLimit;
        _usageLoaded = true;
      });
    }
  }

  // ── Generate recipe ─────────────────────────────────────────────────────

  Future<void> _runGenerate() async {
    final p = _generateCtrl.text.trim();
    if (p.isEmpty) {
      setState(() => _error = 'Describe what you have or want to cook.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _busyMessage = 'Creating your recipe…';
    });
    try {
      final api = await ref.read(apiServiceProvider.future);
      final result =
          await api.post('/ai/generate-recipe', data: {'prompt': p});
      if (!mounted) return;
      if (result.isFailure) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _error = result.error ?? 'Request failed.';
        });
        return;
      }
      _updateUsageFromResponse(result.data!);
      final recipe = result.data!['recipe'] as Map<String, dynamic>?;
      if (recipe == null) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _error = 'No recipe returned.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _busyMessage = null;
      });
      if (mounted) await _showRecipePreview(recipe);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _error = _friendlyError(e);
        });
      }
    }
  }

  // ── Suggest substitutions ───────────────────────────────────────────────

  Future<void> _runSubstitute() async {
    final ing = _subIngCtrl.text.trim();
    final need = _subNeedCtrl.text.trim();
    if (ing.isEmpty || need.isEmpty) {
      setState(() => _error = 'Add ingredients/context and a dietary goal.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _busyMessage = 'Finding substitutions…';
    });
    try {
      final api = await ref.read(apiServiceProvider.future);
      final result = await api.post(
        '/ai/suggest-substitutions',
        data: {'ingredients': ing, 'dietaryNeed': need},
      );
      if (!mounted) return;
      if (result.isFailure) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _error = result.error ?? 'Request failed.';
        });
        return;
      }
      _updateUsageFromResponse(result.data!);
      final subs = (result.data!['substitutions'] as List<dynamic>?) ?? [];
      setState(() {
        _busy = false;
        _busyMessage = null;
      });
      if (mounted) await _showSubstitutionsSheet(subs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _error = _friendlyError(e);
        });
      }
    }
  }

  // ── Format notes ────────────────────────────────────────────────────────

  Future<void> _runFormat() async {
    final n = _formatCtrl.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'Paste your rough notes.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _busyMessage = 'Structuring your notes…';
    });
    try {
      final api = await ref.read(apiServiceProvider.future);
      final result =
          await api.post('/ai/format-recipe', data: {'notes': n});
      if (!mounted) return;
      if (result.isFailure) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _error = result.error ?? 'Request failed.';
        });
        return;
      }
      _updateUsageFromResponse(result.data!);
      final recipe = result.data!['recipe'] as Map<String, dynamic>?;
      if (recipe == null) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _error = 'No recipe returned.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _busyMessage = null;
      });
      if (mounted) await _showRecipePreview(recipe);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
          _error = _friendlyError(e);
        });
      }
    }
  }

  // ── Recipe preview bottom sheet ─────────────────────────────────────────

  Future<void> _showRecipePreview(Map<String, dynamic> recipe) async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecipePreviewSheet(recipe: recipe),
    );
    if (applied == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      ref.read(importedRecipeDataProvider.notifier).state = recipe;
      Navigator.of(context).pop(); // Close the AI helper sheet
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Recipe applied — review and edit before saving.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Substitutions result sheet ──────────────────────────────────────────

  Future<void> _showSubstitutionsSheet(List<dynamic> subs) async {
    if (subs.isEmpty) {
      setState(() => _error = 'No substitutions found for that combination.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubstitutionsResultSheet(substitutions: subs),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('429') || msg.contains('Daily AI limit')) {
      return 'Daily AI limit reached ($_dailyLimit uses). Try again tomorrow.';
    }
    if (msg.contains('503') || msg.contains('not configured')) {
      return 'AI helper is temporarily unavailable. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.80,
          minChildSize: 0.50,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ── Drag handle ──
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppTheme.gray300,
                      borderRadius: AppTheme.borderRadiusFull,
                    ),
                  ),
                ),

                // ── Scrollable content ──
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header ──
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 22,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'AI Recipe Helper',
                                style: context.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_usageLoaded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _usedToday >= _dailyLimit
                                      ? AppTheme.errorLight
                                      : AppTheme.primaryLight,
                                  borderRadius: AppTheme.borderRadiusFull,
                                ),
                                child: Text(
                                  '$_usedToday / $_dailyLimit today',
                                  style: context.textTheme.labelSmall?.copyWith(
                                    color: _usedToday >= _dailyLimit
                                        ? AppTheme.error
                                        : AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Results are always editable — nothing is saved until you save the recipe.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppTheme.gray500,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Tabs ──
                        TabBar(
                          controller: _tabs,
                          labelStyle: context.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(text: 'From ingredients'),
                            Tab(text: 'Substitute'),
                            Tab(text: 'Format notes'),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Tab content ──
                        SizedBox(
                          height: 340,
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _buildGenerateTab(),
                              _buildSubstituteTab(),
                              _buildFormatTab(),
                            ],
                          ),
                        ),

                        // ── Loading indicator ──
                        if (_busy) ...[
                          const SizedBox(height: 16),
                          _LoadingIndicator(message: _busyMessage ?? 'Working…'),
                        ],

                        // ── Error display ──
                        if (_error != null && !_busy) ...[
                          const SizedBox(height: 12),
                          _ErrorBanner(message: _error!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Tab: Generate from ingredients ────────────────────────────────────

  Widget _buildGenerateTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Describe your ingredients, cravings, or dietary needs — AI creates a full recipe.',
          style: context.textTheme.bodySmall?.copyWith(color: AppTheme.gray500),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: _generateCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'e.g. chicken breast, lemon, garlic, rice — quick weeknight dinner',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _runGenerate,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Generate recipe'),
        ),
      ],
    );
  }

  // ── Tab: Substitute ingredients ───────────────────────────────────────

  Widget _buildSubstituteTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste your ingredients and specify a dietary goal — AI suggests swaps.',
          style: context.textTheme.bodySmall?.copyWith(color: AppTheme.gray500),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: _subIngCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'e.g. butter, heavy cream, eggs, all-purpose flour…',
              labelText: 'Ingredients / recipe text',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _subNeedCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g. dairy-free, vegan, lower calorie',
            labelText: 'Dietary goal',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _runSubstitute,
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Find substitutions'),
        ),
      ],
    );
  }

  // ── Tab: Format rough notes ───────────────────────────────────────────

  Widget _buildFormatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paste messy cooking notes — AI turns them into a structured recipe with '
          'ingredients, steps, and estimated times.',
          style: context.textTheme.bodySmall?.copyWith(color: AppTheme.gray500),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: _formatCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: 'Paste rough notes, voice-to-text, or a recipe you jotted down…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _runFormat,
          icon: const Icon(Icons.auto_fix_high, size: 18),
          label: const Text('Structure as recipe'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loading indicator with animated dots and descriptive message
// ═══════════════════════════════════════════════════════════════════════════════

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Error banner with icon
// ═══════════════════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: AppTheme.borderRadiusMedium,
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Recipe preview sheet — shown before applying generate/format results
// ═══════════════════════════════════════════════════════════════════════════════

class _RecipePreviewSheet extends StatelessWidget {
  const _RecipePreviewSheet({required this.recipe});
  final Map<String, dynamic> recipe;

  @override
  Widget build(BuildContext context) {
    final title = recipe['title'] as String? ?? 'Untitled';
    final description = recipe['description'] as String?;
    final prepTime = recipe['prepTime'];
    final cookTime = recipe['cookTime'];
    final servings = recipe['servings'];
    final ingredients =
        (recipe['ingredients'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            const [];
    final steps =
        (recipe['steps'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            const [];
    final dietaryTags =
        (recipe['dietaryTags'] as List<dynamic>?)?.cast<String>() ?? const [];
    final cuisineTags =
        (recipe['cuisineTags'] as List<dynamic>?)?.cast<String>() ?? const [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              // ── Drag handle ──
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppTheme.gray300,
                    borderRadius: AppTheme.borderRadiusFull,
                  ),
                ),
              ),

              // ── Fixed header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Preview',
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Use this recipe'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'This will fill your recipe form. You can edit everything before saving.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppTheme.gray500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // ── Scrollable recipe content ──
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.gray600,
                          ),
                        ),
                      ],

                      // Metadata chips
                      if (prepTime != null ||
                          cookTime != null ||
                          servings != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (prepTime != null)
                              _MetadataChip(
                                icon: Icons.timer_outlined,
                                label: 'Prep: ${prepTime}min',
                              ),
                            if (cookTime != null)
                              _MetadataChip(
                                icon: Icons.local_fire_department_outlined,
                                label: 'Cook: ${cookTime}min',
                              ),
                            if (servings != null)
                              _MetadataChip(
                                icon: Icons.people_outline,
                                label: '$servings servings',
                              ),
                          ],
                        ),
                      ],

                      // Tags
                      if (dietaryTags.isNotEmpty ||
                          cuisineTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...dietaryTags.map((t) => _TagChip(label: t)),
                            ...cuisineTags.map((t) => _TagChip(label: t)),
                          ],
                        ),
                      ],

                      // Ingredients
                      if (ingredients.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Ingredients',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...ingredients.map((ing) {
                          final name = ing['name'] ?? '';
                          final qty = ing['quantity'] ?? '';
                          final unit = ing['unit'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 7, right: 10),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.gray400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '$qty $unit $name'.trim(),
                                    style: context.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // Steps
                      if (steps.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Steps',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...steps.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final instruction =
                              entry.value['instruction'] as String? ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$idx',
                                    style:
                                        context.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    instruction,
                                    style: context.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Substitutions result sheet — actionable list with copy support
// ═══════════════════════════════════════════════════════════════════════════════

class _SubstitutionsResultSheet extends StatelessWidget {
  const _SubstitutionsResultSheet({required this.substitutions});
  final List<dynamic> substitutions;

  String _allAsText() {
    final buf = StringBuffer();
    for (final s in substitutions) {
      final m = s as Map<String, dynamic>;
      buf.writeln('${m['original']} → ${m['replacement']}');
      final note = m['note'] as String?;
      if (note != null && note.isNotEmpty) buf.writeln('  $note');
    }
    return buf.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Column(
            children: [
              // ── Drag handle ──
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppTheme.gray300,
                    borderRadius: AppTheme.borderRadiusFull,
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz,
                        size: 22, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Substitution Ideas',
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy all',
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _allAsText()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Substitutions copied to clipboard.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Use these ideas to update your recipe ingredients.',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: AppTheme.gray500),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // ── Substitution list ──
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: substitutions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (ctx, i) {
                    final m = substitutions[i] as Map<String, dynamic>;
                    final original = m['original'] as String? ?? '';
                    final replacement = m['replacement'] as String? ?? '';
                    final note = m['note'] as String?;
                    return _SubstitutionCard(
                      original: original,
                      replacement: replacement,
                      note: note,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SubstitutionCard extends StatelessWidget {
  const _SubstitutionCard({
    required this.original,
    required this.replacement,
    this.note,
  });

  final String original;
  final String replacement;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: AppTheme.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  original,
                  style: context.textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: AppTheme.gray500,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, size: 16, color: AppTheme.primaryColor),
              ),
              Expanded(
                child: Text(
                  replacement,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppTheme.gray500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Small reusable chips for the preview
// ═══════════════════════════════════════════════════════════════════════════════

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: AppTheme.gray100,
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.gray600),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: AppTheme.gray700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
