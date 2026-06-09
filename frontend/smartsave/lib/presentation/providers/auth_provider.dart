import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import '../../core/di/service_locator.dart';
import '../../core/errors/failures.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/remote/challenge_remote_datasource.dart';
import '../../data/datasources/local/local_database.dart';
import '../../services/google_auth_service.dart';
import '../../services/cache_manager.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Authentication state provider with Google Sign-In, email/password,
/// session restoration, and route guard support.
///
/// ## Auth Flow (Google Sign-In)
/// 1. User taps "Sign in with Google"
/// 2. [GoogleAuthService] presents the Google account picker
/// 3. User selects account → Google returns credential
/// 4. Firebase Auth signs in with the Google credential
/// 5. A fresh Firebase ID token is obtained
/// 6. The ID token is sent to `POST /auth/google` on the backend
/// 7. Backend creates/finds the user and returns a JWT
/// 8. JWT is stored in [FlutterSecureStorage] (same as email login)
/// 9. Auth state updated to authenticated
///
/// ## Session Restoration
/// On app start, [initialize] checks:
/// 1. JWT token in secure storage (for existing email/password users)
/// 2. Firebase Auth cached session (for Google Sign-In users)
/// The fastest available valid session is restored.
class AuthProvider extends ChangeNotifier {
  final AuthRepositoryImpl _authRepository = AuthRepositoryImpl();
  final ChallengeRemoteDataSource _challengeRemote = ChallengeRemoteDataSource();
  final GoogleAuthService _googleAuthService;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;
  bool _googleSignInSupported = true;

  /// Monotonically increasing session counter.
  /// Incremented on every auth change (login, register, googleLogin, logout).
  /// Data providers watch this to detect when they need to clear stale data
  /// from a previous user's session.
  int _sessionId = 0;

  /// Constructor accepts an optional [GoogleAuthService].
  /// If not provided, it resolves from the service locator.
  AuthProvider({GoogleAuthService? googleAuthService})
      : _googleAuthService = googleAuthService ?? getIt<GoogleAuthService>();

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Monotonically increasing session counter.
  /// Providers compare this to their cached value to detect auth changes
  /// and clear stale data from a previous user's session.
  int get sessionId => _sessionId;

  /// Whether Google Sign-In is available on the current device.
  /// Returns false when Firebase isn't configured or Google Play Services
  /// are missing on Android.
  bool get googleSignInSupported => _googleSignInSupported;

