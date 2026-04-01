/// App-wide constants for the Chefless application.
class AppConstants {
  AppConstants._();

  static const String appName = 'Chefless';

  /// Set to false before releasing to production. See DEPLOY_CHECKLIST.md.
  static const bool debugMode = false;

  /// Set to true to use the local API server instead of Render.
  /// Update [_localIp] to your Mac's current local IP address.
  /// Find it with: `ifconfig | grep "inet " | grep -v 127.0.0.1`
  static const bool useLocalApi = false;
  static const String _defaultLocalIp = '192.168.200.32';
  static const int _localPort = 3000;

  static const String _prodApiUrl = 'https://chefless-web.onrender.com/api';

  /// Mutable override for local dev. Set via the connection error screen.
  static String? _apiBaseUrlOverride;

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride != null) return _apiBaseUrlOverride!;
    if (useLocalApi) return 'http://$_defaultLocalIp:$_localPort/api';
    return _prodApiUrl;
  }

  static set apiBaseUrl(String url) => _apiBaseUrlOverride = url;

  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const int maxImageSizeMb = 10;
  static const int maxRecipePhotos = 5;
}

/// RevenueCat configuration constants.
class RevenueCatConstants {
  RevenueCatConstants._();

  static const String apiKey = 'appl_fbxHjPWVTlaiiZrEvpEifpbPEze';

  static const String premiumEntitlementId = 'Chefless Pro';

  static bool get isConfigured => apiKey.isNotEmpty;
}

/// SharedPreferences key constants.
class StorageKeys {
  StorageKeys._();

  static const String darkMode = 'dark_mode';
  static const String onboardingComplete = 'onboarding_complete';
  static const String authToken = 'auth_token';
}
