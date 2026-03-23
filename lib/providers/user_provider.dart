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

/// Fetches another user's public recipes.
final userRecipesProvider =
    FutureProvider.family<List<Recipe>, String>((ref, userId) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get(
    '/users/$userId/recipes',
    queryParameters: {'page': 1, 'limit': 50},
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load recipes.');
  }

  final recipes = result.data!['data'] as List<dynamic>? ?? [];
  return recipes
      .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
      .toList();
});
