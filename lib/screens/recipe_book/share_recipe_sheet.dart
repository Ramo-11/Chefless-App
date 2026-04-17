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
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          // Single scrollable avoids Column + Expanded overflow when the keyboard
          // reduces available height (e.g. search field focused on Home).
          return CustomScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppTheme.spacing12),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing20,
                        vertical: AppTheme.spacing16,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Share Recipe',
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppTheme.gray900,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing20,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          if (mounted) setState(() => _query = value);
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing20,
                      ),
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
                    const SizedBox(height: AppTheme.spacing12),
                  ],
                ),
              ),
              ..._resultSlivers(context, usersAsync),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _resultSlivers(
    BuildContext context,
    AsyncValue<dynamic>? usersAsync,
  ) {
    if (_query.trim().length < 2) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppTheme.gray50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      size: 28,
                      color: AppTheme.gray300,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Text(
                    'Search for users to share this recipe with',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.gray500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (usersAsync == null) {
      return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    }

    return usersAsync.when(
      loading: () => [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppTheme.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 24,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  'Failed to search users',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      data: (users) {
        final userList = users as List<dynamic>;
        if (userList.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppTheme.gray100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_off_rounded,
                        size: 28,
                        color: AppTheme.gray300,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    Text(
                      'No users found',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gray500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        }

        return [
          SliverList.separated(
            itemCount: userList.length,
            itemBuilder: (context, index) {
              final user = userList[index];
              return InkWell(
                onTap: _isSending ? null : () => _share(user.id as String),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing20,
                    vertical: AppTheme.spacing8,
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        fullName: user.fullName as String,
                        profilePictureUrl: user.profilePicture as String?,
                        size: 44,
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Text(
                          user.fullName as String,
                          style: context.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.gray900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isSending)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (context, _) => const Divider(
              height: 1,
              indent: AppTheme.spacing20 + 44 + AppTheme.spacing12,
              color: AppTheme.gray100,
            ),
          ),
        ];
      },
    );
  }
}