  /// Initializes authentication state on app startup.
  ///
  /// Checks both JWT-based sessions (email/password) and Firebase sessions
  /// (Google Sign-In). The fastest available path to authentication wins.
  ///
  /// ## Session priority
  /// 1. Existing JWT token with valid profile → restore immediately
  /// 2. Firebase Auth cached session → get ID token → exchange for JWT
  /// 3. No session → show login screen
  Future<void> initialize() async {
    try {
      // ── Check Google Sign-In availability ──
      _googleSignInSupported = _googleAuthService.isAvailable;

      // ── Phase 1: Try JWT-based session (fast path) ──
      final hasJwt = await _authRepository.isLoggedIn();
      if (hasJwt) {
        try {
          _user = await _authRepository.getProfile();
          _status = AuthStatus.authenticated;
          _sessionId++; // Fresh session — providers must reload
          notifyListeners();
          _recordLoginSafe().catchError((_) {});
          return; // JWT session restored — done
        } catch (_) {
          // JWT expired or invalid — fall through to Phase 2
          debugPrint('[AuthProvider] JWT expired, checking Firebase');
        }
      }

      // ── Phase 2: Try Firebase session (silent sign-in) ──
      if (_googleAuthService.isAvailable) {
        final restored = await _tryRestoreFirebaseSession();
        if (restored) {
          _sessionId++; // Fresh session — providers must reload
          notifyListeners();
          _recordLoginSafe().catchError((_) {});
          return;
        }
      }

      // ── No session found — go to login ──
      _status = AuthStatus.unauthenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
    // Fire-and-forget: gamification should never break auth flow
    _recordLoginSafe().catchError((_) {});
  }

  /// Tries to restore a Firebase Auth session and exchange it for a JWT.
  /// Returns true if the session was restored successfully.
  Future<bool> _tryRestoreFirebaseSession() async {
    try {
      // First check if Firebase already has a current user
      final firebaseUser = _googleAuthService.currentFirebaseUser;

      if (firebaseUser != null) {
        // Firebase has a cached session — get a fresh ID token
        final idToken = await _googleAuthService.getIdToken();
        if (idToken != null) {
          _user = await _authRepository.googleLogin(idToken);
          _status = AuthStatus.authenticated;
          return true;
        }
      }

      // Try silent Google sign-in (restores previous Google session)
      final credential = await _googleAuthService.trySilentSignIn();
      if (credential != null) {
        final idToken = await _googleAuthService.getIdToken();
        if (idToken != null) {
          _user = await _authRepository.googleLogin(idToken);
          _status = AuthStatus.authenticated;
          return true;
        }
      }
    } catch (_) {
      // Silent sign-in failed — this is normal on first launch
      debugPrint('[AuthProvider] Firebase session restore failed');
    }
    return false;
  }

  /// Authenticates with email and password.
  ///
  /// Returns true on success, false on failure. On failure, [errorMessage]
  /// contains a user-friendly error description.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.login(email, password);
      _status = AuthStatus.authenticated;
      _isLoading = false;
      _sessionId++; // Signal all providers to clear stale data
      notifyListeners();
      // Fire-and-forget: gamification should never break auth flow
      _recordLoginSafe().catchError((_) {});
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.error;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _extractError(e);
      _status = AuthStatus.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Authenticates with Google Sign-In.
  ///
  /// Flow:
  /// 1. Google Sign-In SDK presents the account picker
  /// 2. User selects a Google account
  /// 3. Firebase Auth signs in with the Google credential
  /// 4. A fresh Firebase ID token is obtained
  /// 5. The ID token is sent to the backend for JWT exchange
  /// 6. JWT is stored and user model is loaded
  ///
  /// Returns true on success, false on failure/cancellation.
  /// On failure, [errorMessage] contains a user-friendly error.
  Future<bool> googleLogin() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ── Step 1: Sign in with Google → Firebase ──
      final credential = await _googleAuthService.signIn();
      if (credential == null) {
        // User cancelled or an error occurred
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // ── Step 2: Get fresh Firebase ID token ──
      final idToken = await _googleAuthService.getIdToken();
      if (idToken == null) {
        _errorMessage = 'Failed to authenticate with Google. Please try again.';
        _status = AuthStatus.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // ── Step 3: Exchange Firebase token for backend JWT ──
      _user = await _authRepository.googleLogin(idToken);
      _status = AuthStatus.authenticated;
      _isLoading = false;
      _sessionId++; // Signal all providers to clear stale data
      notifyListeners();
      // Fire-and-forget: gamification should never break auth flow
      _recordLoginSafe().catchError((_) {});
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.error;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _extractError(e);
      _status = AuthStatus.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Registers a new user with email and password.
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.register(name, email, password);
      _status = AuthStatus.authenticated;
      _isLoading = false;
      _sessionId++; // Signal all providers to clear stale data
      notifyListeners();
      // Fire-and-forget: gamification should never break auth flow
      _recordLoginSafe().catchError((_) {});
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.error;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _extractError(e);
      _status = AuthStatus.error;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Signs out the user from all auth providers.
  ///
  /// This:
  /// 1. Clears the JWT token from secure storage
  /// 2. Signs out of Firebase Auth (if Google Sign-In was used)
  /// 3. Signs out of Google Sign-In
  /// 4. Clears all local auth state
  ///
  /// Safe to call even if the user wasn't signed in. Never throws.
  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (_) {
      // Logout should never fail — clear local state regardless
    }

    // Sign out of Google/Firebase if available (fire-and-forget)
    _signOutGoogle();

    // Clear all caches and local DB
    await _clearCaches();

    _user = null;
    _status = AuthStatus.unauthenticated;
    _sessionId++; // Signal all providers to clear stale data
    notifyListeners();
  }

  /// Clears all local caches for the current session.
  /// Never throws. Clears:
  ///   - CacheManager entries (shared HTTP response cache)
  ///   - Local DB user data tables (transactions, goals, budgets,
  ///     pending_operations) to prevent data leakage between users
  Future<void> _clearCaches() async {
    try {
      await CacheManager().invalidateAll();
    } catch (_) {
      // Cache invalidation is non-critical
    }
    try {
      await LocalDatabase.instance.clearAllUserData();
    } catch (_) {
      // Local DB clear is non-critical
    }
  }

  /// Signs out of Firebase and Google (fire-and-forget).
  void _signOutGoogle() {
    try {
      _googleAuthService.signOut();
    } catch (_) {
      // Never let Google sign-out break the app
    }
  }

  /// Sends a password reset email.
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.forgotPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send reset email.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates the user's profile on the backend.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      _user = await _authRepository.updateProfile(data);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update profile.';
      notifyListeners();
    }
  }

  /// Changes the user's password.
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      await _authRepository.changePassword(currentPassword, newPassword);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to change password.';
      notifyListeners();
      return false;
    }
  }

  /// Forces a fresh profile reload from the backend.
  Future<void> loadProfile() async {
    try {
      _user = await _authRepository.getProfile();
      notifyListeners();
    } catch (_) {}
  }

  /// Extracts a user-friendly error message from various exception types.
  String _extractError(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return (e.response!.data as Map)['message'] ?? 'Request failed. Please try again.';
    }
    return 'Request failed. Please try again.';
  }

  /// When true, disables gamification recording (intended for unit tests
  /// where platform channels and HTTP are unavailable).
  @visibleForTesting
  static bool disableGamification = false;

  /// Fire-and-forget gamification tracking that never throws.
  Future<void> _recordLoginSafe() async {
    if (disableGamification) return;
    try {
      await _challengeRemote.recordLogin();
    } catch (_) {
      // Silently ignore — gamification should never break auth
    }
  }

  /// Clears the current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
