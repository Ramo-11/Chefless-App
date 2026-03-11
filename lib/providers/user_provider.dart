import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
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

  final userData = result.data!['user'] as Map<String, dynamic>;
  final followStatus =
      result.data!['followStatus'] as String? ?? 'none';

  return UserProfileResult(
    user: CheflessUser.fromJson(userData),
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
      // Invalidate the profile so the UI re-fetches with the new status.
      _ref.invalidate(userProfileProvider(userId));
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

  final followers = result.data!['followers'] as List<dynamic>;
  return followers
      .map((f) => CheflessUser.fromJson(f as Map<String, dynamic>))
      .toList();
});

/// Fetches the paginated list of users the current user is following.
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

  final following = result.data!['following'] as List<dynamic>;
  return following
      .map((f) => CheflessUser.fromJson(f as Map<String, dynamic>))
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

  final requests = result.data!['requests'] as List<dynamic>;
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
      id: json['_id'] as String,
      user: CheflessUser.fromJson(json['follower'] as Map<String, dynamic>),
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
