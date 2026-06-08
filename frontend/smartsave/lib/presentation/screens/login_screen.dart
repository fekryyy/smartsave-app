import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../app/routes.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/loading_button.dart';

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
    // Google sign-in would be implemented here
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sign-In coming soon')),
      );
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

                FadeInUp(delay: const Duration(milliseconds: 300), child: CustomTextField(controller: _emailController, label: 'Email', hint: 'Enter your email', keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined, validator: (v) => v!.contains('@') ? null : 'Enter valid email')),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 400), child: CustomTextField(controller: _passwordController, label: 'Password', hint: 'Enter your password', obscureText: _obscurePassword, prefixIcon: Icons.lock_outlined, suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.grey400), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), validator: (v) => v!.length >= 6 ? null : 'Min 6 characters')),
                const SizedBox(height: 8),
                FadeInUp(delay: const Duration(milliseconds: 500), child: Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword), child: const Text('Forgot Password?')))),

                if (authProvider.errorMessage != null)
                  FadeInUp(child: Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(12)), child: Text(authProvider.errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)))),

                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 600), child: LoadingButton(text: 'Sign In', isLoading: authProvider.isLoading, onPressed: _login)),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 700), child: SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.g_mobiledata, size: 28), onPressed: _googleLogin, label: const Text('Continue with Google')))),
                const SizedBox(height: 24),
                FadeInUp(delay: const Duration(milliseconds: 800), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Don't have an account?", style: Theme.of(context).textTheme.bodyMedium), TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.register), child: const Text('Sign Up'))])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
