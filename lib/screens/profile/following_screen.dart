import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/user_avatar.dart';

/// Displays the list of users the current user is following.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider(1));

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: followingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                const SizedBox(height: AppTheme.spacingMd),
                ElevatedButton(
                  onPressed: () => ref.invalidate(followingProvider(1)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (following) {
          if (following.isEmpty) {
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
            onRefresh: () async {
              ref.invalidate(followingProvider(1));
              await ref.read(followingProvider(1).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingSm,
              ),
              itemCount: following.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final user = following[index];
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
                    onPressed: () => _confirmUnfollow(context, ref, user),
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

  void _confirmUnfollow(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
  ) {
    showDialog<void>(
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
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(followActionProvider.notifier)
                  .unfollow(user.id as String);
            },
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }
}
