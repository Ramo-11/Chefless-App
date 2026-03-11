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

  /// Whether more pages are available.
  bool get hasMore => _hasMore;

  /// Whether a load-more request is in progress.
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<Recipe>> build() async {
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;

    final feedPage = FeedPage(type: _feedType);
    final result = await ref.watch(feedPageProvider(feedPage).future);

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
      final feedPage = FeedPage(type: _feedType, page: nextPage);
      final result = await ref.read(feedPageProvider(feedPage).future);

      _currentPage = result.page;
      _hasMore = result.hasMore;

      final current = state.valueOrNull ?? [];
      state = AsyncData([...current, ...result.recipes]);
    } catch (e, st) {
      // Keep existing data but report the error via state.
      final current = state.valueOrNull ?? [];
      if (current.isEmpty) {
        state = AsyncError(e, st);
      }
      // If we already have data, silently fail — the user can retry.
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Resets to page 1 and refetches.
  Future<void> refresh() async {
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;

    // Invalidate all cached pages for this feed type.
    for (int i = 1; i <= _currentPage + 1; i++) {
      ref.invalidate(feedPageProvider(FeedPage(type: _feedType, page: i)));
    }

    ref.invalidateSelf();
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
