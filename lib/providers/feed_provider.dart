import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import 'auth_provider.dart';

/// Identifies a feed type for parameterized providers.
enum FeedType {
  forYou,
  trending,
  friends,
  seasonal;

  String get endpoint {
    switch (this) {
      case FeedType.forYou:
        return '/feed/for-you';
      case FeedType.trending:
        return '/feed/trending';
      case FeedType.friends:
        return '/feed/friends';
      case FeedType.seasonal:
        return '/feed/seasonal';
    }
  }
}

/// Pagination parameters for feed requests.
class FeedPage extends Equatable {
  const FeedPage({required this.type, this.page = 1, this.limit = 20});

  final FeedType type;
  final int page;
  final int limit;

  @override
  List<Object?> get props => [type, page, limit];
}

/// Result of a paginated feed fetch.
class FeedResult {
  const FeedResult({
    required this.recipes,
    required this.page,
    required this.totalPages,
    required this.hasMore,
  });

  final List<Recipe> recipes;
  final int page;
  final int totalPages;
  final bool hasMore;
}

/// Fetches a single page of feed data by [FeedPage].
final feedPageProvider =
    FutureProvider.family<FeedResult, FeedPage>((ref, feedPage) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get(
    feedPage.type.endpoint,
    queryParameters: {
      'page': feedPage.page,
      'limit': feedPage.limit,
    },
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load feed.');
  }

  final data = result.data!;
  final recipes = (data['recipes'] as List<dynamic>?)
          ?.map((r) => Recipe.fromJson(r as Map<String, dynamic>))
          .toList() ??
      const [];
  final page = data['page'] as int? ?? feedPage.page;
  final totalPages = data['totalPages'] as int? ?? 1;

  return FeedResult(
    recipes: recipes,
    page: page,
    totalPages: totalPages,
    hasMore: page < totalPages,
  );
});

/// Manages paginated feed state for a given [FeedType].
///
/// Accumulates recipes across pages and supports load-more.
class FeedNotifier extends AutoDisposeAsyncNotifier<List<Recipe>> {
  FeedNotifier(this._feedType);

  final FeedType _feedType;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _loadMoreError;

  /// Error from the last loadMore attempt, if any. Cleared on next successful load.
  String? get loadMoreError => _loadMoreError;

  /// Whether more pages are available.
  bool get hasMore => _hasMore;

  /// Whether a load-more request is in progress.
  bool get isLoadingMore => _isLoadingMore;

  Future<FeedResult> _loadPage(int page) {
    return ref.read(feedPageProvider(FeedPage(type: _feedType, page: page)).future);
  }

  @override
  Future<List<Recipe>> build() async {
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
    _loadMoreError = null;

    final result = await _loadPage(1);

    _hasMore = result.hasMore;
    _currentPage = result.page;
    return result.recipes;
  }

  /// Loads the next page and appends results to the current list.
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;

    try {
      final nextPage = _currentPage + 1;
      final result = await _loadPage(nextPage);

      _currentPage = result.page;
      _hasMore = result.hasMore;
      _loadMoreError = null;

      final current = state.valueOrNull ?? [];
      state = AsyncData([...current, ...result.recipes]);
    } catch (e, st) {
      final current = state.valueOrNull ?? [];
      if (current.isEmpty) {
        state = AsyncError(e, st);
      } else {
        // Keep existing data and set _loadMoreError so UI can show a message.
        _loadMoreError = e.toString();
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Resets to page 1 and refetches.
  Future<void> refresh() async {
    final lastKnownPage = _currentPage;

    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;

    // Invalidate all cached pages fetched so far for this feed type.
    for (int i = 1; i <= lastKnownPage; i++) {
      ref.invalidate(feedPageProvider(FeedPage(type: _feedType, page: i)));
    }

    state = const AsyncLoading<List<Recipe>>();

    state = await AsyncValue.guard(() async {
      final result = await _loadPage(1);
      _currentPage = result.page;
      _hasMore = result.hasMore;
      return result.recipes;
    });
  }
}

/// Feed provider for the "For You" tab.
final forYouFeedProvider =
    AutoDisposeAsyncNotifierProvider<FeedNotifier, List<Recipe>>(
  () => FeedNotifier(FeedType.forYou),
);

/// Feed provider for the "Trending" tab.
final trendingFeedProvider =
    AutoDisposeAsyncNotifierProvider<FeedNotifier, List<Recipe>>(
  () => FeedNotifier(FeedType.trending),
);

/// Feed provider for the "Friends" tab.
final friendsFeedProvider =
    AutoDisposeAsyncNotifierProvider<FeedNotifier, List<Recipe>>(
  () => FeedNotifier(FeedType.friends),
);

/// Feed provider for the "Seasonal" tab.
final seasonalFeedProvider =
    AutoDisposeAsyncNotifierProvider<FeedNotifier, List<Recipe>>(
  () => FeedNotifier(FeedType.seasonal),
);
