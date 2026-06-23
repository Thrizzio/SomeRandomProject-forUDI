import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_parser_basically/services/biometric_service.dart';
import 'package:sms_parser_basically/widgets/biometric_lock_wrapper.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BiometricService.mockIsAvailable = null;
    BiometricService.mockAuthResult = null;
  });

  group('BiometricLockWrapper Widget Tests', () {
    testWidgets('Renders child directly when biometric lock is disabled', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': false});
      BiometricService.mockIsAvailable = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: BiometricLockWrapper(
            child: Text('Main Financial Dashboard Content'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Main Financial Dashboard Content'), findsOneWidget);
      expect(find.text('GigTax Vault Locked'), findsNothing);
    });

    testWidgets('Renders lock screen when biometric lock is enabled and locks access', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      BiometricService.mockIsAvailable = true;
      BiometricService.mockAuthResult = false; // auth fails/unresolved initially

      await tester.pumpWidget(
        const MaterialApp(
          home: BiometricLockWrapper(
            child: Text('Main Financial Dashboard Content'),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('GigTax Vault Locked'), findsOneWidget);
      expect(find.text('Unlock Vault'), findsOneWidget);
      expect(find.text('Main Financial Dashboard Content'), findsNothing);
    });

    testWidgets('Unlocks vault and renders child upon successful biometric auth', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'biometric_lock_enabled': true});
      BiometricService.mockIsAvailable = true;
      BiometricService.mockAuthResult = false; // locked initially

      await tester.pumpWidget(
        const MaterialApp(
          home: BiometricLockWrapper(
            child: Text('Main Financial Dashboard Content'),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('GigTax Vault Locked'), findsOneWidget);

      // Now simulate successful authentication
      BiometricService.mockAuthResult = true;

      // Click the Unlock button
      await tester.tap(find.text('Unlock Vault'));
      await tester.pumpAndSettle();

      // Check if unlocked
      expect(find.text('GigTax Vault Locked'), findsNothing);
      expect(find.text('Main Financial Dashboard Content'), findsOneWidget);
    });
  });
}
