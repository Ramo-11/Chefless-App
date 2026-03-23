import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';
import '../utils/json_helpers.dart';
import 'auth_provider.dart';

// ── State Providers ─────────────────────────────────────────────────────────

/// The current search query text.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// The current search filter type: all, recipes, users, or kitchens.
final searchTypeProvider = StateProvider<String>((ref) => 'all');

// ── Search Results ──────────────────────────────────────────────────────────

/// Holds search results fetched from the API.
///
/// Automatically debounces by 300ms after the query changes.
final searchResultsProvider =
    FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final type = ref.watch(searchTypeProvider);

  if (query.trim().isEmpty) {
    return const SearchResults(
      recipes: [],
      users: [],
      kitchens: [],
      totals: SearchTotals(),
    );
  }

  // Debounce: wait 300ms before firing the request.
  final completer = Completer<void>();
  final timer = Timer(const Duration(milliseconds: 300), completer.complete);
  ref.onDispose(timer.cancel);
  await completer.future;

  // If query changed during the debounce window, bail out.
  if (ref.watch(searchQueryProvider).trim() != query.trim()) {
    return const SearchResults(
      recipes: [],
      users: [],
      kitchens: [],
      totals: SearchTotals(),
    );
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
          ?.map((r) =>
              Recipe.fromJson(_normalizeRecipeJson(r as Map<String, dynamic>)))
          .toList() ??
      const [];

  final users = (data['users'] as List<dynamic>?)
          ?.map((u) => _parseSearchUser(u as Map<String, dynamic>))
          .toList() ??
      const [];

  final kitchens = (data['kitchens'] as List<dynamic>?)
          ?.map((k) => _parseSearchKitchen(k as Map<String, dynamic>))
          .toList() ??
      const [];

  final totalsJson = data['totals'] as Map<String, dynamic>?;
  final totals = SearchTotals(
    recipes: totalsJson?['recipes'] as int? ?? recipes.length,
    users: totalsJson?['users'] as int? ?? users.length,
    kitchens: totalsJson?['kitchens'] as int? ?? kitchens.length,
  );

  return SearchResults(
    recipes: recipes,
    users: users,
    kitchens: kitchens,
    totals: totals,
  );
});

// ── Recent Searches ─────────────────────────────────────────────────────────

const _recentSearchesKey = 'chefless_recent_searches';
const _maxRecentSearches = 10;

/// Manages recent search queries persisted in SharedPreferences.
final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<String>>(
  RecentSearchesNotifier.new,
);

class RecentSearchesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_recentSearchesKey);
    if (json == null) return [];
    final list = (jsonDecode(json) as List<dynamic>).cast<String>();
    return list;
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final current = state.valueOrNull ?? [];
    // Remove duplicate, add to front, cap at max.
    final updated = [
      trimmed,
      ...current.where((s) => s.toLowerCase() != trimmed.toLowerCase()),
    ].take(_maxRecentSearches).toList();

    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentSearchesKey, jsonEncode(updated));
  }

  Future<void> remove(String query) async {
    final current = state.valueOrNull ?? [];
    final updated =
        current.where((s) => s.toLowerCase() != query.toLowerCase()).toList();
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentSearchesKey, jsonEncode(updated));
  }

  Future<void> clearAll() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }
}

// ── JSON Parsing ────────────────────────────────────────────────────────────

/// Normalizes the search API recipe JSON to match [Recipe.fromJson] shape.
///
/// The search endpoint returns `author` as a nested object instead of
/// flat `authorId` / `authorName` / `authorPhoto` fields. The aggregation
/// pipeline may also return `_id` as an ObjectId and `createdAt` as a
/// DateTime rather than strings, and omits fields that the full recipe
/// endpoint would include.
Map<String, dynamic> _normalizeRecipeJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);

  // Flatten nested author object.
  if (normalized['author'] is Map<String, dynamic>) {
    final author = normalized['author'] as Map<String, dynamic>;
    normalized['authorId'] = asId(author['_id']);
    normalized['authorName'] = author['fullName'] as String?;
    normalized['authorPhoto'] = author['profilePicture'] as String?;
  }

  // Ensure _id is a plain string (aggregation may return ObjectId or extended JSON map).
  normalized['_id'] = asId(normalized['_id']);

  // Ensure authorId is a plain string.
  if (normalized['authorId'] != null) {
    normalized['authorId'] = asId(normalized['authorId']);
  }

  // Ensure createdAt / updatedAt are strings.
  if (normalized['createdAt'] != null && normalized['createdAt'] is! String) {
    normalized['createdAt'] = normalized['createdAt'].toString();
  }
  normalized['createdAt'] ??= DateTime.now().toIso8601String();
  normalized['updatedAt'] ??= normalized['createdAt'];

  // Provide defaults for fields the search projection omits.
  normalized['showSignature'] ??= false;
  normalized['isPrivate'] ??= false;
  normalized['isModifiedFork'] ??= false;
  normalized['baseServings'] ??= 1;
  normalized['ingredients'] ??= <dynamic>[];
  normalized['steps'] ??= <dynamic>[];

  return normalized;
}

SearchUser _parseSearchUser(Map<String, dynamic> json) {
  return SearchUser(
    id: asId(json['_id']),
    fullName: json['fullName'] as String? ?? '',
    profilePicture: json['profilePicture'] as String?,
    bio: json['bio'] as String?,
    isPublic: json['isPublic'] as bool? ?? true,
    recipesCount: json['recipesCount'] as int? ?? 0,
    followersCount: json['followersCount'] as int? ?? 0,
    spatulaBadge: json['spatulaBadge'] as String?,
  );
}

SearchKitchen _parseSearchKitchen(Map<String, dynamic> json) {
  final lead = json['lead'] as Map<String, dynamic>?;
  return SearchKitchen(
    id: asId(json['_id']),
    name: json['name'] as String? ?? '',
    photo: json['photo'] as String?,
    memberCount: json['memberCount'] as int? ?? 1,
    leadName: lead?['fullName'] as String? ?? 'Unknown',
    leadPhoto: lead?['profilePicture'] as String?,
  );
}

// ── Data Models ─────────────────────────────────────────────────────────────

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

class SearchKitchen {
  const SearchKitchen({
    required this.id,
    required this.name,
    this.photo,
    required this.memberCount,
    required this.leadName,
    this.leadPhoto,
  });

  final String id;
  final String name;
  final String? photo;
  final int memberCount;
  final String leadName;
  final String? leadPhoto;
}

class SearchTotals {
  const SearchTotals({
    this.recipes = 0,
    this.users = 0,
    this.kitchens = 0,
  });

  final int recipes;
  final int users;
  final int kitchens;

  int get total => recipes + users + kitchens;
}

class SearchResults {
  const SearchResults({
    required this.recipes,
    required this.users,
    required this.kitchens,
    required this.totals,
  });

  final List<Recipe> recipes;
  final List<SearchUser> users;
  final List<SearchKitchen> kitchens;
  final SearchTotals totals;

  bool get isEmpty => recipes.isEmpty && users.isEmpty && kitchens.isEmpty;
}
