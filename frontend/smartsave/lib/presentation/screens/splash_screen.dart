import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../app/routes.dart';

/// Animated splash screen that initializes auth state and navigates accordingly.
///
/// ## Navigation logic
/// 1. Delays 2 seconds for splash animation
/// 2. Calls [AuthProvider.initialize] which:
///    - Checks JWT token in secure storage (email/password users)
///    - Checks Firebase Auth cached session (Google Sign-In users)
///    - Tries silent Google sign-in if no JWT found
/// 3. Navigates to:
///    - Onboarding → if authenticated but onboarding not completed
///    - Dashboard → if authenticated and onboarding done
///    - Login → if not authenticated
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.initialize();
    } catch (_) {
      // If initialize throws (e.g., Keychain read failure), go to login
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    if (!mounted) return;
    final isAuth = authProvider.isAuthenticated;
    final user = authProvider.user;
    final showOnboarding = isAuth && user != null && !user.onboardingCompleted;

    Navigator.pushReplacementNamed(
      context,
      showOnboarding ? AppRoutes.onboarding : (isAuth ? AppRoutes.dashboard : AppRoutes.login),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              child: Text(
                'SmartSave',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Smart Saving, Smart Living',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
