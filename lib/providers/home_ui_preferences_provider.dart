import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Whether the user chose to hide the “set up your kitchen” card on Home.
final homeNoKitchenPromptDismissedProvider =
    AsyncNotifierProvider<HomeNoKitchenPromptDismissedNotifier, bool>(
  HomeNoKitchenPromptDismissedNotifier.new,
);

class HomeNoKitchenPromptDismissedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.homeNoKitchenPromptDismissed) ?? false;
  }

  Future<void> dismiss() async {
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.homeNoKitchenPromptDismissed, true);
  }
}
