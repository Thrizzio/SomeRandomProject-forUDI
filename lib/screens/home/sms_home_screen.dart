import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../read_sms.dart';
import '../profile/profile_screen.dart';

class SmsHomeScreen extends StatelessWidget {
	const SmsHomeScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final auth = context.watch<AuthProvider>();
		final user = auth.user;
		final initials = _getInitials(user?.email ?? '');

		return ReadSmsScreen(
			appBarActions: [
				// Profile Icon Button
				Padding(
					padding: const EdgeInsets.only(right: 8),
					child: Center(
						child: GestureDetector(
							onTap: () {
								Navigator.push(
									context,
									MaterialPageRoute(
										builder: (context) => const ProfileScreen(),
									),
								);
							},
							child: CircleAvatar(
								radius: 18,
								backgroundColor: Colors.white,
								child: Text(
									initials,
									style: const TextStyle(
										color: Color(0xFF1E40AF),
										fontWeight: FontWeight.w700,
										fontSize: 12,
									),
								),
							),
						),
					),
				),
			],
		);
	}

	String _getInitials(String email) {
		if (email.isEmpty) return '';
		final parts = email.split('@')[0].split('.');
		if (parts.length >= 2) {
			return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
		}
		return email[0].toUpperCase();
	}
}
