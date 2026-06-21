import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_parser_basically/main.dart';

void main() {
  testWidgets('App builds and displays login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // Start auth check async operations

    // Wait until the CircularProgressIndicator is gone
    while (tester.any(find.byType(CircularProgressIndicator))) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('GigTax Login'), findsOneWidget);
  });
}
