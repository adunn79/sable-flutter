import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';
import '../helpers/test_helpers.dart';

/// Comprehensive Settings Screen Tests
/// Verifies rendering, navigation, interactions, and all settings components
void main() {
  group('Settings Screen - Core Rendering', () {
    testWidgets('Settings screen renders without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('Settings screen has no overflow errors', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await verifyNoOverflowErrors(tester);
    });

    testWidgets('Back button is present and functional', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget, reason: 'Back button not found');
      
      // Tap should not crash
      await tester.tap(backButton);
      await tester.pumpAndSettle();
    });
  });

  group('Settings Screen - Scrolling & Layout', () {
    testWidgets('Scrolling works without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await verifyScrollable(tester);
    });

    testWidgets('Can scroll to bottom of screen', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      
      // Scroll far down
      for (int i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      
      expect(tester.takeException(), isNull);
    });

    testWidgets('ListView exists for scrollable content', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('Settings Screen - Permission Toggles', () {
    testWidgets('All permission toggles are present', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      // Core permission tiles
      expect(find.text('Contacts'), findsWidgets, reason: 'Contacts permission missing');
      expect(find.text('Photos'), findsWidgets, reason: 'Photos permission missing');
      expect(find.text('Calendar'), findsWidgets, reason: 'Calendar permission missing');
    });

    testWidgets('Switches are functional', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      final switches = find.byType(Switch);
      expect(switches, findsWidgets, reason: 'No switches found');
      
      // Tap first switch
      if (switches.evaluate().isNotEmpty) {
        await tester.tap(switches.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Switch tap caused exception');
      }
    });
  });

  group('Settings Screen - Voice Settings', () {
    testWidgets('Voice Engine section exists', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      expect(find.text('Voice Engine'), findsOneWidget, reason: 'Voice Engine section missing');
    });
  });

  group('Settings Screen - Avatar Section', () {
    testWidgets('Chat Appearance section exists', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      // Scroll to find it
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      
      expect(find.text('Chat Appearance'), findsWidgets);
    });
  });

  group('Settings Screen - Music Integration', () {
    testWidgets('Music integration section renders', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      // Scroll to music section
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      
      expect(find.text('MUSIC INTEGRATION'), findsOneWidget, reason: 'Music section missing');
    });

    testWidgets('Spotify row is tappable', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      
      final spotify = find.text('Spotify');
      if (spotify.evaluate().isNotEmpty) {
        await tester.tap(spotify.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Apple Music row is tappable', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      
      final appleMusic = find.text('Apple Music');
      if (appleMusic.evaluate().isNotEmpty) {
        await tester.tap(appleMusic.first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Settings Screen - Bond Engine', () {
    testWidgets('Bond Engine section exists', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      expect(find.text('Current State:'), findsOneWidget, reason: 'Bond Engine state missing');
    });
  });

  group('Settings Screen - Integration Tests', () {
    testWidgets('Complete scroll journey without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      // Scroll to bottom
      for (int i = 0; i < 10; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Scroll $i caused exception');
      }
      
      // Scroll back to top
      for (int i = 0; i < 10; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Scroll back $i caused exception');
      }
      
      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('Multiple toggle interactions dont crash', (tester) async {
      await pumpScreenWithMockImages(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      
      final switches = find.byType(Switch);
      final switchCount = switches.evaluate().length;
      
      // Tap multiple switches
      for (int i = 0; i < (switchCount > 3 ? 3 : switchCount); i++) {
        await tester.tap(switches.at(i));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Switch $i toggle caused exception');
      }
    });
  });
}
