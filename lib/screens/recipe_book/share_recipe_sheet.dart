import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/user_avatar.dart';

/// Bottom sheet for sharing a recipe with another user.
class ShareRecipeSheet extends ConsumerStatefulWidget {
  const ShareRecipeSheet({
    super.key,
    required this.recipeId,
  });

  final String recipeId;

  @override
  ConsumerState<ShareRecipeSheet> createState() => _ShareRecipeSheetState();
}

class _ShareRecipeSheetState extends ConsumerState<ShareRecipeSheet> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  String _query = '';
  bool _isSending = false;

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _share(String recipientId) async {
    if (mounted) setState(() => _isSending = true);

    await ref.read(recipeActionProvider.notifier).share(
          widget.recipeId,
          recipientId,
          _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
        );

    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe shared!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = _query.trim().length >= 2
        ? ref.watch(userSearchProvider(_query))
        : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius:
                        const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Text(
                  'Share Recipe',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    if (mounted) setState(() => _query = value);
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacingSm),

              // Message field
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Add a message (optional)',
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  minLines: 1,
                ),
              ),

              const SizedBox(height: AppTheme.spacingSm),

              // Results
              Expanded(
                child: _buildResults(usersAsync, scrollController),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(
    AsyncValue<dynamic>? usersAsync,
    ScrollController scrollController,
  ) {
    if (_query.trim().length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Text(
            'Search for users to share this recipe with',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (usersAsync == null) {
      return const SizedBox.shrink();
    }

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to search users',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      ),
      data: (users) {
        final userList = users as List<dynamic>;
        if (userList.isEmpty) {
          return Center(
            child: Text(
              'No users found',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: userList.length,
          itemBuilder: (context, index) {
            final user = userList[index];
            return ListTile(
              leading: UserAvatar(
                fullName: user.fullName,
                profilePictureUrl: user.profilePicture,
                size: 40,
              ),
              title: Text(user.fullName),
              trailing: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: () => _share(user.id),
                      icon: const Icon(Icons.send),
                      tooltip: 'Send',
                    ),
            );
          },
        );
      },
    );
  }
}
