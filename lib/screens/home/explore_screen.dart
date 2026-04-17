import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/feed_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/app_help_content.dart';
import '../../utils/calendar_week.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/home_feed_section_header.dart';
import '../../widgets/home_category_browse.dart';
import '../../widgets/home_glance_strip.dart';
import '../../widgets/home_seasonal_carousel.dart';
import '../../widgets/recipe_feed_card.dart';
import '../../widgets/recipe_featured_hero.dart';
import '../../widgets/shimmer_loading.dart';

/// Tab metadata for the explore sub-tabs.
class _FeedTab {
  const _FeedTab({
    required this.feedType,
    required this.label,
    required this.provider,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  final FeedType feedType;
  final String label;
  final AutoDisposeAsyncNotifierProvider<FeedNotifier, List<Recipe>> provider;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
}

final _tabs = [
  _FeedTab(
    feedType: FeedType.forYou,
    label: 'For You',
    provider: forYouFeedProvider,
    emptyTitle: 'Your feed is empty',
    emptySubtitle:
        'Follow people and set your preferences to get personalized recipes',
    emptyIcon: Icons.auto_awesome_outlined,
  ),
  _FeedTab(
    feedType: FeedType.trending,
    label: 'Trending',
    provider: trendingFeedProvider,
    emptyTitle: 'Nothing trending yet',
    emptySubtitle: 'No trending recipes yet',
    emptyIcon: Icons.trending_up,
  ),
  _FeedTab(
    feedType: FeedType.friends,
    label: 'Friends',
    provider: friendsFeedProvider,
    emptyTitle: 'No friend activity',
    emptySubtitle: 'Follow people to see their latest recipes',
    emptyIcon: Icons.people_outline,
  ),
  _FeedTab(
    feedType: FeedType.seasonal,
    label: 'Seasonal',
    provider: seasonalFeedProvider,
    emptyTitle: 'No seasonal picks',
    emptySubtitle: 'No seasonal picks right now',
    emptyIcon: Icons.eco_outlined,
  ),
];

/// The main Home / Explore screen with glance strip, feed sub-tabs, and feeds.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final _outerScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  /// Scroll the outer header back to the top (glance strip visible).
  void scrollToTop() {
    if (_outerScrollController.hasClients) {
      _outerScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
          tooltip: 'Search',
        ),
        title: Text(
          'Discover',
          style: AppTheme.displayTitleMedium(),
        ),
        actions: const [
          SharedRecipesIcon(),
          NotificationBellIcon(),
          ProfileShortcutIcon(),
          MainTabMoreButton(topic: AppHelpTopic.home),
        ],
      ),
      body: NestedScrollView(
        controller: _outerScrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          const SliverToBoxAdapter(child: HomeGlanceStrip()),
          SliverToBoxAdapter(child: _MiniGlobeBanner()),
          const SliverToBoxAdapter(child: HomeCategoryBrowse()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedTabBarDelegate(
              tabBar: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: 6,
                ),
                indicator: BoxDecoration(
                  color: AppTheme.accentPlayful,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPlayful.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.gray600,
                labelStyle:
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                unselectedLabelStyle:
                    Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray600,
                          letterSpacing: -0.1,
                        ),
                tabs: _tabs.map((tab) => Tab(text: tab.label)).toList(),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _tabs.map((tab) {
            return _FeedTabView(
              key: PageStorageKey<String>(tab.label),
              feedTab: tab,
              onScrollToTop: scrollToTop,
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// A single feed tab with infinite scroll, pull-to-refresh, and state handling.
class _FeedTabView extends ConsumerStatefulWidget {
  const _FeedTabView({
    super.key,
    required this.feedTab,
    required this.onScrollToTop,
  });

  final _FeedTab feedTab;
  final VoidCallback onScrollToTop;

  @override
  ConsumerState<_FeedTabView> createState() => _FeedTabViewState();
}

class _FeedTabViewState extends ConsumerState<_FeedTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels >= metrics.maxScrollExtent - 200) {
        final notifier = ref.read(widget.feedTab.provider.notifier);
        if (notifier.hasMore && !notifier.isLoadingMore) {
          notifier.loadMore();
        }
      }
    }
    return false;
  }

  Future<void> _onRefresh() async {
    widget.onScrollToTop();
    final monday = mondayOfWeekContaining(DateTime.now());
    ref.invalidate(myKitchenProvider);
    ref.invalidate(weekScheduleProvider(WeekScheduleParams(weekStart: monday)));
    await ref.read(widget.feedTab.provider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final feedState = ref.watch(widget.feedTab.provider);

    return feedState.when(
      loading: () => const ExploreFeedShimmerList(),
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
        final items = _buildVirtualFeedItems(recipes, widget.feedTab.feedType);

        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppTheme.accentPlayful,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(
                top: AppTheme.spacing16,
                bottom: AppTheme.spacing32,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                switch (item) {
                  case _VirtualHero(:final recipe):
                    return RecipeFeaturedHero(
                      recipe: recipe,
                      useRootRoute: true,
                    );
                  case _VirtualCarousel(:final recipesSlice):
                    return HomeSeasonalCarousel(
                      recipes: recipesSlice,
                      useRootRoute: true,
                    );
                  case _VirtualSection(:final title):
                    return HomeFeedSectionHeader(title: title);
                  case _VirtualRow(:final recipe, elevated: _):
                    return RecipeFeedCard(
                      recipe: recipe,
                      useRootRoute: true,
                    );
                  case _VirtualEnd():
                    if (notifier.hasMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTheme.spacing24,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                AppTheme.accentPlayful,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const _FeedEndMarker();
                }
              },
            ),
          ),
        );
      },
    );
  }
}

/// Subtle end-of-feed marker: thin center line with a terracotta dot.
class _FeedEndMarker extends StatelessWidget {
  const _FeedEndMarker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing40,
        vertical: AppTheme.spacing32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.gray200.withValues(alpha: 0.7),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.accentPlayful.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.gray200.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Delegate that pins the feed tab bar at the top when scrolled.
class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scrolled = shrinkOffset > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm,
        boxShadow: scrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: tabBar),
          ),
          Container(
            height: 1,
            color: scrolled
                ? AppTheme.gray200
                : AppTheme.gray200.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_PinnedTabBarDelegate oldDelegate) => false;
}

