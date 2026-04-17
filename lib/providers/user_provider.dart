import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import '../models/user.dart';
import '../utils/json_helpers.dart';
import 'auth_provider.dart';

/// Fetches a user profile by ID from the API.
///
/// Returns the [CheflessUser] along with the caller's follow status towards
/// that user (the API is expected to include a `followStatus` field:
/// `"none"`, `"pending"`, or `"active"`).
final userProfileProvider =
    FutureProvider.family<UserProfileResult, String>((ref, userId) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/users/$userId');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load user profile.');
  }

  final data = result.data!;

  final userData = data['user'];
  if (userData == null) {
    throw Exception('User not found.');
  }

  // followStatus may be a String ("none"/"pending"/"active") or a Map
  // like {following: bool, status: String?} depending on the API version.
  final rawFollow = data['followStatus'];
  String followStatus;
  if (rawFollow is String) {
    followStatus = rawFollow;
  } else if (rawFollow is Map) {
    followStatus = (rawFollow['status'] as String?) ??
        (rawFollow['following'] == true ? 'active' : 'none');
  } else {
    followStatus = 'none';
  }

  return UserProfileResult(
    user: CheflessUser.fromJson(userData as Map<String, dynamic>),
    followStatus: followStatus,
  );
});

/// Encapsulates a user profile together with the viewer's follow relationship.
class UserProfileResult {
  const UserProfileResult({
    required this.user,
    required this.followStatus,
  });

  final CheflessUser user;

  /// One of `"none"`, `"pending"`, or `"active"`.
  final String followStatus;
}

/// Performs follow / unfollow actions against the API.
///
/// Usage:
/// ```dart
/// ref.read(followActionProvider.notifier).follow(userId);
/// ref.read(followActionProvider.notifier).unfollow(userId);
/// ```
class FollowActionNotifier extends StateNotifier<AsyncValue<void>> {
  FollowActionNotifier(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  Future<void> follow(String userId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/users/$userId/follow');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to follow user.');
      }
      _ref.invalidate(userProfileProvider(userId));
      _ref.invalidate(followingProvider(1));
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<void> unfollow(String userId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/users/$userId/follow');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to unfollow user.');
      }
      _ref.invalidate(userProfileProvider(userId));
      _ref.invalidate(followingProvider(1));
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }
}

final followActionProvider =
    StateNotifierProvider<FollowActionNotifier, AsyncValue<void>>((ref) {
  return FollowActionNotifier(ref);
});

/// Fetches the paginated list of followers for the current user.
/// API returns Follow records with `followerId` populated as the user object.
final followersProvider =
    FutureProvider.family<List<CheflessUser>, int>((ref, page) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get(
    '/users/me/followers',
    queryParameters: {'page': page, 'limit': 20},
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load followers.');
  }

  final records = result.data!['data'] as List<dynamic>? ?? [];
  return records
      .map((r) {
        final follow = r as Map<String, dynamic>;
        final user = follow['followerId'];
        if (user is Map<String, dynamic>) {
          return CheflessUser.fromJson(user);
        }
        return null;
      })
      .whereType<CheflessUser>()
      .toList();
});

/// Fetches the paginated list of users the current user is following.
/// API returns Follow records with `followingId` populated as the user object.
final followingProvider =
    FutureProvider.family<List<CheflessUser>, int>((ref, page) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get(
    '/users/me/following',
    queryParameters: {'page': page, 'limit': 20},
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load following.');
  }

  final records = result.data!['data'] as List<dynamic>? ?? [];
  return records
      .map((r) {
        final follow = r as Map<String, dynamic>;
        final user = follow['followingId'];
        if (user is Map<String, dynamic>) {
          return CheflessUser.fromJson(user);
        }
        return null;
      })
      .whereType<CheflessUser>()
      .toList();
});

