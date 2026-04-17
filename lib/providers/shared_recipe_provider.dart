import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shared_recipe.dart';
import 'auth_provider.dart';

/// Provides a paginated list of recipes shared with the current user.
final sharedRecipesProvider =
    AsyncNotifierProvider<SharedRecipesNotifier, List<SharedRecipe>>(
  SharedRecipesNotifier.new,
);

class SharedRecipesNotifier extends AsyncNotifier<List<SharedRecipe>> {
  String? _nextCursor;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  Future<List<SharedRecipe>> build() async {
    _nextCursor = null;
    _hasMore = true;
    return _fetchPage();
  }

  Future<List<SharedRecipe>> _fetchPage() async {
    final apiService = await ref.read(apiServiceProvider.future);
    final params = <String, dynamic>{'limit': 20};
    if (_nextCursor != null) params['cursor'] = _nextCursor;

    final result = await apiService.get(
      '/recipes/shared-with-me',
      queryParameters: params,
    );

    if (result.isFailure || result.data == null) {
      throw Exception(result.error ?? 'Failed to load shared recipes.');
    }

    final data = result.data!;
    final items = (data['items'] as List<dynamic>)
        .map((e) => SharedRecipe.fromJson(e as Map<String, dynamic>))
        .toList();

    _nextCursor = data['nextCursor'] as String?;
    _hasMore = _nextCursor != null;
    return items;
  }

  Future<void> loadMore() async {
    if (!_hasMore || state is AsyncLoading) return;
    final current = state.valueOrNull ?? [];
    final nextItems = await _fetchPage();
    state = AsyncData([...current, ...nextItems]);
  }
}
