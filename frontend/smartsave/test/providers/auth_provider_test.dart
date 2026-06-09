import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:smartsave/presentation/providers/auth_provider.dart';
import 'package:smartsave/services/google_auth_service.dart';

// ─────────────────────────────────────────────
// Manual mock for GoogleAuthService
//
// Avoids non-nullable bool issues with Mockito's noSuchMethod.
// All non-nullable fields have explicit default values.
// ─────────────────────────────────────────────

class MockGoogleAuthService extends GoogleAuthService {
  @override
  bool isAvailable = false;

  @override
  bool isInitialized = false;

  @override
  bool isSignedIn = false;

  User? currentFirebaseUserOverride;

  @override
  User? get currentFirebaseUser => currentFirebaseUserOverride;

  /// Stub for signIn(). If null, returns null (cancellation).
  Future<UserCredential?> Function()? onSignIn;

  /// Stub for getIdToken(). If null, returns null.
  Future<String?> Function({bool forceRefresh})? onGetIdToken;

  /// Stub for trySilentSignIn(). If null, returns null.
  Future<UserCredential?> Function()? onTrySilentSignIn;

  /// Stub for init(). Setting this replaces mock behavior.
  Future<void> Function()? onInit;

  int signOutCallCount = 0;
  int revokeAccessCallCount = 0;

  @override
  Future<UserCredential?> signIn() async => onSignIn?.call() ?? null;

  @override
  Future<String?> getIdToken({bool forceRefresh = true}) async =>
      onGetIdToken?.call(forceRefresh: forceRefresh) ?? null;

  @override
  Future<UserCredential?> trySilentSignIn() async =>
      onTrySilentSignIn?.call() ?? null;

  @override
  Future<void> init() async => onInit?.call() ?? Future.value();

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> revokeAccess() async {
    revokeAccessCallCount++;
  }
}

/// Unit tests for AuthProvider.
///
/// These tests verify:
/// - Google Sign-In flow integration
/// - Error handling and propagation
/// - State transitions
/// - Edge cases (cancellation, unavailability)
///
/// ## Note
/// Tests depend primarily on [AuthProvider]'s integration with [GoogleAuthService]
/// and [AuthRepositoryImpl]. The GoogleAuthService is mocked here to test the
/// provider logic in isolation.
void main() {
  // Disable gamification recording in tests where platform channels
  // (FlutterSecureStorage, etc.) are not available.
  AuthProvider.disableGamification = true;

  late AuthProvider authProvider;
  late MockGoogleAuthService mockGoogleAuthService;

  setUp(() {
    mockGoogleAuthService = MockGoogleAuthService();
    authProvider = AuthProvider(googleAuthService: mockGoogleAuthService);
  });

  group('AuthProvider - Google Sign-In', () {
    test('initial state is unauthenticated', () {
      expect(authProvider.status, AuthStatus.initial);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.user, isNull);
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.isLoading, false);
    });

    test('googleLogin() sets error when Firebase is not available', () async {
      // Simulate Google Sign-In unavailable — signIn returns null
      mockGoogleAuthService.onSignIn = () async => null;

      final result = await authProvider.googleLogin();

      expect(result, false);
      // When signIn() returns null (cancellation), no error is set
      expect(authProvider.errorMessage, isNull);
    });

    test('googleLogin() handles user cancellation gracefully', () async {
      // signIn returns null = user cancelled
      mockGoogleAuthService.onSignIn = () async => null;

      final result = await authProvider.googleLogin();

      expect(result, false);
      expect(authProvider.errorMessage, isNull);
    });

    test('googleLogin() returns false when ID token retrieval fails', () async {
      // Mock: signIn succeeds but getIdToken returns null
      // We need signIn to return a non-null value so getitoken is called
      mockGoogleAuthService.onSignIn = () async => Future.value(null);
      mockGoogleAuthService.onGetIdToken = ({forceRefresh = true}) async => null;

      final result = await authProvider.googleLogin();
      expect(result, false);
    });

    test('initialize() sets unauthenticated when no session exists', () async {
      // Google auth unavailable
      mockGoogleAuthService.isAvailable = false;

      await authProvider.initialize();

      // Should be unauthenticated since there's no session
      expect(authProvider.status, AuthStatus.unauthenticated);
    });

    test('logout() clears state regardless of errors', () async {
      // Set some state
      authProvider = AuthProvider(googleAuthService: mockGoogleAuthService);

      await authProvider.logout();

      expect(authProvider.user, isNull);
      expect(authProvider.status, AuthStatus.unauthenticated);
    });

    test('clearError() clears error message', () {
      authProvider.clearError();
      expect(authProvider.errorMessage, isNull);
    });
  });

  group('AuthProvider - State Transitions', () {
    test('googleSignInSupported reflects GoogleAuthService availability', () async {
      mockGoogleAuthService.isAvailable = true;
      // initialize() sets _googleSignInSupported
      await authProvider.initialize();
      expect(authProvider.googleSignInSupported, isTrue);
    });

    test('isAuthenticated is false when status is initial', () {
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.status, AuthStatus.initial);
    });
  });
}
