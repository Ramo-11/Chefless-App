import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/recipe.dart';
import '../models/schedule_entry.dart';
import '../models/shopping_list.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'database_service.dart';

/// Handles bidirectional sync between the local SQLite cache and the API.
///
/// - [pushPendingChanges]: replays queued offline mutations to the server.
/// - [pullLatest]: fetches fresh data from the API and caches it locally.
/// - [syncAll]: pushes then pulls (safe order so server has the latest
///   local changes before we overwrite the cache).
class SyncService {
  const SyncService({
    required this.apiService,
    required this.databaseService,
  });

  final ApiService apiService;
  final DatabaseService databaseService;

  /// Replays every entry in the sync queue against the API. Entries that
  /// succeed are removed; entries that fail remain for the next attempt.
  Future<void> pushPendingChanges() async {
    final queue = await databaseService.getQueue();

    for (final entry in queue) {
      try {
        final ApiResult<Map<String, dynamic>> result;

        switch (entry.method.toUpperCase()) {
          case 'POST':
            result = await apiService.post(entry.endpoint, data: entry.body);
          case 'PUT':
            result = await apiService.put(entry.endpoint, data: entry.body);
          case 'DELETE':
            result = await apiService.delete(entry.endpoint, data: entry.body);
          default:
            // GET operations should never be queued.
            await databaseService.removeFromQueue(entry.id);
            continue;
        }

        if (result.isSuccess) {
          await databaseService.removeFromQueue(entry.id);
        } else {
          // If the server returned a 4xx client error (other than 408/429),
          // the request will never succeed — remove it to avoid infinite loops.
          final status = result.statusCode ?? 0;
          if (status >= 400 && status < 500 && status != 408 && status != 429) {
            debugPrint(
              'SyncService: dropping failed queue entry '
              '${entry.id} (${entry.action}): ${result.error}',
            );
            await databaseService.removeFromQueue(entry.id);
          }
        }
      } catch (e) {
        // Network or unexpected error — leave in queue for next attempt.
        debugPrint('SyncService: push error for ${entry.id}: $e');
      }
    }
  }

  /// Fetches the latest data from the API and stores it in the local cache.
  Future<void> pullLatest(String userId) async {
    await Future.wait([
      _pullUserProfile(),
      _pullMyRecipes(),
      _pullLikedRecipes(),
      _pullSchedule(),
      _pullShoppingLists(),
      _pullNotifications(),
    ]);
  }

  /// Pushes pending changes first, then pulls fresh data.
  Future<void> syncAll(String userId) async {
    await pushPendingChanges();
    await pullLatest(userId);
  }

  // ── Private Pull Methods ──────────────────────────────────────────────────

  Future<void> _pullUserProfile() async {
    try {
      final result = await apiService.get('/auth/me');
      if (result.isSuccess && result.data != null) {
        final userData = result.data!['user'];
        if (userData is Map<String, dynamic>) {
          final user = CheflessUser.fromJson(userData);
          await databaseService.upsert('users', user.id, user.toJson());
        }
      }
    } catch (e) {
      debugPrint('SyncService: failed to pull user profile: $e');
    }
  }

  Future<void> _pullMyRecipes() async {
    try {
      final result = await apiService.get('/recipes');
      if (result.isSuccess && result.data != null) {
        final recipes = result.data!['recipes'] as List<dynamic>? ?? [];
        for (final r in recipes) {
          final json = r as Map<String, dynamic>;
          final recipe = Recipe.fromJson(json);
          await databaseService.upsert(
            'recipes',
            recipe.id,
            recipe.toJson(),
            extraColumns: {'authorId': recipe.authorId},
          );
        }
      }
    } catch (e) {
      debugPrint('SyncService: failed to pull recipes: $e');
    }
  }

  Future<void> _pullLikedRecipes() async {
    try {
      final result = await apiService.get('/recipes/liked');
      if (result.isSuccess && result.data != null) {
        final recipes = result.data!['recipes'] as List<dynamic>? ?? [];
        for (final r in recipes) {
          final json = r as Map<String, dynamic>;
          final recipe = Recipe.fromJson(json);
          await databaseService.upsert(
            'recipes',
            recipe.id,
            recipe.toJson(),
            extraColumns: {'authorId': recipe.authorId},
          );
        }
      }
    } catch (e) {
      debugPrint('SyncService: failed to pull liked recipes: $e');
    }
  }

  Future<void> _pullSchedule() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final end = start.add(const Duration(days: 13)); // Current + next week.

      final result = await apiService.get(
        '/schedule',
        queryParameters: {
          'start': start.toIso8601String().split('T').first,
          'end': end.toIso8601String().split('T').first,
        },
      );

      if (result.isSuccess && result.data != null) {
        final entries = result.data!['entries'] as List<dynamic>? ?? [];
        for (final e in entries) {
          final json = e as Map<String, dynamic>;
          final entry = ScheduleEntry.fromJson(json);
          await databaseService.upsert(
            'schedule_entries',
            entry.id,
            entry.toJson(),
            extraColumns: {
              'kitchenId': entry.kitchenId ?? '',
              'date': entry.date.toIso8601String(),
            },
          );
        }
      }
    } catch (e) {
      debugPrint('SyncService: failed to pull schedule: $e');
    }
  }

  Future<void> _pullShoppingLists() async {
    try {
      final result = await apiService.get('/shopping-lists');
      if (result.isSuccess && result.data != null) {
        final lists = result.data!['lists'] as List<dynamic>? ?? [];
        for (final l in lists) {
          final json = l as Map<String, dynamic>;
          final list = ShoppingList.fromJson(json);
          await databaseService.upsert(
            'shopping_lists',
            list.id,
            list.toJson(),
          );
        }
      }
    } catch (e) {
      debugPrint('SyncService: failed to pull shopping lists: $e');
    }
  }

  Future<void> _pullNotifications() async {
    try {
      final result = await apiService.get(
        '/notifications',
        queryParameters: {'page': 1, 'limit': 50},
      );

      if (result.isSuccess && result.data != null) {
        // Clear old notifications and store the latest batch.
        await databaseService.clear('notifications');
        final notifications =
            result.data!['data'] as List<dynamic>? ?? [];
        for (final n in notifications) {
          final json = n as Map<String, dynamic>;
          final notification = AppNotification.fromJson(json);
          await databaseService.upsert(
            'notifications',
            notification.id,
            notification.toJson(),
          );
        }
      }
    } catch (e) {
      debugPrint('SyncService: failed to pull notifications: $e');
    }
  }
}
