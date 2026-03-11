import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/user_avatar.dart';

/// Displays the list of users the current user is following, with pagination
/// and pull-to-refresh.
class FollowingScreen extends ConsumerStatefulWidget {
  const FollowingScreen({super.key});

  @override
  ConsumerState<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends ConsumerState<FollowingScreen> {
  final List<CheflessUser> _following = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!mounted) return;
    setState(() => _isLoadingMore = true);
    try {
      final newFollowing =
          await ref.read(followingProvider(_page + 1).future);
      if (!mounted) return;
      setState(() {
        _page++;
        _following.addAll(newFollowing);
        _hasMore = newFollowing.length >= 20;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(followingProvider(1));
    final freshFollowing =
        await ref.read(followingProvider(1).future);
    if (!mounted) return;
    setState(() {
      _page = 1;
      _following
        ..clear()
        ..addAll(freshFollowing);
      _hasMore = freshFollowing.length >= 20;
    });
  }

  void _confirmUnfollow(CheflessUser user) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfollow'),
        content: Text('Unfollow ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(followActionProvider.notifier)
                  .unfollow(user.id);
              // Optimistically remove from local list.
              if (mounted) {
                setState(() {
                  _following.removeWhere((u) => u.id == user.id);
                });
              }
            },
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialLoad = ref.watch(followingProvider(1));

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: initialLoad.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
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
                  'Failed to load following',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(followingProvider(1)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (firstPage) {
          if (_following.isEmpty && firstPage.isNotEmpty) {
            _following.addAll(firstPage);
            _hasMore = firstPage.length >= 20;
          }

          if (_following.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: context.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'Not following anyone yet',
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingSm,
              ),
              itemCount: _following.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                if (index >= _following.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppTheme.spacingMd),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final user = _following[index];
                return ListTile(
                  leading: UserAvatar(
                    fullName: user.fullName,
                    profilePictureUrl: user.profilePicture,
                    size: 44,
                  ),
                  title: Text(
                    user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _confirmUnfollow(user),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Unfollow'),
                  ),
                  onTap: () => context.push('/user/${user.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
