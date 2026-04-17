import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/user_avatar.dart';

/// Shows pending follow requests with accept / deny actions.
///
/// Uses optimistic updates — requests disappear instantly on accept/deny
/// without waiting for the API round-trip.
class FollowRequestsScreen extends ConsumerStatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  ConsumerState<FollowRequestsScreen> createState() =>
      _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends ConsumerState<FollowRequestsScreen> {
  final Set<String> _processedIds = {};

  void _accept(String requestId) {
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _processedIds.add(requestId));
    ref.read(followRequestActionProvider.notifier).accept(requestId);
  }

  void _deny(String requestId) {
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _processedIds.add(requestId));
    ref.read(followRequestActionProvider.notifier).deny(requestId);
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Follow Requests')),
      body: requestsAsync.when(
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
                  'Failed to load requests',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentPlayful,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _processedIds.clear();
                    ref.invalidate(pendingRequestsProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (requests) {
          final visible = requests
              .where((r) => !_processedIds.contains(r.id))
              .toList();

          if (visible.isEmpty) {
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
                      Icons.person_add_disabled_outlined,
                      size: 36,
                      color: AppTheme.gray400,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No pending requests',
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
              _processedIds.clear();
              ref.invalidate(pendingRequestsProvider);
              await ref.read(pendingRequestsProvider.future);
            },
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
              itemCount: visible.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: AppTheme.spacing16 + 44 + AppTheme.spacing16,
                color: AppTheme.gray100,
              ),
              itemBuilder: (context, index) {
                final request = visible[index];
                final user = request.user;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacing12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/user/${user.id}'),
                        child: UserAvatar(
                          fullName: user.fullName,
                          profilePictureUrl: user.profilePicture,
                          size: 44,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/user/${user.id}'),
                          child: Text(
                            user.fullName,
                            style: context.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.gray900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      SizedBox(
                        height: 34,
                        child: FilledButton(
                          onPressed: () => _accept(request.id),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accentPlayful,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMd,
                            ),
                            textStyle: context.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      SizedBox(
                        height: 34,
                        child: OutlinedButton(
                          onPressed: () => _deny(request.id),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMd,
                            ),
                            side: BorderSide(color: AppTheme.gray200),
                            textStyle: context.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Deny'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
