import 'package:flutter_test/flutter_test.dart';
import 'package:smartsave/services/google_auth_service.dart';

/// Unit tests for GoogleAuthService.
///
/// These tests verify the service's error handling and state management
/// in isolation. Full integration tests with Firebase and Google Sign-In
/// require a real Firebase project and device/emulator.
void main() {
  late GoogleAuthService googleAuthService;

  setUp(() {
    googleAuthService = GoogleAuthService();
  });

  group('GoogleAuthService', () {
    test('initial state is not initialized', () {
      expect(googleAuthService.isInitialized, false);
      expect(googleAuthService.isAvailable, false);
      expect(googleAuthService.isSignedIn, false);
      expect(googleAuthService.currentFirebaseUser, isNull);
      expect(googleAuthService.userEmail, isNull);
      expect(googleAuthService.userDisplayName, isNull);
      expect(googleAuthService.userPhotoUrl, isNull);
    });

    test('init() sets initialized flag even without Firebase', () async {
      // Even without Firebase configured, init() should not crash
      // and should set isInitialized = true
      await googleAuthService.init();
      expect(googleAuthService.isInitialized, true);
      // isAvailable will be false because Firebase isn't configured
      // in the test environment
    });

    test('signOut() does not throw when not initialized', () async {
      // signOut should never throw, even if called before init()
      await expectLater(googleAuthService.signOut(), completes);
    });

    test('signOut() does not throw after init without Firebase', () async {
      await googleAuthService.init();
      await expectLater(googleAuthService.signOut(), completes);
    });

    test('signIn() returns null when not available', () async {
      final result = await googleAuthService.signIn();
      expect(result, isNull);
    });

    test('revokeAccess() does not throw', () async {
      await expectLater(googleAuthService.revokeAccess(), completes);
    });

    test('getIdToken() returns null when not signed in', () async {
      final token = await googleAuthService.getIdToken();
      expect(token, isNull);
    });

    test('trySilentSignIn() returns null when not available', () async {
      final result = await googleAuthService.trySilentSignIn();
      expect(result, isNull);
    });

    test('init() can be called multiple times safely', () async {
      await googleAuthService.init();
      await googleAuthService.init(); // Second call should be no-op
      expect(googleAuthService.isInitialized, true);
    });

    test('isSignedIn returns false when Firebase is null', () {
      // Before init, _firebaseAuth is null
      expect(googleAuthService.isSignedIn, false);
    });
  });
}