List<_VirtualFeedItem> _buildVirtualFeedItems(
  List<Recipe> recipes,
  FeedType feedType,
) {
  final out = <_VirtualFeedItem>[];
  if (recipes.isEmpty) return out;

  out.add(_VirtualHero(recipes.first));

  var startIdx = 1;
  if (feedType == FeedType.seasonal && recipes.length > 1) {
    final end = math.min(7, recipes.length);
    out.add(_VirtualCarousel(recipes.sublist(1, end)));
    startIdx = end;
  }

  final vertical = recipes.sublist(startIdx);
  for (var i = 0; i < vertical.length; i++) {
    if (i == 0 || i % 6 == 0) {
      out.add(_VirtualSection(_sectionTitleFor(feedType, i ~/ 6)));
    }
    out.add(_VirtualRow(vertical[i], elevated: i % 3 == 1));
  }

  out.add(_VirtualEnd());
  return out;
}

String _sectionTitleFor(FeedType type, int sectionIndex) {
  switch (type) {
    case FeedType.forYou:
      return sectionIndex == 0 ? 'More picks for you' : 'Keep exploring';
    case FeedType.trending:
      return sectionIndex == 0 ? 'Trending now' : 'Still heating up';
    case FeedType.friends:
      return sectionIndex == 0
          ? 'From your network'
          : 'More from people you follow';
    case FeedType.seasonal:
      return sectionIndex == 0
          ? 'More seasonal ideas'
          : 'Deeper into the season';
  }
}

