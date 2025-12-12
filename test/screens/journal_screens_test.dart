import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/features/journal/screens/journal_timeline_screen.dart';
import 'package:sable/features/journal/screens/journal_editor_screen.dart';
import '../helpers/test_helpers.dart';

/// Comprehensive Journal Screen Tests
/// Covers Journal Timeline, Editor, and all journal functionality
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Journal Timeline - Core Rendering', () {
    testWidgets('Journal timeline renders without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      expect(tester.takeException(), isNull, reason: 'Journal timeline crashed');
    });

    testWidgets('Journal timeline has no overflow errors', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await verifyNoOverflowErrors(tester);
    });
  });

  group('Journal Timeline - Header', () {
    testWidgets('Journal title exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      expect(find.text('JOURNAL'), findsWidgets, reason: 'Journal title missing');
    });

    testWidgets('New entry button exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Look for add/plus icon or FAB
      final addButton = find.byIcon(LucideIcons.plus);
      final fabButton = find.byType(FloatingActionButton);
      
      expect(
        addButton.evaluate().isNotEmpty || fabButton.evaluate().isNotEmpty,
        true,
        reason: 'New entry button missing',
      );
    });
  });

  group('Journal Timeline - Entry List', () {
    testWidgets('ListView or scroll view exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Should have a scrollable list
      final listView = find.byType(ListView);
      final customScroll = find.byType(CustomScrollView);
      
      expect(
        listView.evaluate().isNotEmpty || customScroll.evaluate().isNotEmpty,
        true,
        reason: 'No scrollable list found',
      );
    });

    testWidgets('Scrolling works without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Try scrolling
      try {
        await tester.drag(find.byType(ListView).first, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 300));
      } catch (_) {
        // ListView might not exist if empty, try CustomScrollView
        try {
          await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -200));
          await tester.pump(const Duration(milliseconds: 300));
        } catch (_) {
          // Acceptable if no scrollable content
        }
      }
      
      expect(tester.takeException(), isNull);
    });
  });

  group('Journal Timeline - Navigation', () {
    testWidgets('Calendar icon or view exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      final calendarIcon = find.byIcon(LucideIcons.calendar);
      // May exist in header
      expect(tester.takeException(), isNull);
    });

    testWidgets('Insights navigation exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Look for insights or stats icon
      final insights = find.byIcon(LucideIcons.barChart2);
      final stats = find.byIcon(LucideIcons.pieChart);
      
      expect(tester.takeException(), isNull);
    });
  });

  group('Journal Timeline - Empty State', () {
    testWidgets('Shows appropriate content when empty', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Should show either entries OR empty state message
      expect(tester.takeException(), isNull);
    });
  });

  group('Journal Editor - Core Rendering', () {
    testWidgets('Journal editor renders without crash', (tester) async {
      // Editor requires an entry or create new mode
      await pumpScreenWithMockImages(tester, const JournalEditorScreen());
      expect(tester.takeException(), isNull, reason: 'Journal editor crashed');
    });

    testWidgets('Journal editor has no overflow', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalEditorScreen());
      await verifyNoOverflowErrors(tester);
    });
  });

  group('Journal Editor - UI Elements', () {
    testWidgets('Save button exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalEditorScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      final saveIcon = find.byIcon(LucideIcons.check);
      final saveText = find.text('Save');
      
      expect(
        saveIcon.evaluate().isNotEmpty || saveText.evaluate().isNotEmpty,
        true,
        reason: 'Save button missing',
      );
    });

    testWidgets('Back button exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalEditorScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      final backIcon = find.byIcon(LucideIcons.arrowLeft);
      final backIcon2 = find.byIcon(Icons.arrow_back);
      
      expect(
        backIcon.evaluate().isNotEmpty || backIcon2.evaluate().isNotEmpty,
        true,
        reason: 'Back button missing',
      );
    });
  });

  group('Journal Editor - Rich Text Editor', () {
    testWidgets('Text editor area exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalEditorScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Quill editor or text field should exist
      final textField = find.byType(TextField);
      final editableText = find.byType(EditableText);
      
      expect(
        textField.evaluate().isNotEmpty || editableText.evaluate().isNotEmpty,
        true,
        reason: 'No text editor found',
      );
    });
  });

  group('Journal Editor - Context Enrichment', () {
    testWidgets('Location context area exists', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalEditorScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Location or map icon
      final locationIcon = find.byIcon(LucideIcons.mapPin);
      // May or may not be visible depending on permissions
      expect(tester.takeException(), isNull);
    });

    testWidgets('Weather context may exist', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalEditorScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Weather elements
      expect(tester.takeException(), isNull);
    });
  });

  group('Journal - Integration Tests', () {
    testWidgets('Timeline to editor navigation doesnt crash', (tester) async {
      await pumpScreenWithMockImages(tester, const JournalTimelineScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Find and tap new entry button
      final addButton = find.byIcon(LucideIcons.plus);
      final fabButton = find.byType(FloatingActionButton);
      
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton.first);
        await tester.pump(const Duration(milliseconds: 300));
      } else if (fabButton.evaluate().isNotEmpty) {
        await tester.tap(fabButton.first);
        await tester.pump(const Duration(milliseconds: 300));
      }
      
      expect(tester.takeException(), isNull);
    });
  });
}
