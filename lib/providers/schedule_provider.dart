import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule_entry.dart';
import 'auth_provider.dart';

/// Parameters for fetching a week of schedule entries.
class WeekScheduleParams {
  const WeekScheduleParams({required this.weekStart});

  final DateTime weekStart;

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeekScheduleParams &&
          other.weekStart.year == weekStart.year &&
          other.weekStart.month == weekStart.month &&
          other.weekStart.day == weekStart.day;

  @override
  int get hashCode =>
      Object.hash(weekStart.year, weekStart.month, weekStart.day);
}

/// Fetches schedule entries for a given week.
final weekScheduleProvider = FutureProvider.family<List<ScheduleEntry>,
    WeekScheduleParams>((ref, params) async {
  final apiService = await ref.watch(apiServiceProvider.future);

  final result = await apiService.get(
    '/schedule',
    queryParameters: {
      'start': params.weekStart.toIso8601String().split('T').first,
      'end': params.weekEnd.toIso8601String().split('T').first,
    },
  );

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load schedule.');
  }

  final entries = (result.data!['suggestions'] ??
          result.data!['entries']) as List<dynamic>? ??
      [];
  return entries
      .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches pending suggestions for the current kitchen (lead/approvers only).
final suggestionsProvider =
    FutureProvider<List<ScheduleEntry>>((ref) async {
  final apiService = await ref.watch(apiServiceProvider.future);

  final result = await apiService.get('/schedule/suggestions');

  if (result.isFailure || result.data == null) {
    throw Exception(result.error ?? 'Failed to load suggestions.');
  }

  final entries = result.data!['entries'] as List<dynamic>? ?? [];
  return entries
      .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Handles schedule create, update, delete, approve, and deny actions.
class ScheduleActionNotifier extends StateNotifier<AsyncValue<void>> {
  ScheduleActionNotifier(this._ref) : super(const AsyncData<void>(null));

  final Ref _ref;

  Future<bool> addEntry({
    required String date,
    required String mealSlot,
    String? recipeId,
    String? freeformText,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final data = <String, dynamic>{
        'date': date,
        'mealSlot': mealSlot,
      };
      if (recipeId != null) {
        data['recipeId'] = recipeId;
      }
      if (freeformText != null) {
        data['freeformText'] = freeformText;
      }

      final result = await apiService.post('/schedule', data: data);
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to add schedule entry.');
      }
      _invalidateSchedule();
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> updateEntry(
    String entryId,
    Map<String, dynamic> data,
  ) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.put('/schedule/$entryId', data: data);
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to update schedule entry.');
      }
      _invalidateSchedule();
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> deleteEntry(String entryId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.delete('/schedule/$entryId');
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to delete schedule entry.');
      }
      _invalidateSchedule();
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> approveSuggestion(String entryId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/schedule/suggestions/$entryId/approve',
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to approve suggestion.');
      }
      _invalidateSchedule();
      _ref.invalidate(suggestionsProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  Future<bool> denySuggestion(String entryId) async {
    state = const AsyncLoading<void>();
    try {
      final apiService = await _ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/schedule/suggestions/$entryId/deny',
      );
      if (result.isFailure) {
        throw Exception(result.error ?? 'Failed to deny suggestion.');
      }
      _ref.invalidate(suggestionsProvider);
      state = const AsyncData<void>(null);
      return true;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      return false;
    }
  }

  /// Invalidates all cached week schedules by clearing the family provider
  /// for common weeks (current and surrounding).
  void _invalidateSchedule() {
    // Invalidate a range of weeks around now so any cached week refreshes.
    final now = DateTime.now();
    for (var offset = -2; offset <= 4; offset++) {
      final day = now.add(Duration(days: offset * 7));
      final weekStart = day.subtract(Duration(days: day.weekday - 1));
      final normalized = DateTime(weekStart.year, weekStart.month, weekStart.day);
      _ref.invalidate(
        weekScheduleProvider(WeekScheduleParams(weekStart: normalized)),
      );
    }
  }
}

final scheduleActionProvider =
    StateNotifierProvider<ScheduleActionNotifier, AsyncValue<void>>((ref) {
  return ScheduleActionNotifier(ref);
});
