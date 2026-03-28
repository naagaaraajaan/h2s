import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aushadhi_bridge/main.dart';

void main() {
  group('Aushadhi Bridge High-Level Tests', () {
    testWidgets('App renders main UI elements correctly', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const AushadhiApp());

      // Verify AppBar Title is present (there might be multiple widgets with this text)
      expect(find.text('Aushadhi Bridge'), findsWidgets);

      // Verify the default vernacular language selection is visible
      expect(find.text('Hindi'), findsOneWidget);

      // Verify the analysis button exists
      expect(find.text('Digitize & Find Generics'), findsOneWidget);

      // Verify Symptoms TextField exists
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Submitting without API Key shows configuration error', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const AushadhiApp());

      // Attempt to digitize right away
      await tester.tap(find.text('Digitize & Find Generics'));

      // Rebuild the app to process the interaction and snackbar animation
      await tester.pump();

      // Since test environments don't have the --dart-define passed into them automatically,
      // it should trigger the API key configuration snackbar error immediately!
      expect(find.text('Please configure your Gemini API Key using --dart-define.'), findsOneWidget);
    });

    testWidgets('Dropdown contains supported regional languages', (WidgetTester tester) async {
      await tester.pumpWidget(const AushadhiApp());

      // Tap the dropdown to open it
      await tester.tap(find.text('Hindi'));
      await tester.pumpAndSettle();

      // Verify all our available vernacular languages are in the list
      expect(find.text('Marathi').last, findsOneWidget);
      expect(find.text('Tamil').last, findsOneWidget);
      expect(find.text('Telugu').last, findsOneWidget);
      expect(find.text('English').last, findsOneWidget);
    });
  });
}
