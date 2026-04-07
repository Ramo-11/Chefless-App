import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kitchen.dart';
import '../models/recipe.dart';
import 'auth_provider.dart';

/// Fetches the current user's kitchen details and members.
///
/// Returns `null` if the user is not in a kitchen.
final myKitchenProvider = FutureProvider<KitchenDetail?>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/kitchens/me');

  if (result.isFailure || result.data == null) {
    // 404 means user is not in a kitchen — not an error.
    if (result.statusCode == 404) return null;
    throw Exception(result.error ?? 'Failed to load kitchen.');
  }

  // API may return 200 with no kitchen data if user isn't in one.
  final kitchenData = result.data!['kitchen'];
  if (kitchenData == null) return null;

  return KitchenDetail.fromJson(result.data!);
});

/// Parameters for fetching kitchen recipes with optional member filter.
class KitchenRecipesParams {
  const KitchenRecipesParams({this.page = 1, this.memberId});

  final int page;
  final String? memberId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KitchenRecipesParams &&
          other.page == page &&
          other.memberId == memberId;

  @override
  int get hashCode => Object.hash(page, memberId);
}

/// Fetches shared recipes from all kitchen members, with optional filtering.
final kitchenRecipesProvider = FutureProvider.family<List<Recipe>,
    KitchenRecipesParams>((ref, params) async {
  final apiService = await ref.watch(apiServiceProvider.future);

  final queryParams = <String, dynamic>{
    'page': params.page,
    'limit': 20,
  };
  if (params.memberId != null) {
    queryParams['memberId'] = params.memberId;
  }

  final result = await apiService.get(
    '/kitchens/recipes',
    queryParameters: queryParams,
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load kitchen recipes.');
  }

  final recipes = (result.data!['recipes'] ??
          result.data!['data']) as List<dynamic>? ??
      [];
  return recipes
      .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Handles kitchen create, join, leave, remove, transfer, permissions,
/// regenerate code, and delete actions.
class KitchenActionNotifier extends StateNotifier<AsyncValue<void>> {
  KitchenActionNotifier(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  Future<bool> createKitchen({
    required String name,
    String? photo,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final data = <String, dynamic>{
        'name': name,
      };
      if (photo != null) {
        data['photo'] = photo;
      }
      final result = await apiService.post('/kitchens', data: data);
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to create kitchen.');
      }
      _ref.invalidate(myKitchenProvider);
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> joinKitchen(String inviteCode) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/kitchens/join', data: {
        'inviteCode': inviteCode.trim().toUpperCase(),
      });
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to join kitchen.');
      }
      _ref.invalidate(myKitchenProvider);
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> leaveKitchen() async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/kitchens/leave');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to leave kitchen.');
      }
      _ref.invalidate(myKitchenProvider);
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> removeMember(String memberId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result =
          await apiService.post('/kitchens/members/$memberId/remove');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to remove member.');
      }
      _ref.invalidate(myKitchenProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> transferLead(String memberId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result =
          await apiService.post('/kitchens/members/$memberId/transfer');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to transfer lead role.');
      }
      _ref.invalidate(myKitchenProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> updatePermissions({
    required List<String> membersWithScheduleEdit,
    required List<String> membersWithApprovalPower,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.put('/kitchens/permissions', data: {
        'membersWithScheduleEdit': membersWithScheduleEdit,
        'membersWithApprovalPower': membersWithApprovalPower,
      });
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update permissions.');
      }
      _ref.invalidate(myKitchenProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> regenerateInviteCode() async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/kitchens/regenerate-code');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to regenerate invite code.');
      }
      _ref.invalidate(myKitchenProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> deleteKitchen() async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/kitchens/me');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to delete kitchen.');
      }
      _ref.invalidate(myKitchenProvider);
      _ref.invalidate(currentUserProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Replaces the kitchen's custom meal slot list (lead only).
  ///
  /// Pass the full desired list; the API handles deduplication and
  /// normalisation. Invalidates [myKitchenProvider] on success so the
  /// schedule screen re-renders with the updated slots.
  Future<bool> setCustomMealSlots(List<String> slots) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.put(
        '/kitchens/slots',
        data: {'customMealSlots': slots},
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update meal slots.');
      }
      _ref.invalidate(myKitchenProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> updateKitchenVisibility(bool isPublic) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.patch(
        '/kitchens/me',
        data: {'isPublic': isPublic},
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update kitchen privacy.');
      }
      _ref.invalidate(myKitchenProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }
}

final kitchenActionProvider =
    StateNotifierProvider<KitchenActionNotifier, AsyncValue<void>>((ref) {
  return KitchenActionNotifier(ref);
});
