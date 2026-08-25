// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amardokan/main.dart';

void main() {
  testWidgets('AmarDokan App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app runs and shows MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}