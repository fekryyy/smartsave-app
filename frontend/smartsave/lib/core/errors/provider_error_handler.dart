import 'package:flutter/material.dart';
import 'failures.dart';

/// Mixin that standardizes error handling across all ChangeNotifier providers.
///
/// Provides:
/// - Consistent `_errorMessage` + `errorMessage` getter
/// - `clearError()` method
/// - `setError()` for standardized error message extraction from any exception type
///
/// Usage:
/// ```dart
/// class MyProvider extends ChangeNotifier with ProviderErrorHandler {
///   Future<void> loadData() async {
///     await wrapAsync(() async {
///       // risky operation
///     }, onError: (msg) => _errorMessage = msg);
///   }
/// }
/// ```
mixin ProviderErrorHandler on ChangeNotifier {
  String? _errorMessage;

  /// The current error message, or null if no error.
  String? get errorMessage => _errorMessage;

  /// Returns true if there is an active error.
  bool get hasError => _errorMessage != null;

  /// Clears the current error message.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Sets the error message and notifies listeners.
  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Extracts a user-friendly error message from any exception type.
  /// Handles [Failure] subclasses, [DioException] (if Dio is available),
  /// and generic [Exception].
  String extractErrorMessage(Object error) {
    if (error is Failure) {
      return error.message;
    }
    // Safe check for DioException without requiring the import
    if (error.runtimeType.toString() == 'DioException') {
      try {
        final dynamic dioErr = error;
        final response = dioErr.response;
        if (response != null && response.data is Map) {
          final msg = (response.data as Map)['message'];
          if (msg is String && msg.isNotEmpty) return msg;
        }
      } catch (_) {}
    }
    if (error is Exception) {
      final msg = error.toString();
      // Remove the "Exception: " prefix if present
      return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
    }
    return 'An unexpected error occurred';
  }

  /// Wraps an async operation with standardized error handling.
  ///
  /// - Sets `_isLoading = true` before the operation
  /// - Sets `_isLoading = false` after (success or failure)
  /// - Extracts error message on failure
  /// - Returns `true` on success, `false` on failure
  ///
  /// [ref] is an optional reference to a `bool Function()` loading getter/setter.
  /// If not provided, it uses local `_isLoading` / `setLoading()`.
  Future<bool> wrapAsync(
    Future<void> Function() operation, {
    required void Function(String) onError,
    VoidCallback? onSuccess,
    bool Function()? isLoading,
    void Function(bool)? setLoading,
  }) async {
    final loadingSetter = setLoading ?? _defaultSetLoading;
    loadingSetter(true);
    notifyListeners();

    try {
      await operation();
      _errorMessage = null;
      onSuccess?.call();
      loadingSetter(false);
      notifyListeners();
      return true;
    } catch (e) {
      final msg = extractErrorMessage(e);
      onError(msg);
      loadingSetter(false);
      notifyListeners();
      return false;
    }
  }

  void _defaultSetLoading(bool value) {
    // Override in providers that have _isLoading
  }
}
