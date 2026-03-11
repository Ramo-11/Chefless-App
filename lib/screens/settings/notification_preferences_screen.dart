import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/extensions.dart';

/// SharedPreferences key prefix for notification preferences.
const _prefKeyPrefix = 'notif_pref_';

/// All notification preference keys with their display labels and section.
const _preferences = <({String key, String label, String section})>[
  // Social
  (key: 'new_follower', label: 'New followers', section: 'Social'),
  (key: 'follow_request', label: 'Follow requests', section: 'Social'),
  (key: 'follow_accepted', label: 'Follow accepted', section: 'Social'),
  // Recipes
  (key: 'recipe_liked', label: 'Likes', section: 'Recipes'),
  (key: 'recipe_forked', label: 'Forks', section: 'Recipes'),
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
  (key: 'kitchen_joined', label: 'Member joins', section: 'Kitchen'),
  (key: 'kitchen_removed', label: 'Removals', section: 'Kitchen'),
];

/// Riverpod provider that loads and manages notification preferences from
/// [SharedPreferences].
final _notifPrefsProvider =
    AsyncNotifierProvider<_NotifPrefsNotifier, Map<String, bool>>(
  _NotifPrefsNotifier.new,
);

class _NotifPrefsNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, bool>{};
    for (final pref in _preferences) {
      result[pref.key] = prefs.getBool('$_prefKeyPrefix${pref.key}') ?? true;
    }
    return result;
  }

  Future<void> toggle(String key) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final newValue = !(current[key] ?? true);
    final updated = {...current, key: newValue};
    state = AsyncData(updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefKeyPrefix$key', newValue);
  }
}

/// Screen that lets the user toggle notification preferences.
///
/// Preferences are grouped by category (Social, Recipes, Kitchen) and
/// stored locally via [SharedPreferences]. The API will handle server-side
/// preference enforcement in a future phase.
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(_notifPrefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: prefsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Text(
              'Failed to load preferences.\n$error',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.error,
              ),
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

    for (final pref in _preferences) {
      if (pref.section != lastSection) {
        lastSection = pref.section;
        children.add(
          _SectionHeader(title: pref.section),
        );
      }

      children.add(
        SwitchListTile(
          title: Text(pref.label),
          value: prefs[pref.key] ?? true,
          onChanged: (_) {
            ref.read(_notifPrefsProvider.notifier).toggle(pref.key);
          },
        ),
      );
    }

    children.add(const SizedBox(height: AppTheme.spacingXl));

    return ListView(children: children);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingMd,
        right: AppTheme.spacingMd,
        top: AppTheme.spacingLg,
        bottom: AppTheme.spacingSm,
      ),
      child: Text(
        title,
        style: context.textTheme.labelLarge?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