sealed class _VirtualFeedItem {}

class _VirtualHero extends _VirtualFeedItem {
  _VirtualHero(this.recipe);
  final Recipe recipe;
}

class _VirtualCarousel extends _VirtualFeedItem {
  _VirtualCarousel(this.recipesSlice);
  final List<Recipe> recipesSlice;
}

class _VirtualSection extends _VirtualFeedItem {
  _VirtualSection(this.title);
  final String title;
}

class _VirtualRow extends _VirtualFeedItem {
  _VirtualRow(this.recipe, {required this.elevated});
  final Recipe recipe;
  final bool elevated;
}

class _VirtualEnd extends _VirtualFeedItem {
  _VirtualEnd();
}

/// Error view with retry button.
class _FeedErrorView extends StatelessWidget {
  const _FeedErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  ({IconData icon, String title, String body}) _classify() {
    final lower = message.toLowerCase();
    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('failed host lookup')) {
      return (
        icon: Icons.wifi_off_rounded,
        title: 'No connection',
        body: 'Check your network and try again.',
      );
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return (
        icon: Icons.hourglass_empty_rounded,
        title: 'Taking too long',
        body: 'The request timed out. Give it another go.',
      );
    }
    if (lower.contains('401') ||
        lower.contains('unauth') ||
        lower.contains('forbidden')) {
      return (
        icon: Icons.lock_outline_rounded,
        title: 'Session expired',
        body: 'Please sign in again to continue.',
      );
    }
    return (
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      body: 'We couldn\'t load your feed. Please retry.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _classify();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                info.icon,
                size: 30,
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            Text(
              info.title,
              style: AppTheme.displayTitleSmall().copyWith(
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              info.body,
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
              label: const Text('Try again'),
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
      color: AppTheme.accentPlayful,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                        color: AppTheme.gray100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 30,
                        color: AppTheme.gray500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    Text(
                      title,
                      style: AppTheme.displayTitleSmall().copyWith(
                        fontSize: 18,
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

/// Small animated globe banner that links to the full globe screen.
class _MiniGlobeBanner extends StatefulWidget {
  @override
  State<_MiniGlobeBanner> createState() => _MiniGlobeBannerState();
}

class _MiniGlobeBannerState extends State<_MiniGlobeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing4,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.shadowCard,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/globe');
            },
            borderRadius: BorderRadius.circular(18),
            splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
            highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentPlayfulLight,
                    Color(0xFFFFF4E0),
                  ],
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) {
                        return SizedBox(
                          width: 52,
                          height: 52,
                          child: CustomPaint(
                            painter: _MiniGlobePainter(
                              rotation: _anim.value * 2 * math.pi,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Taste the world',
                            style: AppTheme.displayTitleSmall().copyWith(
                              fontSize: 17,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Spin the globe, discover a new cuisine',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppTheme.gray600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.accentPlayful,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGlobePainter extends CustomPainter {
  _MiniGlobePainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Ocean — warm blue-teal
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF6B9FBF),
    );

    // Land blobs — warm earthy green
    const landColor = Color(0xFF8DB580);
    for (var i = 0; i < 5; i++) {
      final angle = rotation + (i * math.pi * 2 / 5);
      final x = center.dx + math.cos(angle) * radius * 0.45;
      final y = center.dy + math.sin(angle * 0.7) * radius * 0.55;
      final blobR = radius * (0.18 + (i % 3) * 0.08);
      final depth = math.cos(angle);
      if (depth > -0.3) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: blobR * 1.8,
            height: blobR * 1.2,
          ),
          Paint()..color = landColor.withValues(alpha: (depth + 0.3).clamp(0.0, 1.0) * 0.85),
        );
      }
    }

    // Shine
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Border — soft terracotta tint
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFC4946A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_MiniGlobePainter old) => old.rotation != rotation;
}
