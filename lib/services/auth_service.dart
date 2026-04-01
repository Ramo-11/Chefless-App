import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Encapsulates the result of an authentication operation.
class AuthResult {
  const AuthResult({required this.success, this.error});

  const AuthResult.ok() : success = true, error = null;

  const AuthResult.failed(String message)
      : success = false,
        error = message;

  final bool success;
  final String? error;
}

/// Manages Firebase Authentication for email/password, Google, and Apple
/// sign-in flows. Returns [AuthResult] from every operation so callers never
/// need to catch Firebase exceptions directly.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Stream of Firebase auth state changes (login / logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in Firebase user, if any.
  User? get currentUser => _auth.currentUser;

  /// Returns a fresh ID token for API calls, or `null` if not signed in.
  Future<String?> getIdToken() async {
    return _auth.currentUser?.getIdToken();
  }

  // ── Email / Password ─────────────────────────────────────────────────────

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failed(_friendlyMessage(e.code));
    }
  }

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(fullName.trim());
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failed(_friendlyMessage(e.code));
    }
  }

  // ── Google Sign-In ───────────────────────────────────────────────────────

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return const AuthResult.failed('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in FirebaseAuthException: ${e.code} – ${e.message}');
      return AuthResult.failed(_friendlyOAuthMessage(e.code, 'Google'));
    } catch (e) {
      debugPrint('Google sign-in unexpected error: $e');
      return const AuthResult.failed(
        'Google sign-in failed. Please try again.',
      );
    }
  }

  // ── Apple Sign-In ────────────────────────────────────────────────────────

  Future<AuthResult> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonceHash = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonceHash,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        debugPrint('Apple sign-in: identityToken was null');
        return const AuthResult.failed(
          'Apple sign-in failed. Please try again.',
        );
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Apple only provides the name on the first sign-in; persist it.
      final appleFullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((n) => n != null && n.isNotEmpty).join(' ');

      if (appleFullName.isNotEmpty &&
          (userCredential.user?.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        await userCredential.user?.updateDisplayName(appleFullName);
      }

      return const AuthResult.ok();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult.failed('Apple sign-in was cancelled.');
      }
      debugPrint('Apple sign-in authorization error: ${e.code} – ${e.message}');
      return const AuthResult.failed(
        'Apple sign-in failed. Please try again.',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Apple sign-in FirebaseAuthException: ${e.code} – ${e.message}');
      return AuthResult.failed(_friendlyOAuthMessage(e.code, 'Apple'));
    } catch (e) {
      debugPrint('Apple sign-in unexpected error: $e');
      return const AuthResult.failed(
        'Apple sign-in failed. Please try again.',
      );
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // ── Delete Firebase Auth Account ───────────────────────────────────────

  /// Deletes the current Firebase Auth user. If a recent login is required,
  /// automatically re-authenticates via the user's sign-in provider.
  /// For email/password users, [password] must be provided.
  Future<AuthResult> deleteFirebaseUser({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult.failed('No user signed in.');
    }

    try {
      await user.delete();
      await GoogleSignIn().signOut();
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        debugPrint('Firebase user deletion failed: ${e.code} – ${e.message}');
        return AuthResult.failed(_friendlyMessage(e.code));
      }
    }

    // Re-authenticate then retry deletion
    return _reauthenticateAndDelete(user, password: password);
  }

  Future<AuthResult> _reauthenticateAndDelete(
    User user, {
    String? password,
  }) async {
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    try {
      switch (providerId) {
        case 'apple.com':
          await _reauthWithApple(user);
        case 'google.com':
          await _reauthWithGoogle(user);
        case 'password':
          if (password == null || password.isEmpty) {
            return const AuthResult.failed('requires-password');
          }
          await _reauthWithEmail(user, password);
        default:
          return const AuthResult.failed(
            'Unable to verify your identity. Please sign out and back in, '
            'then try again.',
          );
      }

      await user.delete();
      await GoogleSignIn().signOut();
      return const AuthResult.ok();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthResult.failed('Verification cancelled.');
      }
      debugPrint('Apple re-auth failed: ${e.code} – ${e.message}');
      return const AuthResult.failed(
        'Apple verification failed. Please try again.',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Re-auth + delete failed: ${e.code} – ${e.message}');
      return AuthResult.failed(_friendlyOAuthMessage(e.code, providerId));
    } catch (e) {
      debugPrint('Re-auth unexpected error: $e');
      return const AuthResult.failed(
        'Verification failed. Please try again.',
      );
    }
  }

  Future<void> _reauthWithApple(User user) async {
    final rawNonce = _generateNonce();
    final nonceHash = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonceHash,
    );

    final identityToken = appleCredential.identityToken;
    if (identityToken == null) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'No identity token from Apple.',
      );
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    await user.reauthenticateWithCredential(oauthCredential);
  }

  Future<void> _reauthWithGoogle(User user) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'user-cancelled',
        message: 'Google re-authentication was cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _reauthWithEmail(User user, String password) async {
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  // ── Change Password ──────────────────────────────────────────────────────

  /// Changes the current user's password. Requires re-authentication with
  /// the [currentPassword] first. Only works for email/password users.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthResult.failed('No user signed in.');
    }
    if (user.email == null) {
      return const AuthResult.failed('No email associated with this account.');
    }

    try {
      // Re-authenticate first (Firebase requires recent login for password change).
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Now update the password.
      await user.updatePassword(newPassword);
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failed(_friendlyMessage(e.code));
    }
  }

  // ── Password Reset ───────────────────────────────────────────────────────

  Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failed(_friendlyMessage(e.code));
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Generates a cryptographically-secure random nonce for Apple Sign-In.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Maps Firebase error codes to user-friendly messages for OAuth flows
  /// (Apple / Google), where generic codes like `invalid-credential` need
  /// provider-specific wording instead of "Invalid email or password".
  static String _friendlyOAuthMessage(String code, String provider) {
    switch (code) {
      case 'invalid-credential':
        return '$provider sign-in failed. Please try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return '$provider sign-in is not enabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return '$provider sign-in failed. Please try again.';
    }
  }

  /// Maps Firebase error codes to user-friendly messages.
  @visibleForTesting
  static String friendlyMessage(String code) => _friendlyMessage(code);

  static String _friendlyMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
