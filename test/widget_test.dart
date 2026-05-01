// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medilocker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: This might fail in a real test environment without Firebase initialization,
    // but for now we're just fixing the compilation error.
    await tester.pumpWidget(const MediLockerApp());

    // Verify that the app title or some login text is present
    expect(find.text('MediLocker'), findsWidgets);
  });
}
