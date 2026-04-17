import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../models/user.dart';
import 'auth_provider.dart';
import 'feed_provider.dart';

/// The current user's own recipes.
///
/// Exposes optimistic mutations so list mutations (delete, create, update,
/// remix) feel instant. Mutations apply locally first; the server call is
/// awaited and rollback happens on failure.
class MyRecipesNotifier extends AsyncNotifier<List<Recipe>> {
  @override
  Future<List<Recipe>> build() async {
    final apiService = await ref.watch(apiServiceProvider.future);
    final result = await apiService.get('/recipes');
    if (result.isFailure || result.data == null) {
      throw Exception(result.error ?? 'Failed to load recipes.');
    }
    final recipes = result.data!['data'] as List<dynamic>? ?? [];
    return recipes
        .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Removes a recipe from the local list, returning a snapshot for rollback.
  ({Recipe? removed, int index}) removeLocal(String recipeId) {
    final current = state.valueOrNull;
    if (current == null) return (removed: null, index: -1);
    final idx = current.indexWhere((r) => r.id == recipeId);
    if (idx == -1) return (removed: null, index: -1);
    final removed = current[idx];
    final next = [...current]..removeAt(idx);
    state = AsyncData<List<Recipe>>(next);
    return (removed: removed, index: idx);
  }

  /// Re-inserts a recipe at the given index — used to roll back a failed delete.
  void insertAt(Recipe recipe, int index) {
    final current = state.valueOrNull ?? const <Recipe>[];
    final clamped = index.clamp(0, current.length);
    state = AsyncData<List<Recipe>>(
      [...current.sublist(0, clamped), recipe, ...current.sublist(clamped)],
    );
  }

  /// Replaces a recipe by id with the updated version (after a successful PATCH).
  void replaceLocal(Recipe recipe) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData<List<Recipe>>(
      [for (final r in current) r.id == recipe.id ? recipe : r],
    );
  }

  /// Prepends a freshly created or remixed recipe to the top of the list.
  void prependLocal(Recipe recipe) {
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncData<List<Recipe>>([recipe]);
      return;
    }
    state = AsyncData<List<Recipe>>([recipe, ...current]);
  }

  /// Forces a fresh server fetch (for pull-to-refresh).
  Future<void> refresh() async {
    state = const AsyncLoading<List<Recipe>>();
    state = await AsyncValue.guard(build);
  }
}

final myRecipesProvider =
    AsyncNotifierProvider<MyRecipesNotifier, List<Recipe>>(
  MyRecipesNotifier.new,
);

/// Fetches recipes the current user has liked.
final likedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/recipes/liked');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load liked recipes.');
  }

  final recipes = result.data!['data'] as List<dynamic>? ?? [];
  return recipes
      .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Fetches recipes the current user has saved.
final savedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/recipes/saved');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load saved recipes.');
  }

  final recipes = result.data!['data'] as List<dynamic>? ?? [];
  return recipes
      .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Fetches recipes the current user remixed from others (API: `/recipes/forked`).
final forkedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/recipes/forked');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load remixed recipes.');
  }

  final recipes = result.data!['data'] as List<dynamic>? ?? [];
  return recipes
      .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Fetches a single recipe by ID.
/// Cached results auto-invalidate after 5 minutes to prevent stale data.
final recipeDetailProvider =
    FutureProvider.family<Recipe, String>((ref, recipeId) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/recipes/$recipeId');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load recipe.');
  }

  final recipeData = result.data!['recipe'];
  if (recipeData == null) {
    throw Exception('Recipe not found.');
  }

  // Auto-invalidate cached recipe detail after 5 minutes
  ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), () {
    ref.invalidateSelf();
  });
  ref.onDispose(() => timer.cancel());

  return Recipe.fromJson(recipeData as Map<String, dynamic>);
});

/// Handles recipe creation.
class CreateRecipeNotifier extends StateNotifier<AsyncValue<Recipe?>> {
  CreateRecipeNotifier(this._ref) : super(const AsyncData<Recipe?>(null));

  final Ref _ref;

  Future<Recipe?> create(Map<String, dynamic> data) async {
    state = const AsyncLoading<Recipe?>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/recipes', data: data);

      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to create recipe.');
      }

      final recipeData = result.data!['recipe'];
      if (recipeData == null) {
        throw Exception('Failed to create recipe: no data returned.');
      }
      final recipe =
          Recipe.fromJson(recipeData as Map<String, dynamic>);
      // Surgically prepend the new recipe instead of refetching the whole list.
      _ref.read(myRecipesProvider.notifier).prependLocal(recipe);
      _ref.invalidate(currentUserProvider);
      state = AsyncData<Recipe?>(recipe);
      return recipe;
    } catch (e, st) {
      state = AsyncError<Recipe?>(e, st);
      return null;
    }
  }
}

final createRecipeProvider =
    StateNotifierProvider<CreateRecipeNotifier, AsyncValue<Recipe?>>((ref) {
  return CreateRecipeNotifier(ref);
});

