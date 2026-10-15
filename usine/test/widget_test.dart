import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usine/features/about/presentation/pages/about_page.dart';

void main() {
  testWidgets('AboutPage renders successfully', (WidgetTester tester) async {
    // Build the AboutPage within a MaterialApp and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutPage(),
      ),
    );

    // Verify that the title and key elements are rendered.
    expect(find.text('Gestion Usine d\'Eau'), findsOneWidget);
    expect(find.text('Version 1.0.0 (Stable)'), findsOneWidget);
    expect(find.byIcon(Icons.water_drop), findsOneWidget);
  });
}
