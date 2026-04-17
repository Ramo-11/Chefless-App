import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cookbook.dart';
import '../models/recipe.dart';
import 'auth_provider.dart';

/// Filters that can be applied to recipes inside a cookbook.
class CookbookRecipeFilters {
  const CookbookRecipeFilters({
    this.label,
    this.dietaryTag,
    this.cuisineTag,
    this.maxCookTime,
    this.sort,
  });

  final String? label;
  final String? dietaryTag;
  final String? cuisineTag;
  final int? maxCookTime;
  final String? sort;

  Map<String, dynamic> toQueryParams() {
    return {
      if (label != null) 'label': label,
      if (dietaryTag != null) 'dietaryTag': dietaryTag,
      if (cuisineTag != null) 'cuisineTag': cuisineTag,
      if (maxCookTime != null) 'maxCookTime': maxCookTime,
      if (sort != null) 'sort': sort,
      'limit': 200,
    };
  }
}

/// All cookbooks owned by the current user.
final myCookbooksProvider = FutureProvider<List<Cookbook>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/cookbooks');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load cookbooks.');
  }
  final raw = result.data!['data'] as List<dynamic>? ?? const [];
  return raw
      .map((c) => Cookbook.fromJson(c as Map<String, dynamic>))
      .toList(growable: false);
});

/// Public cookbooks for any user (visibility-aware on the server).
final userCookbooksProvider =
    FutureProvider.family<List<Cookbook>, String>((ref, userId) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/users/$userId/cookbooks');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load cookbooks.');
  }
  final raw = result.data!['data'] as List<dynamic>? ?? const [];
  return raw
      .map((c) => Cookbook.fromJson(c as Map<String, dynamic>))
      .toList(growable: false);
});

/// Detail of a specific cookbook (with owner display info).
final cookbookDetailProvider =
    FutureProvider.family<Cookbook, String>((ref, cookbookId) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/cookbooks/$cookbookId');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load cookbook.');
  }
  final data = result.data!['cookbook'];
  if (data == null) throw Exception('Cookbook not found.');
  return Cookbook.fromJson(data as Map<String, dynamic>);
});

/// Recipes inside a cookbook, optionally filtered server-side.
class CookbookRecipesArgs {
  const CookbookRecipesArgs({
    required this.cookbookId,
    this.filters,
  });

  final String cookbookId;
  final CookbookRecipeFilters? filters;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CookbookRecipesArgs) return false;
    return cookbookId == other.cookbookId &&
        filters?.label == other.filters?.label &&
        filters?.dietaryTag == other.filters?.dietaryTag &&
        filters?.cuisineTag == other.filters?.cuisineTag &&
        filters?.maxCookTime == other.filters?.maxCookTime &&
        filters?.sort == other.filters?.sort;
  }

  @override
  int get hashCode => Object.hash(
        cookbookId,
        filters?.label,
        filters?.dietaryTag,
        filters?.cuisineTag,
        filters?.maxCookTime,
        filters?.sort,
      );
}

final cookbookRecipesProvider =
    FutureProvider.family<List<Recipe>, CookbookRecipesArgs>(
  (ref, args) async {
    final apiService = await ref.watch(apiServiceProvider.future);
    final result = await apiService.get(
      '/cookbooks/${args.cookbookId}/recipes',
      queryParameters: args.filters?.toQueryParams() ?? {'limit': 200},
    );

    if (result.isFailure || result.data == null) {
      throw Exception(result.error ?? 'Failed to load cookbook recipes.');
    }
    final raw = result.data!['data'] as List<dynamic>? ?? const [];
    return raw
        .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  },
);

/// Cookbook IDs that contain a specific recipe (used by add-to-cookbook UI).
final cookbooksContainingRecipeProvider =
    FutureProvider.family<Set<String>, String>((ref, recipeId) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get(
    '/cookbooks/containing',
    queryParameters: {'recipeId': recipeId},
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load cookbook membership.');
  }
  final raw = result.data!['cookbookIds'] as List<dynamic>? ?? const [];
  return raw.map((id) => id as String).toSet();
});

class CookbookActionNotifier extends StateNotifier<AsyncValue<void>> {
  CookbookActionNotifier(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  void _invalidateLists({String? cookbookId, String? recipeId, String? userId}) {
    _ref.invalidate(myCookbooksProvider);
    if (cookbookId != null) {
      _ref.invalidate(cookbookDetailProvider(cookbookId));
    }
    // Recipe lists inside cookbooks are keyed by (cookbookId, filters); the
    // cheapest correct option is to wipe the whole family when membership
    // changes.
    _ref.invalidate(cookbookRecipesProvider);
    if (recipeId != null) {
      _ref.invalidate(cookbooksContainingRecipeProvider(recipeId));
    }
    if (userId != null) {
      _ref.invalidate(userCookbooksProvider(userId));
    }
  }

  Future<Cookbook?> create({
    required String name,
    String? description,
    String? coverPhoto,
    bool isPrivate = false,
    List<String> recipeIds = const [],
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/cookbooks', data: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (coverPhoto != null && coverPhoto.isNotEmpty)
          'coverPhoto': coverPhoto,
        'isPrivate': isPrivate,
        if (recipeIds.isNotEmpty) 'recipeIds': recipeIds,
      });
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to create cookbook.');
      }
      final data = result.data!['cookbook'];
      final cookbook = Cookbook.fromJson(data as Map<String, dynamic>);
      _invalidateLists();
      state = const AsyncData<void>(null);
      return cookbook;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }

  Future<Cookbook?> update({
    required String cookbookId,
    String? name,
    String? description,
    bool clearDescription = false,
    String? coverPhoto,
    bool clearCoverPhoto = false,
    bool? isPrivate,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (clearDescription) {
        body['description'] = null;
      } else if (description != null) {
        body['description'] = description;
      }
      if (clearCoverPhoto) {
        body['coverPhoto'] = null;
      } else if (coverPhoto != null) {
        body['coverPhoto'] = coverPhoto;
      }
      if (isPrivate != null) body['isPrivate'] = isPrivate;

      final result = await apiService.patch('/cookbooks/$cookbookId', data: body);
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update cookbook.');
      }
      final data = result.data!['cookbook'];
      final cookbook = Cookbook.fromJson(data as Map<String, dynamic>);
      _invalidateLists(cookbookId: cookbookId);
      state = const AsyncData<void>(null);
      return cookbook;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }

  Future<bool> delete(String cookbookId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/cookbooks/$cookbookId');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to delete cookbook.');
      }
      _invalidateLists(cookbookId: cookbookId);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> addRecipes({
    required String cookbookId,
    required List<String> recipeIds,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/cookbooks/$cookbookId/recipes',
        data: {'recipeIds': recipeIds},
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to add recipes.');
      }
      _invalidateLists(cookbookId: cookbookId);
      for (final id in recipeIds) {
        _ref.invalidate(cookbooksContainingRecipeProvider(id));
      }
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> removeRecipe({
    required String cookbookId,
    required String recipeId,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result =
          await apiService.delete('/cookbooks/$cookbookId/recipes/$recipeId');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to remove recipe.');
      }
      _invalidateLists(cookbookId: cookbookId, recipeId: recipeId);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }
}

final cookbookActionProvider =
    StateNotifierProvider<CookbookActionNotifier, AsyncValue<void>>((ref) {
  return CookbookActionNotifier(ref);
});
