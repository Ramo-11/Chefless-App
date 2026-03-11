import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/user_avatar.dart';

/// Displays the current user's followers as a paginated list with pull-to-
/// refresh and infinite scroll.
class FollowersScreen extends ConsumerStatefulWidget {
  const FollowersScreen({super.key});

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen> {
  final List<CheflessUser> _followers = [];
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
      final newFollowers =
          await ref.read(followersProvider(_page + 1).future);
      if (!mounted) return;
      setState(() {
        _page++;
        _followers.addAll(newFollowers);
        _hasMore = newFollowers.length >= 20;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(followersProvider(1));
    final freshFollowers =
        await ref.read(followersProvider(1).future);
    if (!mounted) return;
    setState(() {
      _page = 1;
      _followers
        ..clear()
        ..addAll(freshFollowers);
      _hasMore = freshFollowers.length >= 20;
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialLoad = ref.watch(followersProvider(1));

    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
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
                  'Failed to load followers',
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
                      ref.invalidate(followersProvider(1)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (firstPage) {
          // Seed the list on first successful load.
          if (_followers.isEmpty && firstPage.isNotEmpty) {
            _followers.addAll(firstPage);
            _hasMore = firstPage.length >= 20;
          }

          if (_followers.isEmpty) {
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
                    'No followers yet',
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
              itemCount: _followers.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                if (index >= _followers.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppTheme.spacingMd),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final follower = _followers[index];
                return ListTile(
                  leading: UserAvatar(
                    fullName: follower.fullName,
                    profilePictureUrl: follower.profilePicture,
                    size: 44,
                  ),
                  title: Text(
                    follower.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () => context.push('/user/${follower.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
