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

    developer.log(
      'Notification permission: ${settings.authorizationStatus}',
      name: 'FcmService',
    );

    // Get the current FCM token and register with the server
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (e) {
      developer.log(
        'Failed to get FCM token: $e',
        name: 'FcmService',
      );
    }

    // Listen for token refreshes (e.g., app restore, manual deletion)
    messaging.onTokenRefresh.listen((newToken) {
      _registerToken(newToken);
    });

    // Handle foreground messages — log them so the notification provider
    // can refresh. Push banners are handled by the OS only when the app is
    // backgrounded; in the foreground we rely on the in-app notification feed.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log(
        'Foreground FCM: ${message.notification?.title} — '
        '${message.notification?.body}',
        name: 'FcmService',
      );
      // The notification feed auto-refreshes via Riverpod, so we just log here.
      // If you want to show a local notification banner in the foreground, add
      // flutter_local_notifications and display it here.
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
