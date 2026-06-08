import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/errors/failures.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/remote/challenge_remote_datasource.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepositoryImpl _authRepository = AuthRepositoryImpl();
  final ChallengeRemoteDataSource _challengeRemote = ChallengeRemoteDataSource();
  
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> initialize() async {
    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        try {
          _user = await _authRepository.getProfile();
          _status = AuthStatus.authenticated;
        } catch (_) {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
    // Fire-and-forget: gamification should never break auth flow
    _recordLoginSafe();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.login(email, password);
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      // Fire-and-forget: gamification should never break auth flow
      _recordLoginSafe();
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

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.register(name, email, password);
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      // Fire-and-forget: gamification should never break auth flow
      _recordLoginSafe();
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

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

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

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      _user = await _authRepository.updateProfile(data);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update profile.';
      notifyListeners();
    }
  }

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

  Future<void> loadProfile() async {
    try {
      _user = await _authRepository.getProfile();
      notifyListeners();
    } catch (_) {}
  }

  String _extractError(Object e) {
    if (e is DioException && e.response?.data is Map) {
      return (e.response!.data as Map)['message'] ?? 'Request failed. Please try again.';
    }
    return 'Request failed. Please try again.';
  }

  /// Fire-and-forget gamification tracking that never throws
  Future<void> _recordLoginSafe() async {
    try {
      await _challengeRemote.recordLogin();
    } catch (_) {
      // Silently ignore — gamification should never break auth
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
