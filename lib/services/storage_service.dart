import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Typed wrapper around [SharedPreferences] for persistent local storage.
class StorageService {
  StorageService._(this._prefs);

  final SharedPreferences _prefs;

  /// Initializes the storage service. Must be called once before use.
  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  // ── Dark Mode ──────────────────────────────────────────────────────────────

  bool get isDarkMode => _prefs.getBool(StorageKeys.darkMode) ?? false;

  Future<bool> setDarkMode({required bool enabled}) =>
      _prefs.setBool(StorageKeys.darkMode, enabled);

  // ── Onboarding ─────────────────────────────────────────────────────────────

  bool get isOnboardingComplete =>
      _prefs.getBool(StorageKeys.onboardingComplete) ?? false;

  Future<bool> setOnboardingComplete({required bool complete}) =>
      _prefs.setBool(StorageKeys.onboardingComplete, complete);

  // ── Auth Token ─────────────────────────────────────────────────────────────

  String? get authToken => _prefs.getString(StorageKeys.authToken);

  Future<bool> setAuthToken(String token) =>
      _prefs.setString(StorageKeys.authToken, token);

  Future<bool> clearAuthToken() => _prefs.remove(StorageKeys.authToken);

  // ── Generic Accessors ──────────────────────────────────────────────────────

  String? getString(String key) => _prefs.getString(key);

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<bool> remove(String key) => _prefs.remove(key);

  Future<bool> clear() => _prefs.clear();
}
