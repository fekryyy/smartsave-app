import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../app/routes.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/loading_button.dart';

/// Login screen with email/password and Google Sign-In support.
///
/// ## Google Sign-In
/// The "Continue with Google" button:
/// - Uses brand-matching colors (Google blue / dark mode gray)
/// - Shows a loading spinner during authentication
/// - Is disabled during active auth operations
/// - Falls back gracefully when Google Sign-In is unavailable
/// - Prevents duplicate login attempts
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _googleSignInLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      final user = authProvider.user;
      if (user != null && !user.onboardingCompleted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    }
  }

  Future<void> _googleLogin() async {
    if (_googleSignInLoading) return; // Prevent duplicate taps

    final authProvider = context.read<AuthProvider>();

    if (!authProvider.googleSignInSupported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In is not configured. Please use email login.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _googleSignInLoading = true);

    final success = await authProvider.googleLogin();

    if (!mounted) return;
    setState(() => _googleSignInLoading = false);

    if (success && mounted) {
      final user = authProvider.user;
      if (user != null && !user.onboardingCompleted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                FadeInLeft(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.grey700),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInLeft(
                  delay: const Duration(milliseconds: 100),
                  child: Text('Welcome Back', style: Theme.of(context).textTheme.displaySmall),
                ),
                const SizedBox(height: 8),
                FadeInLeft(
                  delay: const Duration(milliseconds: 200),
                  child: Text('Sign in to continue managing your finances', style: Theme.of(context).textTheme.bodyLarge),
                ),
                const SizedBox(height: 40),

                // ── Email Field ──
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (v) => v!.contains('@') ? null : 'Enter valid email',
                  ),
                ),
                const SizedBox(height: 16),

                // ── Password Field ──
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.grey400),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) => v!.length >= 6 ? null : 'Min 6 characters',
                  ),
                ),
                const SizedBox(height: 8),

                // ── Forgot Password ──
                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                ),

                // ── Error Message ──
                if (authProvider.errorMessage != null)
                  FadeInUp(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        authProvider.errorMessage!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Sign In Button ──
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: LoadingButton(
                    text: 'Sign In',
                    isLoading: authProvider.isLoading,
                    onPressed: _login,
                  ),
                ),

                // ── Divider ──
                const SizedBox(height: 24),
                FadeInUp(
                  delay: const Duration(milliseconds: 650),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or continue with',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey400),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Google Sign-In Button ──
                FadeInUp(
                  delay: const Duration(milliseconds: 700),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: authProvider.isLoading || _googleSignInLoading
                          ? null
                          : _googleLogin,
                      icon: _googleSignInLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.g_mobiledata, size: 28),
                      label: Text(
                        _googleSignInLoading
                            ? 'Signing in...'
                            : 'Continue with Google',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppColors.grey800,
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.grey600
                              : AppColors.grey300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Register Link ──
                FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
