import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'providers/auth_provider.dart';
import 'providers/ui_state_provider.dart';
import 'services/app_logger.dart';
import 'services/auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/local_auth_service.dart';
import 'services/foreground_sms_handler.dart';
import 'widgets/auth_gate.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
  } catch (e) {
    AppLogger.warning('main', 'Firebase initialization error (using local mock auth/db fallback): $e');
    isFirebaseInitialized = false;
  }

  // Initialize background SMS service
  try {
    final smsHandler = ForegroundSmsHandler();
    await smsHandler.initialize();
  } catch (e) {
    AppLogger.error('main', 'SMS handler initialization error', e);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => isFirebaseInitialized ? FirebaseAuthService() : LocalAuthService(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
          )..init(), // Initialize auth on app startup
        ),
        ChangeNotifierProvider<UiStateProvider>(
          create: (_) => UiStateProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GigTax',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
