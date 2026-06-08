import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../presentation/providers/auth_provider.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/loading_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.forgotPassword(_emailController.text.trim());

    if (success && mounted) {
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _emailSent
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_outline, size: 80, color: AppColors.success),
                const SizedBox(height: 24),
                Text('Email Sent!', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Check your email for password reset instructions', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Login')),
              ])
            : Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 20),
                  Text('Forgot your password?', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text("Enter your email and we'll send you a reset link", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 32),
                  CustomTextField(controller: _emailController, label: 'Email', hint: 'Enter your email', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) => v!.contains('@') ? null : 'Enter valid email'),
                  const SizedBox(height: 24),
                  LoadingButton(text: 'Send Reset Link', isLoading: authProvider.isLoading, onPressed: _sendResetEmail),
                ]),
              ),
      ),
    );
  }
}