/// Fetches the list of pending follow requests for the current user.
final pendingRequestsProvider =
    FutureProvider<List<PendingFollowRequest>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/users/me/requests');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load follow requests.');
  }

  final requests = result.data!['requests'] as List<dynamic>? ?? [];
  return requests
      .map((r) => PendingFollowRequest.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// A pending follow request containing the request ID and the requesting user.
class PendingFollowRequest {
  const PendingFollowRequest({
    required this.id,
    required this.user,
  });

  final String id;
  final CheflessUser user;

  factory PendingFollowRequest.fromJson(Map<String, dynamic> json) {
    return PendingFollowRequest(
      id: asId(json['_id']),
      user: CheflessUser.fromJson(
        (json['follower'] ?? (throw Exception('Follow request missing follower data.')))
            as Map<String, dynamic>,
      ),
    );
  }
}

/// Handles accepting or denying pending follow requests.
class FollowRequestActionNotifier extends StateNotifier<AsyncValue<void>> {
  FollowRequestActionNotifier(this._ref)
      : super(const AsyncData<void>(null));

  final Ref _ref;

  Future<void> accept(String requestId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result =
          await apiService.post('/users/requests/$requestId/accept');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to accept request.');
      }
      _ref.invalidate(pendingRequestsProvider);
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }

  Future<void> deny(String requestId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result =
          await apiService.post('/users/requests/$requestId/deny');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to deny request.');
      }
      _ref.invalidate(pendingRequestsProvider);
      state = const AsyncData<void>(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
    }
  }
}

final followRequestActionProvider = StateNotifierProvider<
    FollowRequestActionNotifier, AsyncValue<void>>((ref) {
  return FollowRequestActionNotifier(ref);
});

int _intFromApi(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.round();
  return fallback;
}

List<Recipe> _parseUserRecipesPayload(Map<String, dynamic> data) {
  final raw = data['data'] as List<dynamic>? ?? [];
  return raw
      .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
      .toList();
}

/// One page of another user's shared recipes (see [userRecipesPagedProvider]).
@immutable
class UserRecipesPagedState {
  const UserRecipesPagedState({
    required this.recipes,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    this.isLoadingMore = false,
  });

  final List<Recipe> recipes;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final bool isLoadingMore;

  bool get hasMore => currentPage < totalPages;

  UserRecipesPagedState copyWith({
    List<Recipe>? recipes,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    bool? isLoadingMore,
  }) {
    return UserRecipesPagedState(
      recipes: recipes ?? this.recipes,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Loads `/users/:id/recipes` page-by-page (API limit max 50 per request).
class UserRecipesPagedNotifier
    extends StateNotifier<AsyncValue<UserRecipesPagedState>> {
  UserRecipesPagedNotifier(this._ref, this.userId) : super(const AsyncLoading()) {
    Future.microtask(loadInitial);
  }

  final Ref _ref;
  final String userId;

  static const int _pageSize = 20;

  Future<void> refresh() => loadInitial();

  Future<void> loadInitial() async {
    state = const AsyncLoading();
    try {
      await _fetchAndSetPage(1, append: false);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    final snapshot = current;
    state = AsyncData(snapshot.copyWith(isLoadingMore: true));
    try {
      await _fetchAndSetPage(snapshot.currentPage + 1, append: true);
    } catch (_) {
      state = AsyncData(snapshot.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _fetchAndSetPage(int page, {required bool append}) async {
    final apiService = await _ref.read(apiServiceProvider.future);
    final result = await apiService.get(
      '/users/$userId/recipes',
      queryParameters: {'page': page, 'limit': _pageSize},
    );

    if (result.isFailure || result.data == null) {
      throw Exception(result.error ?? 'Failed to load recipes.');
    }

    final data = result.data!;
    final batch = _parseUserRecipesPayload(data);
    final totalCount = _intFromApi(data['total'], fallback: batch.length);
    var totalPages = _intFromApi(data['totalPages'], fallback: -1);
    if (totalPages < 0) {
      totalPages = totalCount == 0
          ? 0
          : (totalCount + _pageSize - 1) ~/ _pageSize;
    }

    if (append) {
      final previous = state.asData!.value;
      state = AsyncData(
        UserRecipesPagedState(
          recipes: [...previous.recipes, ...batch],
          currentPage: page,
          totalPages: totalPages,
          totalCount: totalCount,
        ),
      );
    } else {
      state = AsyncData(
        UserRecipesPagedState(
          recipes: batch,
          currentPage: page,
          totalPages: totalPages,
          totalCount: totalCount,
        ),
      );
    }
  }
}

final userRecipesPagedProvider = StateNotifierProvider.autoDispose
    .family<UserRecipesPagedNotifier, AsyncValue<UserRecipesPagedState>, String>(
  (ref, userId) => UserRecipesPagedNotifier(ref, userId),
);
