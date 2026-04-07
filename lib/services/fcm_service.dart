import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Handles Firebase Cloud Messaging: permission requests, token management,
/// and foreground message handling.
class FcmService {
  FcmService({required this.apiService});

  final ApiService apiService;
  String? _currentToken;
  static bool _foregroundListenerAttached = false;
  static bool _tokenRefreshListenerAttached = false;

  /// Stream of foreground push messages, exposed as a static getter so
  /// Riverpod providers can subscribe without needing an FcmService instance.
  static Stream<RemoteMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage;

  /// Initializes FCM: requests permission, retrieves the token, registers it
  /// with the API, and sets up listeners for token refresh and foreground
  /// messages.
  Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Request notification permission (required on iOS, optional on Android 13+)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      developer.log(
        'User denied notification permissions',
        name: 'FcmService',
      );
      return;
    }

    // iOS requires explicit foreground presentation options for alerts/sound/badge.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get the current FCM token and register with the server.
    // On iOS, APNs registration can lag behind app startup, so a single early
    // getToken() call may return null and leave the device unregistered.
    try {
      final token = await _obtainReadyToken(messaging);
      if (token != null) {
        await _registerToken(token);
      } else {
        developer.log(
          'FCM token unavailable after retries; device not registered yet.',
          name: 'FcmService',
        );
        _retryTokenRegistrationLater(messaging);
      }
    } catch (e) {
      developer.log(
        'Failed to get FCM token: $e',
        name: 'FcmService',
      );
    }

    // Listen for token refreshes (e.g., app restore, manual deletion).
    if (!_tokenRefreshListenerAttached) {
      _tokenRefreshListenerAttached = true;
      messaging.onTokenRefresh.listen((newToken) {
        _registerToken(newToken);
      });
    }

    // Handle foreground messages — log them so the notification provider
    // can refresh. Push banners are handled by the OS only when the app is
    // backgrounded; in the foreground we rely on the in-app notification feed.
    if (!_foregroundListenerAttached) {
      _foregroundListenerAttached = true;
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log(
          'Foreground FCM: ${message.notification?.title} — '
          '${message.notification?.body}',
          name: 'FcmService',
        );
      });
    }
  }

  Future<String?> _obtainReadyToken(FirebaseMessaging messaging) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      for (var attempt = 0; attempt < 6; attempt++) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }

    for (var attempt = 0; attempt < 4; attempt++) {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    return null;
  }

  void _retryTokenRegistrationLater(FirebaseMessaging messaging) {
    Future<void>.delayed(const Duration(seconds: 5), () async {
      try {
        final token = await _obtainReadyToken(messaging);
        if (token != null) {
          await _registerToken(token);
        }
      } catch (e) {
        developer.log(
          'Delayed FCM token retry failed: $e',
          name: 'FcmService',
        );
      }
    });
  }

  /// Registers (or updates) the FCM token with the API server.
  Future<void> _registerToken(String token) async {
    if (token == _currentToken) return;

    try {
      final result = await apiService.post(
        '/auth/fcm-token',
        data: {'token': token},
      );

      if (result.isSuccess) {
        _currentToken = token;
        debugPrint('[FcmService] FCM token registered successfully');
      } else {
        developer.log(
          'Failed to register FCM token: ${result.error}',
          name: 'FcmService',
        );
      }
    } catch (e) {
      developer.log(
        'Error registering FCM token: $e',
        name: 'FcmService',
      );
    }
  }

  /// Clears the FCM token from the server (call on sign-out).
  Future<void> clearToken() async {
    _currentToken = null;
    try {
      await apiService.delete('/auth/fcm-token');
    } catch (e) {
      developer.log(
        'Error clearing FCM token: $e',
        name: 'FcmService',
      );
    }
  }
}
