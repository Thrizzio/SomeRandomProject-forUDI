import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';

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

		final auth = context.read<AuthProvider>();
		final ok = await auth.register(
			_emailCtrl.text.trim(),
			_passwordCtrl.text.trim(),
		);

		if (!mounted) return;

		if (ok) {
			Navigator.pop(context);
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Registration successful. Please login.')),
			);
			return;
		}

		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text(auth.error ?? 'Registration failed')),
		);
	}

	@override
	Widget build(BuildContext context) {
		final auth = context.watch<AuthProvider>();
		final colors = Theme.of(context).colorScheme;

		return Scaffold(
			appBar: AppBar(
				title: const Text('Create Account'),
				elevation: 0,
			),
			body: Center(
				child: SingleChildScrollView(
					padding: const EdgeInsets.symmetric(
						horizontal: AppSpacing.lg,
						vertical: AppSpacing.xl,
					),
					child: Form(
						key: _formKey,
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								// Header
								Icon(
									Icons.person_add_outlined,
									size: 48,
									color: colors.primary,
								),
								const SizedBox(height: AppSpacing.xl),
								Text(
									'Get Started',
									style: Theme.of(context).textTheme.headlineSmall?.copyWith(
										fontWeight: FontWeight.bold,
									),
								),
								const SizedBox(height: AppSpacing.md),
								Text(
									'Join us to track income and manage taxes',
									style: Theme.of(context).textTheme.bodySmall,
									textAlign: TextAlign.center,
								),
								const SizedBox(height: AppSpacing.xl),

								// Email field
								TextFormField(
									controller: _emailCtrl,
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
								const SizedBox(height: AppSpacing.lg),

								// Password field
								TextFormField(
									controller: _passwordCtrl,
									obscureText: true,
									decoration: const InputDecoration(
										labelText: 'Password',
										prefixIcon: Icon(Icons.lock_outlined),
										helperText: 'At least 6 characters',
									),
									validator: (value) {
										final v = (value ?? '').trim();
										if (v.isEmpty) return 'Password is required';
										if (v.length < 6) return 'Password must be at least 6 characters';
										return null;
									},
								),
								const SizedBox(height: AppSpacing.lg),

								// Confirm password field
								TextFormField(
									controller: _confirmPasswordCtrl,
									obscureText: true,
									decoration: const InputDecoration(
										labelText: 'Confirm Password',
										prefixIcon: Icon(Icons.lock_outlined),
									),
									validator: (value) {
										final v = (value ?? '').trim();
										if (v.isEmpty) return 'Please confirm your password';
										if (v != _passwordCtrl.text.trim()) return 'Passwords do not match';
										return null;
									},
								),
								const SizedBox(height: AppSpacing.xxl),

								// Register button
								SizedBox(
									width: double.infinity,
									child: ElevatedButton(
										onPressed: auth.loading ? null : _onRegister,
										child: auth.loading
											? SizedBox(
												height: 20,
												width: 20,
												child: CircularProgressIndicator(
													strokeWidth: 2,
													valueColor: AlwaysStoppedAnimation(colors.surface),
												),
											)
											: const Text('Create Account'),
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
