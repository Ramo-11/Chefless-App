import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../models/user.dart';
import 'auth_provider.dart';
import 'feed_provider.dart';

/// Fetches the current user's own recipes from the API.
final myRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/recipes');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load recipes.');
  }

  final recipes = result.data!['data'] as List<dynamic>? ?? [];
  return recipes
      .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
      .toList();
});

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

/// Fetches recipes the current user has forked.
final forkedRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/recipes/forked');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load forked recipes.');
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
      _ref.invalidate(myRecipesProvider);
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

/// Handles recipe actions: like, unlike, fork, delete, update.
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
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/recipes/$recipeId/like');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to like recipe.');
      }
      _ref.invalidate(recipeDetailProvider(recipeId));
      _ref.invalidate(likedRecipesProvider);
      _invalidateFeeds();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<void> unlike(String recipeId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/recipes/$recipeId/like');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to unlike recipe.');
      }
      _ref.invalidate(recipeDetailProvider(recipeId));
      _ref.invalidate(likedRecipesProvider);
      _invalidateFeeds();
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<Recipe?> fork(String recipeId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/recipes/$recipeId/fork');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to fork recipe.');
      }
      _ref.invalidate(myRecipesProvider);
      _ref.invalidate(forkedRecipesProvider);
      _ref.invalidate(recipeDetailProvider(recipeId));
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
      final forkedData = result.data!['recipe'];
      if (forkedData == null) {
        throw Exception('Failed to fork recipe: no data returned.');
      }
      return Recipe.fromJson(
          forkedData as Map<String, dynamic>);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }

  Future<void> deleteRecipe(String recipeId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/recipes/$recipeId');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to delete recipe.');
      }
      _ref.invalidate(myRecipesProvider);
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<Recipe?> update(
      String recipeId, Map<String, dynamic> data) async {
    state = const AsyncLoading<void>();
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
      final recipe =
          Recipe.fromJson(updatedData as Map<String, dynamic>);
      _ref.invalidate(myRecipesProvider);
      _ref.invalidate(likedRecipesProvider);
      _ref.invalidate(forkedRecipesProvider);
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(recipeDetailProvider(recipeId));
      _invalidateFeeds();
      state = const AsyncData<void>(null);
      return recipe;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }

  Future<void> share(
      String recipeId, String recipientId, String? message) async {
    state = const AsyncLoading<void>();
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
      state = const AsyncData<void>(null);
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
