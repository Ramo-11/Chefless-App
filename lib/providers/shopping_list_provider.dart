import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shopping_list.dart';
import 'auth_provider.dart';

/// Fetches all shopping lists for the current user (personal + kitchen).
final shoppingListsProvider =
    FutureProvider<List<ShoppingList>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/shopping-lists');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load shopping lists.');
  }

  final lists = result.data!['lists'] as List<dynamic>;
  return lists
      .map((e) => ShoppingList.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches a single shopping list by ID.
final shoppingListDetailProvider =
    FutureProvider.family<ShoppingList, String>((ref, id) async {
  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/shopping-lists/$id');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load shopping list.');
  }

  return ShoppingList.fromJson(
    result.data!['list'] as Map<String, dynamic>,
  );
});

/// Handles shopping list CRUD, item management, and schedule generation.
class ShoppingListActionNotifier extends StateNotifier<AsyncValue<void>> {
  ShoppingListActionNotifier(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  /// Creates a new shopping list.
  Future<String?> createList({required String name}) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post('/shopping-lists', data: {
        'name': name,
      });
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to create shopping list.');
      }
      _ref.invalidate(shoppingListsProvider);
      state = const AsyncData<void>(null);
      final listData = result.data!['list'] as Map<String, dynamic>;
      return listData['_id'] as String;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }

  /// Deletes a shopping list by ID.
  Future<bool> deleteList(String listId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/shopping-lists/$listId');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to delete shopping list.');
      }
      _ref.invalidate(shoppingListsProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Updates the name of a shopping list.
  Future<bool> updateListName(String listId, String name) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.put('/shopping-lists/$listId', data: {
        'name': name,
      });
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update shopping list.');
      }
      _ref.invalidate(shoppingListsProvider);
      _ref.invalidate(shoppingListDetailProvider(listId));
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Adds an item to a shopping list.
  Future<bool> addItem(
    String listId, {
    required String name,
    double? quantity,
    String? unit,
    String? category,
    String? notes,
    String? imageUrl,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final data = <String, dynamic>{'name': name};
      if (quantity != null) data['quantity'] = quantity;
      if (unit != null) data['unit'] = unit;
      if (category != null) data['category'] = category;
      if (notes != null) data['notes'] = notes;
      if (imageUrl != null) data['imageUrl'] = imageUrl;

      final result = await apiService.post(
        '/shopping-lists/$listId/items',
        data: data,
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to add item.');
      }
      _ref.invalidate(shoppingListDetailProvider(listId));
      _ref.invalidate(shoppingListsProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Updates an existing item in a shopping list.
  Future<bool> updateItem(
    String listId,
    String itemId, {
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? notes,
    String? imageUrl,
    bool clearQuantity = false,
    bool clearUnit = false,
    bool clearCategory = false,
    bool clearNotes = false,
    bool clearImageUrl = false,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (clearQuantity) {
        data['quantity'] = null;
      } else if (quantity != null) {
        data['quantity'] = quantity;
      }
      if (clearUnit) {
        data['unit'] = null;
      } else if (unit != null) {
        data['unit'] = unit;
      }
      if (clearCategory) {
        data['category'] = null;
      } else if (category != null) {
        data['category'] = category;
      }
      if (clearNotes) {
        data['notes'] = null;
      } else if (notes != null) {
        data['notes'] = notes;
      }
      if (clearImageUrl) {
        data['imageUrl'] = null;
      } else if (imageUrl != null) {
        data['imageUrl'] = imageUrl;
      }

      final result = await apiService.patch(
        '/shopping-lists/$listId/items/$itemId',
        data: data,
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update item.');
      }
      _ref.invalidate(shoppingListDetailProvider(listId));
      _ref.invalidate(shoppingListsProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Removes an item from a shopping list.
  Future<bool> removeItem(String listId, String itemId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete(
        '/shopping-lists/$listId/items/$itemId',
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to remove item.');
      }
      _ref.invalidate(shoppingListDetailProvider(listId));
      _ref.invalidate(shoppingListsProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Toggles the checked state of an item.
  Future<bool> toggleItem(String listId, String itemId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/shopping-lists/$listId/items/$itemId/toggle',
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to toggle item.');
      }
      _ref.invalidate(shoppingListDetailProvider(listId));
      _ref.invalidate(shoppingListsProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Clears all completed (checked) items from a shopping list.
  Future<bool> clearCompleted(String listId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/shopping-lists/$listId/clear-completed',
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to clear completed items.');
      }
      _ref.invalidate(shoppingListDetailProvider(listId));
      _ref.invalidate(shoppingListsProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Generates a shopping list from the kitchen schedule for a date range.
  Future<String?> generateFromSchedule({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/shopping-lists/generate',
        data: {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
      );
      if (result.isFailure) {
        throw Exception(
          result.error ?? 'Failed to generate shopping list.',
        );
      }
      _ref.invalidate(shoppingListsProvider);
      state = const AsyncData<void>(null);
      final listData = result.data!['list'] as Map<String, dynamic>;
      return listData['_id'] as String;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return null;
    }
  }
}

final shoppingListActionProvider =
    StateNotifierProvider<ShoppingListActionNotifier, AsyncValue<void>>(
        (ref) {
  return ShoppingListActionNotifier(ref);
});
