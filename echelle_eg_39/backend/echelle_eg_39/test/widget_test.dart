// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/main.dart';

void main() {
  testWidgets('App builds and displays home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EchelleEG39App());

    // Verify that the app title is displayed.
    expect(find.text('ÉCHELLE EG39'), findsOneWidget);

    // Verify that the home screen text is present.
    expect(find.text('Équipements populaires'), findsOneWidget);
  });
}
