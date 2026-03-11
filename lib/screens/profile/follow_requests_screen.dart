import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/user_avatar.dart';

/// Shows pending follow requests with accept / deny actions.
class FollowRequestsScreen extends ConsumerWidget {
  const FollowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Follow Requests')),
      body: requestsAsync.when(
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
                  'Failed to load requests',
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
                      ref.invalidate(pendingRequestsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_disabled_outlined,
                    size: 48,
                    color: context.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No pending requests',
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
              ref.invalidate(pendingRequestsProvider);
              await ref.read(pendingRequestsProvider.future);
            },
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final request = requests[index];
                final user = request.user;
                final actionState =
                    ref.watch(followRequestActionProvider);
                final isProcessing = actionState is AsyncLoading;

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
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  ref
                                      .read(followRequestActionProvider
                                          .notifier)
                                      .accept(request.id);
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingSm,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  ref
                                      .read(followRequestActionProvider
                                          .notifier)
                                      .deny(request.id);
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingSm,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Deny'),
                        ),
                      ),
                    ],
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
