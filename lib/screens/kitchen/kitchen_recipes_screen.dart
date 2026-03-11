import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/kitchen_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/recipe_card.dart';

/// Displays all shared recipes from kitchen members with optional filtering.
class KitchenRecipesScreen extends ConsumerStatefulWidget {
  const KitchenRecipesScreen({super.key});

  @override
  ConsumerState<KitchenRecipesScreen> createState() =>
      _KitchenRecipesScreenState();
}

class _KitchenRecipesScreenState extends ConsumerState<KitchenRecipesScreen> {
  String? _selectedMemberId;

  @override
  Widget build(BuildContext context) {
    final kitchenAsync = ref.watch(myKitchenProvider);
    final params = KitchenRecipesParams(memberId: _selectedMemberId);
    final recipesAsync = ref.watch(kitchenRecipesProvider(params));

    return Scaffold(
      appBar: AppBar(title: const Text('Kitchen Recipes')),
      body: Column(
        children: [
          // Member filter chips
          kitchenAsync.when(
            data: (detail) {
              if (detail == null) return const SizedBox.shrink();
              return _MemberFilterBar(
                members: detail.members,
                selectedMemberId: _selectedMemberId,
                onSelected: (id) {
                  setState(() {
                    _selectedMemberId =
                        _selectedMemberId == id ? null : id;
                  });
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Recipe list
          Expanded(
            child: recipesAsync.when(
              data: (recipes) {
                if (recipes.isEmpty) {
                  return _EmptyRecipesView(
                    hasFilter: _selectedMemberId != null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(kitchenRecipesProvider(params)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    itemCount: recipes.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spacingMd),
                    itemBuilder: (context, index) {
                      return RecipeCard(recipe: recipes[index]);
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
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
                        error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      OutlinedButton(
                        onPressed: () => ref
                            .invalidate(kitchenRecipesProvider(params)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberFilterBar extends StatelessWidget {
  const _MemberFilterBar({
    required this.members,
    required this.selectedMemberId,
    required this.onSelected,
  });

  final List<CheflessUser> members;
  final String? selectedMemberId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        itemCount: members.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppTheme.spacingSm),
        itemBuilder: (context, index) {
          final member = members[index];
          final isSelected = selectedMemberId == member.id;
          return FilterChip(
            label: Text(member.fullName),
            selected: isSelected,
            onSelected: (_) => onSelected(member.id),
          );
        },
      ),
    );
  }
}

class _EmptyRecipesView extends StatelessWidget {
  const _EmptyRecipesView({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: context.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              hasFilter ? 'No Recipes Found' : 'No Kitchen Recipes Yet',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              hasFilter
                  ? 'This member has no shared recipes.'
                  : 'Recipes shared by kitchen members will appear here.',
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
