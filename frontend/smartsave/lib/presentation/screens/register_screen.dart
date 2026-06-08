import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../app/routes.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/loading_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
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
                const SizedBox(height: 20),
                FadeInLeft(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.grey700)))),
                const SizedBox(height: 32),
                FadeInLeft(delay: const Duration(milliseconds: 100), child: Text('Create Account', style: Theme.of(context).textTheme.displaySmall)),
                const SizedBox(height: 8),
                FadeInLeft(delay: const Duration(milliseconds: 200), child: Text('Start your financial journey today', style: Theme.of(context).textTheme.bodyLarge)),
                const SizedBox(height: 32),

                FadeInUp(delay: const Duration(milliseconds: 300), child: CustomTextField(controller: _nameController, label: 'Full Name', hint: 'Enter your name', prefixIcon: Icons.person_outline, validator: (v) => v!.length >= 2 ? null : 'Name is required')),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 350), child: CustomTextField(controller: _emailController, label: 'Email', hint: 'Enter your email', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) => v!.contains('@') ? null : 'Enter valid email')),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 400), child: CustomTextField(controller: _passwordController, label: 'Password', hint: 'Min 6 characters', obscureText: _obscurePassword, prefixIcon: Icons.lock_outlined, suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.grey400), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), validator: (v) => v!.length >= 6 ? null : 'Min 6 characters')),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 450), child: CustomTextField(controller: _confirmPasswordController, label: 'Confirm Password', hint: 'Re-enter password', obscureText: _obscureConfirm, prefixIcon: Icons.lock_outlined, suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppColors.grey400), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)), validator: (v) => v == _passwordController.text ? null : 'Passwords do not match')),
                const SizedBox(height: 16),
                if (authProvider.errorMessage != null)
                  FadeInUp(child: Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(top: 16), decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(12)), child: Text(authProvider.errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)))),

                const SizedBox(height: 24),
                FadeInUp(delay: const Duration(milliseconds: 500), child: LoadingButton(text: 'Create Account', isLoading: authProvider.isLoading, onPressed: _register)),
                const SizedBox(height: 24),
                FadeInUp(delay: const Duration(milliseconds: 600), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Already have an account?', style: Theme.of(context).textTheme.bodyMedium), TextButton(onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login), child: const Text('Sign In'))])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
