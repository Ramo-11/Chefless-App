import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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
/// ID token into every request.
final apiServiceProvider = FutureProvider<ApiService>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final token = await authService.getIdToken();
  final apiService = ApiService(authToken: token);
  return apiService;
});

/// Fetches the current user's Chefless profile from the API.
///
/// Returns `null` if the user is not authenticated or the API call fails.
final currentUserProvider = FutureProvider<CheflessUser?>((ref) async {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (firebaseUser) async {
      if (firebaseUser == null) return null;

      final apiService = await ref.watch(apiServiceProvider.future);
      final result = await apiService.get('/auth/me');

      if (result.isSuccess && result.data != null) {
        final userData = result.data!['user'];
        if (userData is Map<String, dynamic>) {
          return CheflessUser.fromJson(userData);
        }
      }
      return null;
    },
    loading: () => null,
    error: (_, _) => null,
  );
});
