import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

/// Provides the singleton [AuthService] instance.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Streams Firebase auth state changes (sign-in / sign-out).
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provides an [ApiService] that automatically injects the current Firebase
/// ID token into every request. Re-evaluates when auth state changes
/// (sign-out / sign-in with different account) so the token stays fresh.
final apiServiceProvider = FutureProvider<ApiService>((ref) async {
  // Watch auth state so this re-evaluates on sign-in/sign-out.
  await ref.watch(authStateProvider.future);
  final authService = ref.read(authServiceProvider);
  final token = await authService.getIdToken();
  return ApiService(
    authToken: token,
    authTokenProvider: ({bool forceRefresh = false}) {
      return authService.getIdToken(forceRefresh: forceRefresh);
    },
  );
});

/// Fetches the current user's Chefless profile from the API.
///
/// Returns `null` if the user is not authenticated or the API call fails.
/// Stays in [AsyncLoading] until Firebase auth resolves, so the router
/// doesn't prematurely redirect to onboarding.
final currentUserProvider = FutureProvider<CheflessUser?>((ref) async {
  // Await auth — keeps this provider in AsyncLoading until Firebase resolves.
  final firebaseUser = await ref.watch(authStateProvider.future);
  if (firebaseUser == null) return null;

  assert(() {
    debugPrint('[currentUserProvider] Firebase user: ${firebaseUser.email}');
    return true;
  }());

  final apiService = await ref.watch(apiServiceProvider.future);
  final result = await apiService.get('/auth/me');

  if (result.isSuccess && result.data != null) {
    final userData = result.data!['user'];
    if (userData is Map<String, dynamic>) {
      final user = CheflessUser.fromJson(userData);
      assert(() {
        debugPrint('[currentUserProvider] Profile loaded: ${user.fullName}');
        return true;
      }());
      return user;
    }
  }

  // 404 means the user hasn't registered yet — not a connection error.
  if (result.statusCode == 404) {
    assert(() {
      debugPrint('[currentUserProvider] User not registered yet (404)');
      return true;
    }());
    return null;
  }

  // Any other failure (timeout, connection refused, 500, etc.) is a real error.
  final errorMsg = result.error ?? 'Failed to connect to server';
  assert(() {
    debugPrint('[currentUserProvider] API error: $errorMsg');
    return true;
  }());
  throw Exception(errorMsg);
});

/// Initializes FCM when the user is authenticated. Call this provider once
/// from a top-level widget (e.g., [AppShell]) to register the FCM token
/// and start listening for push notifications.
final fcmInitProvider = FutureProvider<void>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return;

  final apiService = await ref.read(apiServiceProvider.future);
  final fcmService = FcmService(apiService: apiService);
  await fcmService.initialize();
});
