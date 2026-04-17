import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';

/// SharedPreferences key prefix for notification preferences (local cache).
const _prefKeyPrefix = 'notif_pref_';

/// All notification preference keys with their display labels and section.
const _preferences = <({String key, String label, String section})>[
  // Social
  (key: 'new_follower', label: 'New followers', section: 'Social'),
  (key: 'follow_request', label: 'Follow requests', section: 'Social'),
  (key: 'follow_accepted', label: 'Follow accepted', section: 'Social'),
  // Recipes
  (key: 'recipe_liked', label: 'Likes', section: 'Recipes'),
  (key: 'recipe_saved', label: 'Saves', section: 'Recipes'),
  (key: 'recipe_forked', label: 'Remixes', section: 'Recipes'),
  (key: 'recipe_shared', label: 'Shares', section: 'Recipes'),
  // Kitchen
  (
    key: 'schedule_suggestion',
    label: 'Schedule suggestions',
    section: 'Kitchen',
  ),
  (
    key: 'suggestion_approved',
    label: 'Suggestion approvals',
    section: 'Kitchen',
  ),
  (
    key: 'suggestion_denied',
    label: 'Suggestion declined',
    section: 'Kitchen',
  ),
  (
    key: 'kitchen_invite',
    label: 'Kitchen welcome & invites',
    section: 'Kitchen',
  ),
  (key: 'kitchen_joined', label: 'Member joins', section: 'Kitchen'),
  (key: 'kitchen_removed', label: 'Removals', section: 'Kitchen'),
  (key: 'system', label: 'Product updates', section: 'Other'),
];

/// Riverpod provider that loads notification preferences from the server,
/// falling back to local cache if the server request fails.
final _notifPrefsProvider =
    AsyncNotifierProvider<_NotifPrefsNotifier, Map<String, bool>>(
  _NotifPrefsNotifier.new,
);

class _NotifPrefsNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    // Try loading from server first
    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.get('/notifications/preferences');

      if (result.isSuccess && result.data != null) {
        final serverPrefs =
            result.data!['preferences'] as Map<String, dynamic>?;
        if (serverPrefs != null) {
          final prefs = <String, bool>{};
          for (final pref in _preferences) {
            prefs[pref.key] = serverPrefs[pref.key] as bool? ?? true;
          }
          // Cache locally
          _cacheLocally(prefs);
          return prefs;
        }
      }
    } catch (e) {
      developer.log(
        'Failed to load notification preferences from server, '
        'falling back to local cache: $e',
        name: 'NotifPrefs',
      );
    }

    // Fall back to local cache
    return _loadFromLocal();
  }

  Future<Map<String, bool>> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, bool>{};
    for (final pref in _preferences) {
      result[pref.key] = prefs.getBool('$_prefKeyPrefix${pref.key}') ?? true;
    }
    return result;
  }

  Future<void> _cacheLocally(Map<String, bool> prefs) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    for (final entry in prefs.entries) {
      await sharedPrefs.setBool('$_prefKeyPrefix${entry.key}', entry.value);
    }
  }

  Future<void> toggle(String key) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final newValue = !(current[key] ?? true);
    final updated = Map<String, bool>.from(current)..[key] = newValue;
    state = AsyncData(updated);

    // Save to local cache immediately
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setBool('$_prefKeyPrefix$key', newValue);

    // Sync to server
    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.patch(
        '/notifications/preferences',
        data: {key: newValue},
      );

      if (result.isFailure) {
        developer.log(
          'Failed to sync preference "$key" to server: ${result.error}',
          name: 'NotifPrefs',
        );
        // Revert optimistic update on failure
        final reverted = Map<String, bool>.from(updated)
          ..[key] = !newValue;
        state = AsyncData(reverted);
        await sharedPrefs.setBool('$_prefKeyPrefix$key', !newValue);
      }
    } catch (e) {
      developer.log(
        'Error syncing preference "$key" to server: $e',
        name: 'NotifPrefs',
      );
      // Revert optimistic update on error
      final reverted = Map<String, bool>.from(
        state.valueOrNull ?? current,
      )..[key] = !newValue;
      state = AsyncData(reverted);
      await sharedPrefs.setBool('$_prefKeyPrefix$key', !newValue);
    }
  }
}

/// Screen that lets the user toggle notification preferences.
///
/// Preferences are loaded from the server and synced back on every toggle.
/// Local [SharedPreferences] serve as a fallback cache.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(_notifPrefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: prefsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 28,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Failed to load preferences',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing6),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (prefs) => _PreferencesList(prefs: prefs),
      ),
    );
  }
}

class _PreferencesList extends ConsumerWidget {
  const _PreferencesList({required this.prefs});

  final Map<String, bool> prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group preferences by section.
    String? lastSection;
    final children = <Widget>[];

    for (int i = 0; i < _preferences.length; i++) {
      final pref = _preferences[i];

      if (pref.section != lastSection) {
        lastSection = pref.section;
        children.add(_SectionHeader(title: pref.section.toUpperCase()));
      }

      // Determine if this is the first item in its section group
      final isFirstInSection = i == 0 || _preferences[i - 1].section != pref.section;

      if (isFirstInSection) {
        // Start a new group
        final sectionItems = <Widget>[];

        // Collect all items for this section
        for (int j = i; j < _preferences.length && _preferences[j].section == pref.section; j++) {
          final sectionPref = _preferences[j];
          if (j > i) {
            sectionItems.add(
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacing16),
                child: Container(height: 1, color: AppTheme.gray100),
              ),
            );
          }
          sectionItems.add(
            _NotifToggleRow(
              label: sectionPref.label,
              value: prefs[sectionPref.key] ?? true,
              onChanged: (_) {
                ref.read(_notifPrefsProvider.notifier).toggle(sectionPref.key);
              },
            ),
          );
        }

        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.borderRadiusMedium,
                border: Border.all(color: AppTheme.gray200),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: sectionItems,
              ),
            ),
          ),
        );

        // Skip ahead past the items we just processed
        // (the outer loop will handle the increment)
      }

      if (!isFirstInSection) continue;
    }

    children.add(const SizedBox(height: AppTheme.spacing48));

    return ListView(children: children);
  }
}

// ── Notification Toggle Row ──────────────────────────────────────────────────

class _NotifToggleRow extends StatelessWidget {
  const _NotifToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.gray900,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacing20,
        right: AppTheme.spacing20,
        top: AppTheme.spacing32,
        bottom: AppTheme.spacing8,
      ),
      child: Text(
        title,
        style: context.textTheme.labelSmall?.copyWith(
          color: AppTheme.gray400,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
