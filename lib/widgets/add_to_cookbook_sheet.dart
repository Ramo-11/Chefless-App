import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/cookbook.dart';
import '../providers/cookbook_provider.dart';
import '../utils/extensions.dart';

/// Bottom sheet that lets the user add a recipe to one of their cookbooks
/// (or create a new cookbook on the fly). Multi-select toggle: tapping a
/// row adds or removes the recipe from that cookbook in real time.
class AddToCookbookSheet extends ConsumerStatefulWidget {
  const AddToCookbookSheet({
    super.key,
    required this.recipeId,
    required this.recipeTitle,
  });

  final String recipeId;
  final String recipeTitle;

  static Future<void> show(
    BuildContext context, {
    required String recipeId,
    required String recipeTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => AddToCookbookSheet(
        recipeId: recipeId,
        recipeTitle: recipeTitle,
      ),
    );
  }

  @override
  ConsumerState<AddToCookbookSheet> createState() => _AddToCookbookSheetState();
}

class _AddToCookbookSheetState extends ConsumerState<AddToCookbookSheet> {
  final Set<String> _busy = {};

  Future<void> _toggle({
    required Cookbook cookbook,
    required bool isMember,
  }) async {
    if (_busy.contains(cookbook.id)) return;
    setState(() => _busy.add(cookbook.id));

    final notifier = ref.read(cookbookActionProvider.notifier);
    final ok = isMember
        ? await notifier.removeRecipe(
            cookbookId: cookbook.id,
            recipeId: widget.recipeId,
          )
        : await notifier.addRecipes(
            cookbookId: cookbook.id,
            recipeIds: [widget.recipeId],
          );

    if (!mounted) return;
    setState(() => _busy.remove(cookbook.id));

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isMember
                ? 'Removed from "${cookbook.name}".'
                : 'Added to "${cookbook.name}".',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(
            isMember
                ? 'Failed to remove from cookbook.'
                : 'Failed to add to cookbook.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cookbooksAsync = ref.watch(myCookbooksProvider);
    final containingAsync =
        ref.watch(cookbooksContainingRecipeProvider(widget.recipeId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing20,
        AppTheme.spacing4,
        AppTheme.spacing20,
        AppTheme.spacing20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add to cookbook', style: AppTheme.displayTitleSmall()),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            'Organize "${widget.recipeTitle}" into one of your folders.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await context.push('/cookbook/new');
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create new cookbook'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentPlayful,
              side: BorderSide(
                color: AppTheme.accentPlayful.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacing12,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: cookbooksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppTheme.spacing24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Text(
                  err.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.error,
                  ),
                ),
              ),
              data: (cookbooks) {
                if (cookbooks.isEmpty) {
                  return _EmptyHint(context: context);
                }
                final containing = containingAsync.valueOrNull ?? <String>{};
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: cookbooks.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cookbook = cookbooks[index];
                    final isMember = containing.contains(cookbook.id);
                    final busy = _busy.contains(cookbook.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accentPlayfulLight,
                          borderRadius: AppTheme.borderRadiusMedium,
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: AppTheme.accentPlayful,
                        ),
                      ),
                      title: Text(
                        cookbook.name,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryDeep,
                        ),
                      ),
                      subtitle: Text(
                        '${cookbook.recipesCount} recipe${cookbook.recipesCount == 1 ? '' : 's'}'
                        '${cookbook.isPrivate ? ' · Private' : ''}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.gray500,
                        ),
                      ),
                      trailing: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              isMember
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: isMember
                                  ? AppTheme.success
                                  : AppTheme.gray400,
                            ),
                      onTap: busy
                          ? null
                          : () => _toggle(
                                cookbook: cookbook,
                                isMember: isMember,
                              ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.spacing16,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.accentPlayfulLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: AppTheme.accentPlayful,
              size: 28,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            'No cookbooks yet',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryDeep,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            'Create your first cookbook to start grouping recipes.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }
}
