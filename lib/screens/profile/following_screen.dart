import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/shimmer_loading.dart';
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
        loading: () => const UserListShimmer(),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 32,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Failed to load following',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentPlayful,
                    foregroundColor: Colors.white,
                  ),
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
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing20),
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.people_outline,
                      size: 36,
                      color: AppTheme.gray400,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'Not following anyone yet',
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.gray500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.accentPlayful,
            onRefresh: () async {
              ref.invalidate(followingProvider(1));
              await ref.read(followingProvider(1).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingSm,
              ),
              itemCount: following.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: AppTheme.spacing16 + 44 + AppTheme.spacing16,
                color: AppTheme.gray100,
              ),
              itemBuilder: (context, index) {
                final user = following[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacing4,
                  ),
                  leading: UserAvatar(
                    fullName: user.fullName,
                    profilePictureUrl: user.profilePicture,
                    size: 44,
                  ),
                  title: Text(
                    user.fullName,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray900,
                    ),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _confirmUnfollow(context, ref, user);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                      ),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: AppTheme.gray200),
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
