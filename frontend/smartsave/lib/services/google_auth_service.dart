import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Production-grade Google Authentication Service.
///
/// Wraps [GoogleSignIn] and [FirebaseAuth] into a single cohesive service
/// with enterprise-grade error handling, platform-specific initialization,
/// multi-account support, and graceful degradation when Firebase or
/// Google Play Services are unavailable.
///
/// ## Architecture
/// This service is registered as a lazy singleton via [GetIt] in
/// [setupServiceLocator]. AuthProvider depends on it through
/// constructor injection (optional — falls back to direct instantiation).
///
/// ## Security
/// - Never logs tokens, credentials, or user PII
/// - Uses Firebase Auth under the hood for secure token management
/// - Google Sign-In tokens are exchanged for Firebase credentials immediately
/// - ID tokens are obtained with forced refresh to prevent stale token usage
class GoogleAuthService {
  GoogleSignIn? _googleSignIn;
  FirebaseAuth? _firebaseAuth;
  bool _isAvailable = false;
  bool _initialized = false;

  /// Whether Google Sign-In is available (Firebase configured, platform OK).
  bool get isAvailable => _isAvailable;

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// The current Firebase user, if any.
  User? get currentFirebaseUser => _firebaseAuth?.currentUser;

  /// The underlying [FirebaseAuth] instance (null if unavailable).
  FirebaseAuth? get firebaseAuth => _firebaseAuth;

  /// Initializes Google Sign-In and Firebase Auth.
  ///
  /// Must be called once during app startup. Safe to call multiple times —
  /// subsequent calls are no-ops.
  ///
  /// If Firebase is not configured (e.g., missing google-services.json),
  /// the service degrades gracefully: [isAvailable] returns false and
  /// sign-in attempts return null instead of crashing.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _googleSignIn = GoogleSignIn(
        scopes: <String>[
          'email',
          'profile',
          // OpenID scopes are included by default — no need for 'openid'
        ],
      );

      _firebaseAuth = FirebaseAuth.instance;
      _isAvailable = true;
    } catch (e) {
      // Firebase or Google Sign-In is not configured.
      // This is expected if google-services.json / GoogleService-Info.plist
      // are missing. Gracefully degrade.
      _isAvailable = false;
      debugPrint('[GoogleAuthService] Not available: $e');
    }
  }

  /// Signs in the user with Google and Firebase Authentication.
  ///
  /// Flow:
  /// 1. Google Sign-In SDK presents the account picker
  /// 2. User selects a Google account
  /// 3. Google returns an authentication credential
  /// 4. Credential is exchanged for a Firebase Auth credential
  /// 5. Firebase Auth signs in, returning a [UserCredential]
  /// 6. The Firebase ID token can be obtained via [getIdToken]
  ///
  /// Returns the [UserCredential] on success, or null on failure/cancellation.
  ///
  /// ## Error handling
  /// - User cancellation → returns null (not an error)
  /// - Network loss → returns null, caller sets appropriate error message
  /// - Firebase not configured → returns null
  /// - Platform exceptions → caught and returned as null
  Future<UserCredential?> signIn() async {
    if (!_isAvailable) return null;

    try {
      // ── Step 1: Sign in with Google ──
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      // User cancelled the flow
      if (googleUser == null) return null;

      // ── Step 2: Get Google authentication details ──
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        debugPrint('[GoogleAuthService] No ID token from Google');
        return null;
      }

      // ── Step 3: Exchange Google credential for Firebase credential ──
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // ── Step 4: Sign in to Firebase ──
      final UserCredential userCredential =
          await _firebaseAuth!.signInWithCredential(credential);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Firebase auth errors — log without PII
      debugPrint('[GoogleAuthService] Firebase auth error: ${e.code}');
      return null;
    } on FirebaseException catch (e) {
      // General Firebase errors (network, etc.)
      debugPrint('[GoogleAuthService] Firebase error: ${e.code}');
      return null;
    } catch (e) {
      // Platform exceptions (e.g., Google Play Services missing on Android)
      debugPrint('[GoogleAuthService] Sign-in error: ${e.runtimeType}');
      return null;
    }
  }

  /// Signs out of both Google and Firebase Authentication.
  ///
  /// This:
  /// 1. Signs out of Firebase Auth
  /// 2. Signs out of Google Sign-In (disconnects the account)
  ///
  /// Safe to call multiple times. Never throws.
  Future<void> signOut() async {
    try {
      // Sign out of Firebase first
      if (_firebaseAuth != null) {
        await _firebaseAuth!.signOut();
      }

      // Then sign out of Google
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
    } catch (e) {
      // Sign-out should never fail — eat the exception
      debugPrint('[GoogleAuthService] Sign-out error: ${e.runtimeType}');
    }
  }

  /// Revokes Google account access (disconnects the account entirely).
  ///
  /// Unlike [signOut], this disconnects the Google account so the user
  /// must re-authenticate with Google on their next sign-in attempt.
  /// Useful for account switching.
  ///
  /// Safe to call multiple times. Never throws.
  Future<void> revokeAccess() async {
    try {
      if (_firebaseAuth != null) {
        await _firebaseAuth!.signOut();
      }
      if (_googleSignIn != null) {
        await _googleSignIn!.disconnect();
      }
    } catch (e) {
      debugPrint('[GoogleAuthService] Revoke error: ${e.runtimeType}');
    }
  }

  /// Gets a fresh Firebase ID token for the currently signed-in user.
  ///
  /// The [forceRefresh] parameter (default true) ensures a fresh token
  /// is always obtained — never reuse a potentially expired token.
  ///
  /// Returns the ID token as a [String], or null if no user is signed in
  /// or token retrieval fails.
  Future<String?> getIdToken({bool forceRefresh = true}) async {
    try {
      final User? user = _firebaseAuth?.currentUser;
      if (user == null) return null;

      final IdTokenResult idTokenResult = await user.getIdTokenResult(forceRefresh);
      return idTokenResult.token;
    } catch (e) {
      debugPrint('[GoogleAuthService] Token error: ${e.runtimeType}');
      return null;
    }
  }

  /// Checks if a user is currently signed in to Firebase.
  bool get isSignedIn => _firebaseAuth?.currentUser != null;

  /// Returns the email of the currently signed-in user, or null.
  String? get userEmail => _firebaseAuth?.currentUser?.email;

  /// Returns the display name of the currently signed-in user, or null.
  String? get userDisplayName => _firebaseAuth?.currentUser?.displayName;

  /// Returns the photo URL of the currently signed-in user, or null.
  String? get userPhotoUrl => _firebaseAuth?.currentUser?.photoURL;

  /// Attempts to silently restore the previous Google sign-in session.
  ///
  /// This checks if a user was previously signed in to Firebase and
  /// automatically restores their session. This works even when offline
  /// because Firebase caches the auth state locally.
  ///
  /// Returns a [UserCredential] if a session was restored, or null.
  Future<UserCredential?> trySilentSignIn() async {
    if (!_isAvailable) return null;

    try {
      // Check if Firebase has a cached user
      final User? currentUser = _firebaseAuth?.currentUser;
      if (currentUser != null) {
        // User is already signed in to Firebase — session restored
        return null; // No new credential needed, user is already authenticated
      }

      // Try to silently sign in with Google (restores previous Google session)
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signInSilently();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) return null;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth!.signInWithCredential(credential);

      return userCredential;
    } catch (e) {
      // Silent sign-in often fails (e.g., no cached session) — this is normal
      debugPrint('[GoogleAuthService] Silent sign-in: ${e.runtimeType}');
      return null;
    }
  }
}