/// Handles recipe actions: like, unlike, remix, duplicate, delete, update.
class RecipeActionNotifier extends StateNotifier<AsyncValue<void>> {
  RecipeActionNotifier(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  void _invalidateFeeds() {
    // Invalidate the underlying page cache so fresh data is fetched.
    for (final type in FeedType.values) {
      _ref.invalidate(feedPageProvider(FeedPage(type: type)));
    }
    // Then invalidate the notifiers so they re-run build().
    _ref.invalidate(forYouFeedProvider);
    _ref.invalidate(trendingFeedProvider);
    _ref.invalidate(friendsFeedProvider);
    _ref.invalidate(seasonalFeedProvider);
  }

  Future<void> like(String recipeId) async {
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/recipes/$recipeId/like');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to like recipe.');
      }
      // Detail view's `isLiked` flag depends on a fresh fetch.
      // Liked-list refreshes lazily when user opens that tab.
      _ref.invalidate(recipeDetailProvider(recipeId));
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<void> unlike(String recipeId) async {
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/recipes/$recipeId/like');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to unlike recipe.');
      }
      _ref.invalidate(recipeDetailProvider(recipeId));
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<void> save(String recipeId) async {
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/recipes/$recipeId/save');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to save recipe.');
      }
      _ref.invalidate(recipeDetailProvider(recipeId));
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<void> unsave(String recipeId) async {
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/recipes/$recipeId/save');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to unsave recipe.');
      }
      _ref.invalidate(recipeDetailProvider(recipeId));
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<Recipe?> remix(String recipeId) async {
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/recipes/$recipeId/fork');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to remix recipe.');
      }
      final forkedData = result.data!['recipe'];
      if (forkedData == null) {
        throw Exception('Failed to remix recipe: no data returned.');
      }
      final forked = Recipe.fromJson(forkedData as Map<String, dynamic>);
      _ref.read(myRecipesProvider.notifier).prependLocal(forked);
      _ref.invalidate(forkedRecipesProvider);
      _ref.invalidate(recipeDetailProvider(recipeId));
      _ref.invalidate(currentUserProvider);
      return forked;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }

  Future<Recipe?> duplicateOwn(String recipeId) async {
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/recipes/$recipeId/duplicate');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to duplicate recipe.');
      }
      final data = result.data!['recipe'];
      if (data == null) {
        throw Exception('Failed to duplicate recipe: no data returned.');
      }
      final copy = Recipe.fromJson(data as Map<String, dynamic>);
      _ref.read(myRecipesProvider.notifier).prependLocal(copy);
      _ref.invalidate(currentUserProvider);
      return copy;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }

  /// Optimistically removes the recipe from the local list, awaits the server
  /// delete, and rolls back on failure. Returns `true` on success.
  Future<bool> deleteRecipe(String recipeId) async {
    final notifier = _ref.read(myRecipesProvider.notifier);
    final snapshot = notifier.removeLocal(recipeId);
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/recipes/$recipeId');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to delete recipe.');
      }
      // Server confirmed — clean up dependent caches lazily.
      _ref.invalidate(forkedRecipesProvider);
      _ref.invalidate(currentUserProvider);
      // The recipe detail cache for this id is now stale; drop it so any
      // back-stack reopen yields a clean 404 instead of a phantom view.
      _ref.invalidate(recipeDetailProvider(recipeId));
      return true;
    } catch (e, st) {
      // Rollback the optimistic removal so the user sees the recipe restored.
      if (snapshot.removed != null && snapshot.index >= 0) {
        notifier.insertAt(snapshot.removed!, snapshot.index);
      }
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<Recipe?> update(
      String recipeId, Map<String, dynamic> data) async {
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result =
          await apiService.patch('/recipes/$recipeId', data: data);
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update recipe.');
      }
      final updatedData = result.data!['recipe'];
      if (updatedData == null) {
        throw Exception('Failed to update recipe: no data returned.');
      }
      final recipe = Recipe.fromJson(updatedData as Map<String, dynamic>);
      // Surgically replace in the user's own list; other lists pick it up
      // when they're next opened/refreshed.
      _ref.read(myRecipesProvider.notifier).replaceLocal(recipe);
      _ref.invalidate(recipeDetailProvider(recipeId));
      _invalidateFeeds();
      return recipe;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }

  Future<void> share(
      String recipeId, String recipientId, String? message) async {
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/recipes/$recipeId/share',
        data: {
          'recipientId': recipientId,
          if (message != null && message.isNotEmpty) 'message': message,
        },
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to share recipe.');
      }
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }
}

final recipeActionProvider =
    StateNotifierProvider<RecipeActionNotifier, AsyncValue<void>>((ref) {
  return RecipeActionNotifier(ref);
});

/// Searches users for the share recipe sheet.
/// Holds imported recipe pre-fill data after a successful URL import.
///
/// `ImportRecipeSheet` sets this before navigating to `CreateRecipeScreen`.
/// `CreateRecipeScreen` reads + clears it in `initState` via a post-frame
/// callback. Using `null` to signal "no pending import".
final importedRecipeDataProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

final userSearchProvider =
    FutureProvider.family<List<CheflessUser>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];

  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get(
    '/search',
    queryParameters: {'q': query.trim(), 'type': 'users'},
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to search users.');
  }

  final users = result.data!['users'] as List<dynamic>? ?? [];
  return users
      .map((u) => CheflessUser.fromJson(u as Map<String, dynamic>))
      .toList();
});
