import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ui_state_provider.dart';
import '../../widgets/error_and_loading_widgets.dart';
import '../../services/app_logger.dart';
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
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Validation
      if (email.isEmpty || password.isEmpty) {
        AppLogger.warning(_tag, 'Empty credentials attempted');
        context.read<UiStateProvider>().setError('Email and password are required');
        return;
      }

      if (!email.contains('@')) {
        AppLogger.warning(_tag, 'Invalid email format: $email');
        context.read<UiStateProvider>().setError('Please enter a valid email');
        return;
      }

      if (password.length < 6) {
        AppLogger.warning(_tag, 'Password too short');
        context.read<UiStateProvider>().setError('Password must be at least 6 characters');
        return;
      }

      // Perform login
      AppLogger.info(_tag, 'Attempting login for: $email');
      context.read<UiStateProvider>().setLoading(true);
      final success = await context.read<AuthProvider>().login(email, password);

      if (mounted) {
        if (success) {
          AppLogger.info(_tag, 'Login successful for: $email');
          context.read<UiStateProvider>().setSuccess('Login successful!');
        } else {
          final error = context.read<AuthProvider>().error ?? 'Login failed';
          AppLogger.error(_tag, 'Login failed: $error', null);
          context.read<UiStateProvider>().setError(error);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Login exception', e, stackTrace);
      if (mounted) {
        context.read<UiStateProvider>().setError('An unexpected error occurred');
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
                
                // Logo/Title
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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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

                // Error message
                if (uiState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ErrorDisplay(
                      error: uiState.errorMessage!,
                      onRetry: () => context.read<UiStateProvider>().clearError(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),

                // Success message
                if (uiState.successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SuccessMessage(message: uiState.successMessage!),
                  ),

                // Email field
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.shade600,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Password field
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
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.deepPurple.shade600,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login button
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: uiState.isLoading ? null : _handleLogin,
                    icon: uiState.isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withOpacity(0.7),
                        ),
                      ),
                    )
                        : const Icon(Icons.login),
                    label: Text(
                      uiState.isLoading ? 'Logging in...' : 'Login',
                      style: const TextTheme().bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Register link
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
                        AppLogger.info(_tag, 'Navigating to register');
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Register',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade600,
                        ),
                      ),
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