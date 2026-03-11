import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../models/user.dart';
import 'auth_provider.dart';

/// Fetches the current user's own recipes from the API.
final myRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/recipes');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load recipes.');
  }

  final recipes = result.data!['recipes'] as List<dynamic>;
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

  final recipes = result.data!['recipes'] as List<dynamic>;
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

  final recipes = result.data!['recipes'] as List<dynamic>;
  return recipes
      .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Fetches a single recipe by ID.
final recipeDetailProvider =
    FutureProvider.family<Recipe, String>((ref, recipeId) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/recipes/$recipeId');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load recipe.');
  }

  final recipeData = result.data!['recipe'] as Map<String, dynamic>;
  return Recipe.fromJson(recipeData);
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

      final recipe =
          Recipe.fromJson(result.data!['recipe'] as Map<String, dynamic>);
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
      return Recipe.fromJson(
          result.data!['recipe'] as Map<String, dynamic>);
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
          await apiService.put('/recipes/$recipeId', data: data);
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update recipe.');
      }
      final recipe =
          Recipe.fromJson(result.data!['recipe'] as Map<String, dynamic>);
      _ref.invalidate(myRecipesProvider);
      _ref.invalidate(recipeDetailProvider(recipeId));
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
final userSearchProvider =
    FutureProvider.family<List<CheflessUser>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];

  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get(
    '/users/search',
    queryParameters: {'q': query.trim()},
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to search users.');
  }

  final users = result.data!['users'] as List<dynamic>;
  return users
      .map((u) => CheflessUser.fromJson(u as Map<String, dynamic>))
      .toList();
});
