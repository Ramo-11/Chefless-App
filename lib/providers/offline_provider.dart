import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';

/// Holds the last sync error message for UI display (null = no error).
final syncErrorProvider = StateProvider<String?>((ref) => null);

/// Provides the singleton [DatabaseService].
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

/// Provides a [CacheService] backed by the local database.
final cacheServiceProvider = Provider<CacheService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return CacheService(databaseService: db);
});

/// Provides a [SyncService] once the API service is ready.
///
/// Returns `null` if the user is not yet authenticated (API service
/// unavailable).
final syncServiceProvider = Provider<SyncService?>((ref) {
  final db = ref.watch(databaseServiceProvider);
  final apiServiceAsync = ref.watch(apiServiceProvider);
  final apiService = apiServiceAsync.valueOrNull;

  if (apiService == null) return null;

  return SyncService(apiService: apiService, databaseService: db);
});

/// Triggers a full sync whenever the user comes back online.
///
/// This provider is auto-disposed and should be watched from the app shell
/// to keep it alive while the app is running.
final syncTriggerProvider = Provider<void>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  final currentUser = ref.watch(currentUserProvider);

  if (isOnline) {
    final user = currentUser.valueOrNull;
    if (user != null) {
      // Perform sync asynchronously — don't block the provider.
      final apiServiceAsync = ref.read(apiServiceProvider);
      final apiService = apiServiceAsync.valueOrNull;
      if (apiService != null) {
        final db = ref.read(databaseServiceProvider);
        final syncService = SyncService(
          apiService: apiService,
          databaseService: db,
        );
        syncService.syncAll(user.id).catchError((Object e) {
          debugPrint('SyncTrigger: sync failed: $e');
          ref.read(syncErrorProvider.notifier).state = e.toString();
        });
      }
    }
  }
});
