import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:postal_app/screens/login_screen.dart';

void main() {
  testWidgets('Login screen shows title and fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('Postal Courier'), findsOneWidget);
    expect(find.text('User name'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
