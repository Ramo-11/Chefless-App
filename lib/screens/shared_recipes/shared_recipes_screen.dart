import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/shared_recipe.dart';
import '../../providers/shared_recipe_provider.dart';
import '../../utils/cloudinary_url.dart';
import '../../utils/extensions.dart';
import '../../utils/time_utils.dart';
import '../../widgets/user_avatar.dart';

/// Dedicated inbox for recipes shared with the current user.
class SharedRecipesScreen extends ConsumerStatefulWidget {
  const SharedRecipesScreen({super.key});

  @override
  ConsumerState<SharedRecipesScreen> createState() =>
      _SharedRecipesScreenState();
}

class _SharedRecipesScreenState extends ConsumerState<SharedRecipesScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    final notifier = ref.read(sharedRecipesProvider.notifier);
    if (!notifier.hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    await ref.read(sharedRecipesProvider.notifier).loadMore();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _refresh() async {
    ref.invalidate(sharedRecipesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(sharedRecipesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text(
          'Shared With You',
          style: AppTheme.displayTitleMedium(),
        ),
      ),
      body: listAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => _ErrorBody(
          message: error.toString(),
          onRetry: _refresh,
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppTheme.accentPlayful,
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                top: AppTheme.spacing8,
                bottom: AppTheme.spacing32,
              ),
              itemCount: items.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                child: Container(height: 1, color: AppTheme.gray100),
              ),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _SharedRecipeTile(item: items[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _SharedRecipeTile extends StatelessWidget {
  const _SharedRecipeTile({required this.item});

  final SharedRecipe item;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = item.recipePhoto != null;
    final thumbUrl = hasPhoto
        ? cloudinaryUrl(item.recipePhoto!, width: 136, height: 136)
        : null;

    return InkWell(
      onTap: () => context.push('/recipe/${item.recipeId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe thumbnail
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: AppTheme.borderRadiusMedium,
                border: Border.all(
                  color: AppTheme.gray200.withValues(alpha: 0.6),
                ),
                boxShadow: AppTheme.shadowSubtle,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto && thumbUrl != null
                  ? CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppTheme.gray100),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.gray100,
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: AppTheme.gray300,
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      color: AppTheme.gray100,
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: AppTheme.gray300,
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe title
                  Text(
                    item.recipeTitle,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryDeep,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  // Sender info
                  Row(
                    children: [
                      UserAvatar(
                        fullName: item.senderName ?? '?',
                        profilePictureUrl: item.senderPhoto,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacing6),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: item.senderName ?? 'Someone',
                                style: context.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.gray700,
                                ),
                              ),
                              TextSpan(
                                text: ' shared this with you',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.gray500,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Optional message
                  if (item.message?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: AppTheme.spacing6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: AppTheme.borderRadiusSmall,
                        border: Border.all(color: AppTheme.gray200),
                      ),
                      child: Text(
                        '"${item.message!.trim()}"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.gray600,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacing4),
                  // Timestamp
                  Text(
                    timeAgo(item.sharedAt),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: AppTheme.gray400,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacing4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.gray300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 32,
                color: AppTheme.gray300,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              'No shared recipes yet',
              style: context.textTheme.titleMedium?.copyWith(
                color: AppTheme.gray900,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              'When someone shares a recipe with you\nthrough Chefless, it will appear here.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.all(AppTheme.spacing48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Something went wrong',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing16),
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
