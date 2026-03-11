import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/search_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/user_avatar.dart';

/// Full-screen search overlay with debounced text search, type filtering
/// (All / Recipes / Users), and navigation to recipe detail or user profile.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Sync text field with provider (in case navigated back).
    _controller.text = ref.read(searchQueryProvider);
    // Auto-focus on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final selectedType = ref.watch(searchTypeProvider);
    final searchAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search recipes and users...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacingSm,
            ),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                    tooltip: 'Clear search',
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
      ),
      body: Column(
        children: [
          // Type filter tabs.
          _TypeFilterRow(
            selected: selectedType,
            onSelected: (type) {
              ref.read(searchTypeProvider.notifier).state = type;
            },
          ),
          const Divider(height: 1),

          // Results area.
          Expanded(
            child: query.trim().isEmpty
                ? _buildInitialState(context)
                : searchAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => _buildErrorState(context, error),
                    data: (results) => results.isEmpty
                        ? _buildEmptyState(context, query)
                        : _buildResults(context, results, selectedType),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Search for recipes or users',
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No results for "$query"',
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Try a different search term or filter.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
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
              'Something went wrong',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              error.toString(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            OutlinedButton(
              onPressed: () => ref.invalidate(searchResultsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    SearchResults results,
    String type,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      children: [
        // Recipes section.
        if (results.recipes.isNotEmpty && type != 'users') ...[
          if (type == 'all')
            _SectionHeader(
              title: 'Recipes',
              count: results.recipes.length,
            ),
          ...results.recipes.map(
            (recipe) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: RecipeCard(recipe: recipe),
            ),
          ),
        ],

        // Users section.
        if (results.users.isNotEmpty && type != 'recipes') ...[
          if (type == 'all')
            _SectionHeader(
              title: 'Users',
              count: results.users.length,
            ),
          ...results.users.map(
            (user) => _UserListTile(user: user),
          ),
        ],
      ],
    );
  }
}

class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const _types = [
    ('all', 'All'),
    ('recipes', 'Recipes'),
    ('users', 'Users'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      child: Row(
        children: _types.map((entry) {
          final (value, label) = entry;
          final isSelected = selected == value;
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacingSm),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onSelected(value),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppTheme.spacingSm,
        bottom: AppTheme.spacingSm,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            '($count)',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({required this.user});

  final SearchUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXs,
        vertical: AppTheme.spacingXs,
      ),
      leading: UserAvatar(
        fullName: user.fullName,
        profilePictureUrl: user.profilePicture,
        size: 44,
      ),
      title: Text(
        user.fullName,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        user.bio ?? '${user.recipesCount} recipes',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: user.isPublic
          ? null
          : Icon(
              Icons.lock_outline,
              size: 16,
              color: context.colorScheme.onSurfaceVariant,
            ),
      onTap: () => context.push('/user/${user.id}'),
    );
  }
}
