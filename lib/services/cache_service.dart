import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'database_service.dart';

/// A lightweight cache-first data access layer.
///
/// When online, fetches data from the API via [fetchFn], caches the result
/// in SQLite, and returns it. When offline (or if the fetch fails), returns
/// the cached version. Returns `null` if the cache is empty and the device
/// is offline.
class CacheService {
  const CacheService({required this.databaseService});

  final DatabaseService databaseService;

  /// Fetches a single item with cache-first semantics.
  ///
  /// - [table] / [id]: SQLite lookup coordinates.
  /// - [fetchFn]: async function that hits the API and returns raw JSON.
  /// - [isOnline]: current connectivity state.
  Future<Map<String, dynamic>?> getCachedOrFetch({
    required String table,
    required String id,
    required Future<Map<String, dynamic>?> Function() fetchFn,
    required bool isOnline,
    Map<String, String>? extraColumns,
  }) async {
    if (isOnline) {
      try {
        final data = await fetchFn();
        if (data != null) {
          await databaseService.upsert(table, id, data,
              extraColumns: extraColumns);
          return data;
        }
      } catch (e) {
        debugPrint('CacheService: fetch failed, falling back to cache: $e');
      }
    }

    // Offline or fetch failed — try cache.
    return databaseService.getById(table, id);
  }

  /// Fetches a list of items with cache-first semantics.
  ///
  /// - [table]: SQLite table to cache into / read from.
  /// - [fetchFn]: returns a list of JSON maps from the API.
  /// - [idExtractor]: pulls the unique ID from each JSON map.
  /// - [isOnline]: current connectivity state.
  /// - [clearBeforeCache]: if `true`, clears the table before inserting
  ///   fresh data (useful for full-replacement syncs like "my recipes").
  Future<List<Map<String, dynamic>>> getCachedListOrFetch({
    required String table,
    required Future<List<Map<String, dynamic>>> Function() fetchFn,
    required String Function(Map<String, dynamic>) idExtractor,
    required bool isOnline,
    bool clearBeforeCache = false,
    Map<String, String> Function(Map<String, dynamic>)? extraColumnsBuilder,
  }) async {
    if (isOnline) {
      try {
        final items = await fetchFn();
        if (clearBeforeCache) {
          await databaseService.clear(table);
        }
        for (final item in items) {
          final id = idExtractor(item);
          await databaseService.upsert(
            table,
            id,
            item,
            extraColumns: extraColumnsBuilder?.call(item),
          );
        }
        return items;
      } catch (e) {
        debugPrint(
            'CacheService: list fetch failed, falling back to cache: $e');
      }
    }

    // Offline or fetch failed — return whatever is cached.
    return databaseService.getAll(table);
  }

  /// Queues a mutation for offline sync and optionally caches the optimistic
  /// result locally.
  ///
  /// Call this instead of hitting the API directly when offline.
  Future<void> queueOfflineMutation({
    required String action,
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    String? cacheTable,
    String? cacheId,
    Map<String, dynamic>? optimisticData,
    Map<String, String>? extraColumns,
  }) async {
    await databaseService.addToQueue(
      action: action,
      endpoint: endpoint,
      method: method,
      body: body,
    );

    // Store an optimistic local copy so the UI reflects the change
    // immediately, even before sync.
    if (cacheTable != null && cacheId != null && optimisticData != null) {
      await databaseService.upsert(
        cacheTable,
        cacheId,
        optimisticData,
        extraColumns: extraColumns,
      );
    }
  }

  /// Serializes a value to a JSON-encodable string for storage.
  static String encode(Object value) => jsonEncode(value);

  /// Deserializes a JSON string back to a dynamic value.
  static Object? decode(String source) => jsonDecode(source);
}
