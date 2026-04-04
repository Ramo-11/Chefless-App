import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/feed_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/shimmer_loading.dart';

/// Tab metadata for the explore sub-tabs.
class _FeedTab {
  const _FeedTab({
    required this.label,
    required this.provider,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  final String label;
  final AutoDisposeAsyncNotifierProvider<FeedNotifier, List<Recipe>> provider;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
}

final _tabs = [
  _FeedTab(
    label: 'For You',
    provider: forYouFeedProvider,
    emptyTitle: 'Your feed is empty',
    emptySubtitle:
        'Follow people and set your preferences to get personalized recipes',
    emptyIcon: Icons.auto_awesome_outlined,
  ),
  _FeedTab(
    label: 'Trending',
    provider: trendingFeedProvider,
    emptyTitle: 'Nothing trending yet',
    emptySubtitle: 'No trending recipes yet',
    emptyIcon: Icons.trending_up,
  ),
  _FeedTab(
    label: 'Friends',
    provider: friendsFeedProvider,
    emptyTitle: 'No friend activity',
    emptySubtitle: 'Follow people to see their latest recipes',
    emptyIcon: Icons.people_outline,
  ),
  _FeedTab(
    label: 'Seasonal',
    provider: seasonalFeedProvider,
    emptyTitle: 'No seasonal picks',
    emptySubtitle: 'No seasonal picks right now',
    emptyIcon: Icons.eco_outlined,
  ),
];

/// The main Explore screen with horizontal sub-tabs for different feeds.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
          tooltip: 'Search',
        ),
        title: const Text('Explore'),
        actions: const [NotificationBellIcon()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
              tabs: _tabs.map((tab) => Tab(text: tab.label)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          return _FeedTabView(
            key: PageStorageKey<String>(tab.label),
            feedTab: tab,
          );
        }).toList(),
      ),
    );
  }
}

/// A single feed tab with infinite scroll, pull-to-refresh, and state handling.
class _FeedTabView extends ConsumerStatefulWidget {
  const _FeedTabView({
    super.key,
    required this.feedTab,
  });

  final _FeedTab feedTab;

  @override
  ConsumerState<_FeedTabView> createState() => _FeedTabViewState();
}

class _FeedTabViewState extends ConsumerState<_FeedTabView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

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
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // Trigger load more when within 200px of the bottom.
    if (currentScroll >= maxScroll - 200) {
      final notifier = ref.read(widget.feedTab.provider.notifier);
      if (notifier.hasMore && !notifier.isLoadingMore) {
        notifier.loadMore();
      }
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(widget.feedTab.provider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final feedState = ref.watch(widget.feedTab.provider);

    return feedState.when(
      loading: () => const RecipeCardShimmerList(),
      error: (error, _) => _FeedErrorView(
        message: error.toString(),
        onRetry: _onRefresh,
      ),
      data: (recipes) {
        if (recipes.isEmpty) {
          return _FeedEmptyView(
            title: widget.feedTab.emptyTitle,
            subtitle: widget.feedTab.emptySubtitle,
            icon: widget.feedTab.emptyIcon,
            onRefresh: _onRefresh,
          );
        }

        final notifier = ref.read(widget.feedTab.provider.notifier);

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppTheme.primaryColor,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            itemCount: recipes.length + (notifier.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == recipes.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding:
                    const EdgeInsets.only(bottom: AppTheme.spacing12),
                child: RecipeCard(
                  recipe: recipes[index],
                  useRootRoute: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Shimmer loading is now handled by the shared RecipeCardShimmerList widget.

/// Error view with retry button.
class _FeedErrorView extends StatelessWidget {
  const _FeedErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              'Something went wrong',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spacing24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state view for a feed tab.
class _FeedEmptyView extends StatelessWidget {
  const _FeedEmptyView({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 32,
                        color: AppTheme.gray400,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    Text(
                      title,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray900,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      subtitle,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gray500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
