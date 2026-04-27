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
    try {
      if (!_formKey.currentState!.validate()) return;

      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      final uiState = context.read<UiStateProvider>();
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
        context.read<UiStateProvider>().setError('An unexpected error occurred');
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
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'Password must be at least 6 characters';
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
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Please confirm your password';
                        if (v != _passwordCtrl.text.trim()) return 'Passwords do not match';
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

	final _emailCtrl = TextEditingController();
	final _passwordCtrl = TextEditingController();
	final _confirmPasswordCtrl = TextEditingController();
	final _formKey = GlobalKey<FormState>();
	bool _obscurePassword = true;
	bool _obscureConfirmPassword = true;
	bool _isLoading = false;

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

		setState(() => _isLoading = true);

		try {
			final auth = context.read<AuthProvider>();
			final ok = await auth.register(
				_emailCtrl.text.trim(),
				_passwordCtrl.text.trim(),
			);

			if (!mounted) return;

			if (ok) {
				Navigator.pop(context);
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: const Text('Registration successful. Please login.'),
						backgroundColor: Colors.green[700],
						behavior: SnackBarBehavior.floating,
						shape: RoundedRectangleBorder(
							borderRadius: BorderRadius.circular(12),
						),
					),
				);
				return;
			}

			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(auth.error ?? 'Registration failed'),
					backgroundColor: Colors.red[700],
					behavior: SnackBarBehavior.floating,
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(12),
					),
				),
			);
		} finally {
			if (mounted) {
				setState(() => _isLoading = false);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: SafeArea(
				child: SingleChildScrollView(
					child: Padding(
						padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								// Back Button
								Align(
									alignment: Alignment.centerLeft,
									child: IconButton(
										icon: const Icon(Icons.arrow_back),
										color: const Color(0xFF1E40AF),
										onPressed: () => Navigator.pop(context),
									),
								),
								const SizedBox(height: 16),

								// Header Section
								_buildHeader(),
								const SizedBox(height: 40),

								// Registration Form Card
								_buildRegisterCard(),
							],
						),
					),
				),
			),
		);
	}

	Widget _buildHeader() {
		return Column(
			children: [
				// App Logo/Icon
				Container(
					width: 80,
					height: 80,
					decoration: BoxDecoration(
						gradient: const LinearGradient(
							colors: [
								Color(0xFF1E40AF),
								Color(0xFF0EA5E9),
							],
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
						),
						borderRadius: BorderRadius.circular(20),
					),
					child: const Icon(
						Icons.receipt_long,
						color: Colors.white,
						size: 40,
					),
				),
				const SizedBox(height: 24),

				// Title
				Text(
					'Create Account',
					style: Theme.of(context).textTheme.headlineSmall?.copyWith(
						fontWeight: FontWeight.w800,
						color: const Color(0xFF1E40AF),
					),
				),
				const SizedBox(height: 8),

				// Subtitle
				Text(
					'Join GigTax today',
					style: Theme.of(context).textTheme.bodyMedium?.copyWith(
						color: const Color(0xFF6B7280),
						fontSize: 15,
					),
				),
			],
		);
	}

	Widget _buildRegisterCard() {
		return Card(
			elevation: 2,
			child: Padding(
				padding: const EdgeInsets.all(28),
				child: Form(
					key: _formKey,
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							// Form Title
							Text(
								'Registration Details',
								style: Theme.of(context).textTheme.titleLarge?.copyWith(
									fontWeight: FontWeight.w700,
								),
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 8),

							Text(
								'Fill in your information to get started',
								style: Theme.of(context).textTheme.bodyMedium,
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 28),

							// Email Field
							TextFormField(
								controller: _emailCtrl,
								keyboardType: TextInputType.emailAddress,
								decoration: InputDecoration(
									labelText: 'Email Address',
									hintText: 'Enter your email',
									prefixIcon: const Icon(Icons.email_outlined),
									prefixIconColor: const Color(0xFF6B7280),
									errorText: null,
								),
								validator: (value) {
									final v = (value ?? '').trim();
									if (v.isEmpty) return 'Email is required';
									if (!_isValidEmail(v)) return 'Enter a valid email';
									return null;
								},
							),
							const SizedBox(height: 16),

							// Password Field
							TextFormField(
								controller: _passwordCtrl,
								obscureText: _obscurePassword,
								decoration: InputDecoration(
									labelText: 'Password',
									hintText: 'At least 6 characters',
									prefixIcon: const Icon(Icons.lock_outline),
									prefixIconColor: const Color(0xFF6B7280),
									suffixIcon: IconButton(
										icon: Icon(
											_obscurePassword ? Icons.visibility_off : Icons.visibility,
											color: const Color(0xFF6B7280),
										),
										onPressed: () {
											setState(() => _obscurePassword = !_obscurePassword);
										},
									),
									errorText: null,
								),
								validator: (value) {
									final v = (value ?? '').trim();
									if (v.isEmpty) return 'Password is required';
									if (v.length < 6) return 'Password must be at least 6 characters';
									return null;
								},
							),
							const SizedBox(height: 16),

							// Confirm Password Field
							TextFormField(
								controller: _confirmPasswordCtrl,
								obscureText: _obscureConfirmPassword,
								decoration: InputDecoration(
									labelText: 'Confirm Password',
									hintText: 'Re-enter your password',
									prefixIcon: const Icon(Icons.lock_outline),
									prefixIconColor: const Color(0xFF6B7280),
									suffixIcon: IconButton(
										icon: Icon(
											_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
											color: const Color(0xFF6B7280),
										),
										onPressed: () {
											setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
										},
									),
									errorText: null,
								),
								validator: (value) {
									final v = (value ?? '').trim();
									if (v.isEmpty) return 'Please confirm your password';
									if (v != _passwordCtrl.text.trim()) return 'Passwords do not match';
									return null;
								},
							),
							const SizedBox(height: 28),

							// Register Button
							SizedBox(
								height: 56,
								child: ElevatedButton(
									onPressed: _isLoading ? null : _onRegister,
									style: ElevatedButton.styleFrom(
										backgroundColor: const Color(0xFF1E40AF),
										foregroundColor: Colors.white,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(12),
										),
										elevation: 3,
									),
									child: _isLoading
										? const SizedBox(
											height: 24,
											width: 24,
											child: CircularProgressIndicator(
												strokeWidth: 2.5,
												valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
											),
										)
										: const Text(
											'Create Account',
											style: TextStyle(
												fontSize: 16,
												fontWeight: FontWeight.w600,
											),
										),
								),
							),
						],
					),
				),
			),
		);
	}

}
