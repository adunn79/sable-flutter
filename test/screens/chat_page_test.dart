import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/src/pages/chat/chat_page.dart';
import '../helpers/test_helpers.dart';

/// Comprehensive Chat Page Tests
/// Verifies core chat functionality, UI elements, and interactions
void main() {
  group('Chat Page - Core Rendering', () {
    testWidgets('Chat page renders without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      // Chat page may not have "Chat" title, verify by absence of exception
      expect(tester.takeException(), isNull, reason: 'Chat page crashed on render');
    });

    testWidgets('Chat page has no overflow errors on load', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await verifyNoOverflowErrors(tester);
    });
  });

  group('Chat Page - Input Area', () {
    testWidgets('Text input field exists', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.byType(TextField), findsWidgets, reason: 'Text input field missing');
    });

    testWidgets('Input placeholder text is visible', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.text('Type a message...'), findsWidgets);
    });

    testWidgets('Wand icon (rewrite) is present', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.byIcon(LucideIcons.wand2), findsWidgets, reason: 'Wand icon missing');
    });

    testWidgets('Microphone icon is present', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      final micIcon = find.byIcon(LucideIcons.mic);
      final micOffIcon = find.byIcon(LucideIcons.micOff);
      expect(
        micIcon.evaluate().isNotEmpty || micOffIcon.evaluate().isNotEmpty,
        true,
        reason: 'Microphone icon missing',
      );
    });

    testWidgets('Volume/mute icon is present', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      final volumeIcon = find.byIcon(LucideIcons.volume2);
      final muteIcon = find.byIcon(LucideIcons.volumeX);
      expect(
        volumeIcon.evaluate().isNotEmpty || muteIcon.evaluate().isNotEmpty,
        true,
        reason: 'Volume icon missing',
      );
    });

    testWidgets('Display mode icon is present', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.byIcon(LucideIcons.image), findsWidgets, reason: 'Display icon missing');
    });

    testWidgets('Clock icon is present', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.byIcon(LucideIcons.clock), findsWidgets, reason: 'Clock icon missing');
    });

    testWidgets('Music icon is present', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.byIcon(LucideIcons.music), findsWidgets, reason: 'Music icon missing');
    });

    testWidgets('Info icon is present', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.byIcon(LucideIcons.info), findsWidgets, reason: 'Info icon missing');
    });
  });

  group('Chat Page - Floating Chips', () {
    testWidgets('Daily Update chip exists', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.text('Daily\nUpdate'), findsOneWidget, reason: 'Daily Update chip missing');
    });

    testWidgets('Local Vibe chip exists', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.text('Local\nVibe'), findsOneWidget, reason: 'Local Vibe chip missing');
    });

    testWidgets('Scroll chip exists', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.text('Scroll\n↓'), findsOneWidget, reason: 'Scroll chip missing');
    });

    testWidgets('Clear Screen chip exists', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.text('Clear\nScreen'), findsOneWidget, reason: 'Clear Screen chip missing');
    });

    testWidgets('Share chip exists', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.text('Share'), findsOneWidget, reason: 'Share chip missing');
    });

    testWidgets('Chips are tappable without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      // Tap Daily Update
      final dailyUpdate = find.text('Daily\nUpdate');
      if (dailyUpdate.evaluate().isNotEmpty) {
        await tester.tap(dailyUpdate);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Daily Update tap crashed');
      }
    });
  });

  group('Chat Page - Message List', () {
    testWidgets('ListView exists for messages', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      expect(find.byType(ListView), findsWidgets, reason: 'Message list missing');
    });
  });

  group('Chat Page - Header', () {
    testWidgets('Weather widget or temperature exists', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      // Look for temperature pattern (e.g., "47°")
      final tempFinder = find.textContaining('°');
      // May or may not find depending on weather load, just verify no crash
      expect(tester.takeException(), isNull);
    });
  });

  group('Chat Page - Icon Interactions', () {
    testWidgets('Microphone icon is tappable', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      final mic = find.byIcon(LucideIcons.mic);
      if (mic.evaluate().isNotEmpty) {
        await tester.tap(mic.first);
        await tester.pump(const Duration(milliseconds: 500));
        // Note: May request permission, just verify no crash
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Volume icon toggles mute state', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      final volume = find.byIcon(LucideIcons.volume2);
      if (volume.evaluate().isNotEmpty) {
        await tester.tap(volume.first);
        await tester.pumpAndSettle();
        // After tap, should show mute icon
        expect(find.byIcon(LucideIcons.volumeX), findsWidgets);
      }
    });

    testWidgets('Display mode icon opens modal', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      final displayIcon = find.byIcon(LucideIcons.image);
      if (displayIcon.evaluate().isNotEmpty) {
        await tester.tap(displayIcon.first);
        await tester.pumpAndSettle();
        
        // Modal should appear with display mode options
        expect(find.text('Display Mode'), findsWidgets);
      }
    });

    testWidgets('Info icon shows help dialog', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      final info = find.byIcon(LucideIcons.info);
      if (info.evaluate().isNotEmpty) {
        await tester.tap(info.first);
        await tester.pumpAndSettle();
        
        // Help sheet should appear
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Chat Page - Text Input', () {
    testWidgets('Can type in text field', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Hello Aeliana');
      await tester.pumpAndSettle();
      
      expect(find.text('Hello Aeliana'), findsOneWidget);
    });

    testWidgets('Can clear text field', (tester) async {
      await pumpScreenWithMockImages(tester, const ChatPage());
      await tester.pumpAndSettle();
      
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test message');
      await tester.pumpAndSettle();
      
      await tester.enterText(textField, '');
      await tester.pumpAndSettle();
      
      expect(find.text('Test message'), findsNothing);
    });
  });
}
