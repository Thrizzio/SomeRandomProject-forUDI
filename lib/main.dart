import 'package:flutter/material.dart';
import 'package:sms_parser_basically/read_sms.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalAuthService>(
          create: (_) => LocalAuthService(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<LocalAuthService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'GigTax',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
          ),
        ),

        // OPTION 1: Use AuthGate (recommended)
        home: const AuthGate(),

        // OPTION 2 (for testing SMS directly):
        // home: const ReadSmsScreen(),
      ),
    );
  }
}