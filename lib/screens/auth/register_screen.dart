import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/ui_state_provider.dart';
import '../../services/app_logger.dart';
import '../../widgets/error_and_loading_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const String _tag = 'RegisterScreen';

  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmPasswordCtrl;
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    AppLogger.info(_tag, 'Screen initialized');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final uiState = context.read<UiStateProvider>();

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      uiState.setLoading(true);
      AppLogger.info(_tag, 'Attempting registration for: $email');

      final auth = context.read<AuthProvider>();
      final ok = await auth.register(email, password);

      if (!mounted) return;

      if (ok) {
        uiState.setSuccess('Account created! Please login.');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop();
      } else {
        uiState.setError(auth.error ?? 'Registration failed');
      }
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Registration exception', e, stackTrace);
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
        title: 'Create Account',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join GigTax Today',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an account to track your gig income',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 24),
              if (uiState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ErrorDisplay(
                    error: uiState.errorMessage!,
                    onRetry: () => context.read<UiStateProvider>().clearError(),
                  ),
                ),
              if (uiState.successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SuccessMessage(message: uiState.successMessage!),
                ),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      enabled: !uiState.isLoading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Email is required';
                        if (!_isValidEmail(v)) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      enabled: !uiState.isLoading,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Password is required';
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      enabled: !uiState.isLoading,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          },
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Please confirm your password';
                        if (v != _passwordCtrl.text.trim()) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: uiState.isLoading ? null : _onRegister,
                        child: uiState.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
