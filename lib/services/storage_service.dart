import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// Typed wrapper around [SharedPreferences] for non-sensitive data and
/// [FlutterSecureStorage] for sensitive data (auth tokens, credentials).
class StorageService {
  StorageService._(this._prefs);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// Initializes the storage service. Must be called once before use.
  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final service = StorageService._(prefs);

    // One-time migration: move auth token from SharedPreferences to secure storage.
    final legacyToken = prefs.getString(StorageKeys.authToken);
    if (legacyToken != null) {
      await service._secure.write(key: StorageKeys.authToken, value: legacyToken);
      await prefs.remove(StorageKeys.authToken);
    }

    return service;
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

  // ── Auth Token (secure storage) ────────────────────────────────────────────

  Future<String?> getAuthToken() =>
      _secure.read(key: StorageKeys.authToken);

  Future<void> setAuthToken(String token) =>
      _secure.write(key: StorageKeys.authToken, value: token);

  Future<void> clearAuthToken() =>
      _secure.delete(key: StorageKeys.authToken);

  // ── Generic Accessors ──────────────────────────────────────────────────────

  String? getString(String key) => _prefs.getString(key);

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<bool> remove(String key) => _prefs.remove(key);

  Future<bool> clear() async {
    await _secure.deleteAll();
    return _prefs.clear();
  }
}
