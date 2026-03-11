/// App-wide constants for the Chefless application.
class AppConstants {
  AppConstants._();

  static const String appName = 'Chefless';

  static const String apiBaseUrl = 'http://localhost:3001/api';

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const int maxImageSizeMb = 10;
  static const int maxRecipePhotos = 5;
}

/// RevenueCat configuration constants.
class RevenueCatConstants {
  RevenueCatConstants._();

  // Replace with actual RevenueCat API key before release.
  static const String apiKey = 'REVENUECAT_API_KEY_PLACEHOLDER';

  static const String premiumEntitlementId = 'premium';
}

/// SharedPreferences key constants.
class StorageKeys {
  StorageKeys._();

  static const String darkMode = 'dark_mode';
  static const String onboardingComplete = 'onboarding_complete';
  static const String authToken = 'auth_token';
}
