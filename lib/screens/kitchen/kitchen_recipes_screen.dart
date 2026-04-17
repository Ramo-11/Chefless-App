import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/kitchen_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/recipe_compact_row.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/user_avatar.dart';

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
    final recipeCount = recipesAsync.valueOrNull?.length ?? 0;
    final memberCount = kitchenAsync.valueOrNull?.members.length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text(
          'Kitchen Recipes',
          style: AppTheme.displayTitleMedium(),
        ),
      ),
      body: Column(
        children: [
          _KitchenRecipesIntro(
            recipeCount: recipeCount,
            memberCount: memberCount,
            hasFilter: _selectedMemberId != null,
            onClearFilter: () => setState(() => _selectedMemberId = null),
          ),
          kitchenAsync.when(
            data: (detail) {
              if (detail == null) return const SizedBox.shrink();
              return _MemberFilterBar(
                members: detail.members,
                selectedMemberId: _selectedMemberId,
                onSelected: (id) {
                  setState(() {
                    _selectedMemberId = id;
                  });
                },
              );
            },
            loading: () => const _MemberFilterBarLoading(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: recipesAsync.when(
              data: (recipes) {
                if (recipes.isEmpty) {
                  return _EmptyRecipesView(hasFilter: _selectedMemberId != null);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(kitchenRecipesProvider(params));
                    ref.invalidate(myKitchenProvider);
                  },
                  color: AppTheme.accentPlayful,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing16,
                      AppTheme.spacing8,
                      AppTheme.spacing16,
                      AppTheme.spacing24,
                    ),
                    itemCount: recipes.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spacing2),
                    itemBuilder: (context, index) {
                      return RecipeCompactRow(
                        recipe: recipes[index],
                        useRootRoute: true,
                        showChevron: true,
                      );
                    },
                  ),
                );
              },
              loading: () => ListView(
                padding: const EdgeInsets.only(top: AppTheme.spacing8),
                children: const [
                  RecipeCompactRowShimmer(gradientValue: 0.2),
                  RecipeCompactRowShimmer(gradientValue: 0.45),
                  RecipeCompactRowShimmer(gradientValue: 0.7),
                  RecipeCompactRowShimmer(gradientValue: 0.9),
                ],
              ),
              error: (error, _) => _KitchenRecipesErrorView(
                message: error.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(kitchenRecipesProvider(params)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenRecipesIntro extends StatelessWidget {
  const _KitchenRecipesIntro({
    required this.recipeCount,
    required this.memberCount,
    required this.hasFilter,
    required this.onClearFilter,
  });

  final int recipeCount;
  final int memberCount;
  final bool hasFilter;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Container(
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
              AppTheme.accentPlayfulLight.withValues(alpha: 0.72),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared cooking',
              style: AppTheme.displayTitleSmall(),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              'Browse recipes shared across your kitchen and narrow them by member when you want a more personal view.',
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
                _IntroMeta(
                  icon: Icons.menu_book_rounded,
                  label: '$recipeCount recipe${recipeCount == 1 ? '' : 's'}',
                ),
                _IntroMeta(
                  icon: Icons.people_alt_outlined,
                  label: '$memberCount member${memberCount == 1 ? '' : 's'}',
                ),
                if (hasFilter)
                  TextButton.icon(
                    onPressed: onClearFilter,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Clear filter'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroMeta extends StatelessWidget {
  const _IntroMeta({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: AppTheme.accentPlayful.withValues(alpha: 0.75),
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
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          0,
          AppTheme.spacing16,
          AppTheme.spacing8,
        ),
        itemCount: members.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppTheme.spacing8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selectedMemberId == null;
            return _MemberPill(
              label: 'Everyone',
              isSelected: isSelected,
              onTap: () => onSelected(null),
            );
          }

          final member = members[index - 1];
          final isSelected = selectedMemberId == member.id;
          return _MemberPill(
            label: member.fullName,
            avatar: UserAvatar(
              fullName: member.fullName,
              profilePictureUrl: member.profilePicture,
              size: 24,
            ),
            isSelected: isSelected,
            onTap: () => onSelected(member.id),
          );
        },
      ),
    );
  }
}

class _MemberPill extends StatelessWidget {
  const _MemberPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.avatar,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppTheme.borderRadiusFull,
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.10),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.05),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentPlayfulLight
                : AppTheme.surfaceElevated,
            borderRadius: AppTheme.borderRadiusFull,
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentPlayful.withValues(alpha: 0.28)
                  : AppTheme.gray200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatar != null) ...[
                avatar!,
                const SizedBox(width: AppTheme.spacing8),
              ],
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? AppTheme.accentPlayful
                      : AppTheme.textPrimaryDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberFilterBarLoading extends StatelessWidget {
  const _MemberFilterBarLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          0,
          AppTheme.spacing16,
          AppTheme.spacing8,
        ),
        children: List.generate(
          4,
          (index) => Container(
            margin: const EdgeInsets.only(right: AppTheme.spacing8),
            width: index == 0 ? 92 : 116,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: AppTheme.borderRadiusFull,
              border: Border.all(color: AppTheme.gray200),
            ),
          ),
        ),
      ),
    );
  }
}

class _KitchenRecipesErrorView extends StatelessWidget {
  const _KitchenRecipesErrorView({
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
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Couldn’t load kitchen recipes',
              style: context.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimaryDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
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
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.accentPlayfulLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.soup_kitchen_rounded,
                size: 36,
                color: AppTheme.accentPlayful.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              hasFilter ? 'No recipes for this member' : 'No kitchen recipes yet',
              style: AppTheme.displayTitleSmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              hasFilter
                  ? 'Try another member or clear the filter to browse the full kitchen collection.'
                  : 'Recipes shared by kitchen members will appear here as your group cooks together.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
