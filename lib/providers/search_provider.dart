import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../models/user.dart';
import 'auth_provider.dart';

/// The current search query text.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// The current search filter type: all, recipes, or users.
final searchTypeProvider = StateProvider<String>((ref) => 'all');

/// Holds search results (recipes + users) fetched from the API.
///
/// Automatically debounces by 300ms after the query changes.
final searchResultsProvider =
    FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final type = ref.watch(searchTypeProvider);

  if (query.trim().isEmpty) {
    return const SearchResults(recipes: [], users: []);
  }

  // Debounce: wait 300ms before firing the request.
  final completer = Completer<void>();
  final timer = Timer(const Duration(milliseconds: 300), completer.complete);
  ref.onDispose(timer.cancel);
  await completer.future;

  // If query changed during the debounce window, this provider is already
  // stale and will be disposed — safe to return empty.
  if (ref.watch(searchQueryProvider).trim() != query.trim()) {
    return const SearchResults(recipes: [], users: []);
  }

  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get(
    '/search',
    queryParameters: {
      'q': query.trim(),
      'type': type,
    },
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Search failed.');
  }

  final data = result.data!;

  final recipes = (data['recipes'] as List<dynamic>?)
          ?.map((r) => Recipe.fromJson(_normalizeRecipeJson(r as Map<String, dynamic>)))
          .toList() ??
      const [];

  final users = (data['users'] as List<dynamic>?)
          ?.map((u) => _parseSearchUser(u as Map<String, dynamic>))
          .toList() ??
      const [];

  return SearchResults(recipes: recipes, users: users);
});

/// Normalizes the search API recipe JSON to match the [Recipe.fromJson] shape.
///
/// The search endpoint returns `author` as a nested object instead of
/// flat `authorId` / `authorName` / `authorPhoto` fields.
Map<String, dynamic> _normalizeRecipeJson(Map<String, dynamic> json) {
  if (json.containsKey('author') && json['author'] is Map<String, dynamic>) {
    final author = json['author'] as Map<String, dynamic>;
    return {
      ...json,
      'authorId': author['_id'] as String,
      'authorName': author['fullName'] as String?,
      'authorPhoto': author['profilePicture'] as String?,
    };
  }
  return json;
}

/// Parses a user search result into a lightweight [SearchUser].
SearchUser _parseSearchUser(Map<String, dynamic> json) {
  return SearchUser(
    id: json['_id'] as String,
    fullName: json['fullName'] as String,
    profilePicture: json['profilePicture'] as String?,
    bio: json['bio'] as String?,
    isPublic: json['isPublic'] as bool? ?? true,
    recipesCount: json['recipesCount'] as int? ?? 0,
    followersCount: json['followersCount'] as int? ?? 0,
    spatulaBadge: json['spatulaBadge'] as String?,
  );
}

/// Lightweight user model for search results (avoids requiring all
/// [CheflessUser] fields that the search API does not return).
class SearchUser {
  const SearchUser({
    required this.id,
    required this.fullName,
    this.profilePicture,
    this.bio,
    required this.isPublic,
    required this.recipesCount,
    required this.followersCount,
    this.spatulaBadge,
  });

  final String id;
  final String fullName;
  final String? profilePicture;
  final String? bio;
  final bool isPublic;
  final int recipesCount;
  final int followersCount;
  final String? spatulaBadge;
}

/// Combined search results for recipes and users.
class SearchResults {
  const SearchResults({
    required this.recipes,
    required this.users,
  });

  final List<Recipe> recipes;
  final List<SearchUser> users;

  bool get isEmpty => recipes.isEmpty && users.isEmpty;
}
