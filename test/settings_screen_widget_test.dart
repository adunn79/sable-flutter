import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';

/// Widget tests for Settings Screen
/// Tests all toggles, navigation, and UI interactions
void main() {
  group('Settings Screen Widget Tests', () {
    testWidgets('Settings screen builds without crash', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('All permission toggles are present', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for permission tiles
      expect(find.text('Contacts'), findsWidgets);
      expect(find.text('Photos'), findsWidgets);
      expect(find.text('Calendar'), findsWidgets);
      expect(find.text('Reminders'), findsWidgets);
    });

    testWidgets('Bond engine section renders', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Current State:'), findsOneWidget);
    });

    testWidgets('Voice settings are accessible', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Voice Engine'), findsOneWidget);
    });

    testWidgets('Scrolling works without crash', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to bottom
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Scroll to top
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('Back button exists and is tappable', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      // Verify it's tappable (won't navigate in test, but shouldn't crash)
      await tester.tap(backButton);
      await tester.pumpAndSettle();
    });
  });

  group('Permission Toggle Interaction Tests', () {
    testWidgets('Tapping permission toggle shows response', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find a switch (any permission toggle)
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Tap first switch
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Should not crash after toggle
      expect(find.text('SETTINGS'), findsOneWidget);
    });
  });

  group('Visual Regression Tests', () {
    testWidgets('Settings screen maintains layout', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify key sections exist
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });
  });
}
