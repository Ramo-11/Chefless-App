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
      return AuthResult.failed(_friendlyMessage(e.code));
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

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
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
      return AuthResult.failed('Apple sign-in failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failed(_friendlyMessage(e.code));
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
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
