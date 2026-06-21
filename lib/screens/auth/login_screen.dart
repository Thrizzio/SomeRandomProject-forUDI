import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/ui_state_provider.dart';
import '../../services/app_logger.dart';
import '../../widgets/error_and_loading_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _tag = 'LoginScreen';

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    AppLogger.info(_tag, 'Screen initialized');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final uiState = context.read<UiStateProvider>();

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        uiState.setError('Email and password are required');
        return;
      }

      if (!email.contains('@')) {
        uiState.setError('Please enter a valid email');
        return;
      }

      if (password.length < 6) {
        uiState.setError('Password must be at least 6 characters');
        return;
      }

      uiState.setLoading(true);
      AppLogger.info(_tag, 'Attempting login for: $email');
      final success = await context.read<AuthProvider>().login(email, password);

      if (!mounted) return;

      if (success) {
        uiState.setSuccess('Login successful!');
      } else {
        uiState.setError(context.read<AuthProvider>().error ?? 'Login failed');
      }
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Login exception', e, stackTrace);
      if (mounted) {
        uiState.setError('An unexpected error occurred');
      }
    } finally {
      if (mounted) {
        uiState.setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = context.watch<UiStateProvider>();

    return Scaffold(
      appBar: ProductionAppBar(
        title: 'GigTax Login',
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.security,
                        size: 64,
                        color: Colors.deepPurple.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'GigTax',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Income Tracking for Gig Workers',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                if (uiState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ErrorDisplay(
                      error: uiState.errorMessage!,
                      onRetry: () =>
                          context.read<UiStateProvider>().clearError(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                if (uiState.successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SuccessMessage(message: uiState.successMessage!),
                  ),
                TextField(
                  controller: _emailController,
                  enabled: !uiState.isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'your@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  enabled: !uiState.isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: uiState.isLoading ? null : _handleLogin,
                    icon: uiState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(uiState.isLoading ? 'Logging in...' : 'Login'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: uiState.isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text('Register'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
