import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
	const RegisterScreen({super.key});

	@override
	State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
