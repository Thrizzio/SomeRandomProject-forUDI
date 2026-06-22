import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_parser_basically/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed_v1': true,
    });
  });

  testWidgets('App builds and displays main navigation or login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    int pumps = 0;
    while (tester.any(find.byType(CircularProgressIndicator)) && pumps < 10) {
      await tester.pump(const Duration(milliseconds: 100));
      pumps++;
    }

    expect(find.textContaining('GigTax'), findsWidgets);
  });
}
