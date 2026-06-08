import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/routes.dart';
import '../../providers/auth_provider.dart';

/// Route guard widget that protects authenticated routes.
///
/// Wraps any widget that requires authentication. If the user is not
/// authenticated, redirects to the login screen.
///
/// ## Usage
/// ```dart
/// RouteGuard(
///   child: DashboardScreen(),
/// )
/// ```
///
/// Or with a custom redirect:
/// ```dart
/// RouteGuard(
///   redirectTo: '/custom-login',
///   child: ProfileScreen(),
/// )
/// ```
///
/// ## Behavior
/// - **Initial state** (auth not yet checked): Shows a loading indicator
/// - **Authenticated**: Shows the child widget
/// - **Unauthenticated**: Redirects to [redirectTo] (default: login)
/// - **Error state**: Shows error with retry option
///
/// ## Security
/// Route guards are a FIRST LINE of defense only.
/// ALL API endpoints must independently verify authentication.
/// Never rely solely on client-side route protection.
class RouteGuard extends StatelessWidget {
  final Widget child;
  final String redirectTo;
  final Widget? loadingWidget;

  const RouteGuard({
    super.key,
    required this.child,
    this.redirectTo = AppRoutes.login,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    switch (authProvider.status) {
      case AuthStatus.initial:
        // Auth state not yet determined — show loading
        return loadingWidget ??
            const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );

      case AuthStatus.loading:
        return loadingWidget ??
            const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );

      case AuthStatus.authenticated:
        // User is authenticated — show the protected content
        return child;

      case AuthStatus.unauthenticated:
        // User is not authenticated — redirect to login
        // Use addPostFrameCallback to prevent build-time navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, redirectTo);
          }
        });
        return loadingWidget ??
            const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );

      case AuthStatus.error:
        // Error during auth check — show error with retry
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authProvider.errorMessage ?? 'Authentication error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => authProvider.initialize(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      authProvider.logout();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, redirectTo);
                      }
                    },
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}

/// Mixin for stateful widgets to check authentication before navigation.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with AuthCheckMixin {
///   Future<void> onButtonTap() async {
///     final isAuth = await ensureAuthenticated(context);
///     if (!isAuth) return; // Redirect already happened
///     // Proceed with authenticated action
///   }
/// }
/// ```
mixin AuthCheckMixin<T extends StatefulWidget> on State<T> {
  /// Checks if the user is authenticated.
  /// If not, redirects to login and returns false.
  @protected
  Future<bool> ensureAuthenticated(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
      return false;
    }
    return true;
  }
}
