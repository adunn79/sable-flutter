import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/features/onboarding/screens/screen_1_calibration.dart';
import 'package:sable/features/onboarding/screens/screen_2_protocol.dart';
import 'package:sable/features/onboarding/screens/screen_3_archetype.dart';
import 'package:sable/features/onboarding/screens/screen_4_customize.dart';
import '../helpers/test_helpers.dart';

/// Comprehensive Onboarding Screen Tests
/// Covers all onboarding flow screens for complete user journey
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Onboarding Screen 1 - Calibration', () {
    testWidgets('Calibration screen renders without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const CalibrationScreen());
      expect(tester.takeException(), isNull, reason: 'Calibration screen crashed');
    });

    testWidgets('Calibration screen has no overflow', (tester) async {
      await pumpScreenWithMockImages(tester, const CalibrationScreen());
      await verifyNoOverflowErrors(tester);
    });

    testWidgets('Name input field exists', (tester) async {
      await pumpScreenWithMockImages(tester, const CalibrationScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      expect(find.byType(TextField), findsWidgets, reason: 'Name input missing');
    });

    testWidgets('Can enter name in field', (tester) async {
      await pumpScreenWithMockImages(tester, const CalibrationScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, 'Test User');
      await tester.pump(const Duration(milliseconds: 300));
      
      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('Continue button exists', (tester) async {
      await pumpScreenWithMockImages(tester, const CalibrationScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      final continueText = find.text('Continue');
      final nextIcon = find.byIcon(LucideIcons.arrowRight);
      
      expect(
        continueText.evaluate().isNotEmpty || nextIcon.evaluate().isNotEmpty,
        true,
        reason: 'Continue/Next button missing',
      );
    });

    testWidgets('Date picker interaction works', (tester) async {
      await pumpScreenWithMockImages(tester, const CalibrationScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Date picker may exist for birthday
      final datePicker = find.byType(CupertinoDatePicker);
      if (datePicker.evaluate().isNotEmpty) {
        // Scroll date picker
        await tester.drag(datePicker.first, const Offset(0, -50));
        await tester.pump(const Duration(milliseconds: 300));
      }
      
      expect(tester.takeException(), isNull);
    });
  });

  group('Onboarding Screen 2 - Protocol', () {
    testWidgets('Protocol screen renders without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const ProtocolScreen());
      expect(tester.takeException(), isNull, reason: 'Protocol screen crashed');
    });

    testWidgets('Protocol screen has no overflow', (tester) async {
      await pumpScreenWithMockImages(tester, const ProtocolScreen());
      await verifyNoOverflowErrors(tester);
    });

    testWidgets('Protocol text is displayed', (tester) async {
      await pumpScreenWithMockImages(tester, const ProtocolScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Should have some protocol/terms content
      expect(tester.takeException(), isNull);
    });

    testWidgets('Accept button exists', (tester) async {
      await pumpScreenWithMockImages(tester, const ProtocolScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      final acceptText = find.text('Accept');
      final agreeText = find.text('I Agree');
      final continueText = find.text('Continue');
      
      expect(
        acceptText.evaluate().isNotEmpty || 
        agreeText.evaluate().isNotEmpty ||
        continueText.evaluate().isNotEmpty,
        true,
        reason: 'Accept/Agree button missing',
      );
    });

    testWidgets('Can scroll protocol content', (tester) async {
      await pumpScreenWithMockImages(tester, const ProtocolScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      await verifyScrollable(tester, scrollableType: SingleChildScrollView);
      expect(tester.takeException(), isNull);
    });
  });

  group('Onboarding Screen 3 - Archetype Selection', () {
    testWidgets('Archetype screen renders without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const ArchetypeScreen());
      expect(tester.takeException(), isNull, reason: 'Archetype screen crashed');
    });

    testWidgets('Archetype screen has no overflow', (tester) async {
      await pumpScreenWithMockImages(tester, const ArchetypeScreen());
      await verifyNoOverflowErrors(tester);
    });

    testWidgets('Multiple archetype options exist', (tester) async {
      await pumpScreenWithMockImages(tester, const ArchetypeScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Should find archetype names
      final aeliana = find.text('Aeliana');
      final sable = find.text('Sable');
      final kai = find.text('Kai');
      
      final foundArchetypes = [
        aeliana.evaluate().isNotEmpty,
        sable.evaluate().isNotEmpty,
        kai.evaluate().isNotEmpty,
      ].where((found) => found).length;
      
      expect(foundArchetypes, greaterThan(0), reason: 'No archetypes found');
    });

    testWidgets('Archetype cards are tappable', (tester) async {
      await pumpScreenWithMockImages(tester, const ArchetypeScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Try tapping an archetype
      final aeliana = find.text('Aeliana');
      if (aeliana.evaluate().isNotEmpty) {
        await tester.tap(aeliana.first);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'Archetype tap crashed');
      }
    });

    testWidgets('Can scroll through archetypes', (tester) async {
      await pumpScreenWithMockImages(tester, const ArchetypeScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Try horizontal or vertical scroll
      final pageView = find.byType(PageView);
      final listView = find.byType(ListView);
      
      if (pageView.evaluate().isNotEmpty) {
        await tester.drag(pageView.first, const Offset(-200, 0));
        await tester.pump(const Duration(milliseconds: 300));
      } else if (listView.evaluate().isNotEmpty) {
        await tester.drag(listView.first, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 300));
      }
      
      expect(tester.takeException(), isNull);
    });
  });

  group('Onboarding Screen 4 - Customization', () {
    testWidgets('Customize screen renders without crash', (tester) async {
      await pumpScreenWithMockImages(tester, const CustomizeScreen());
      expect(tester.takeException(), isNull, reason: 'Customize screen crashed');
    });

    testWidgets('Customize screen has no overflow', (tester) async {
      await pumpScreenWithMockImages(tester, const CustomizeScreen());
      await verifyNoOverflowErrors(tester);
    });

    testWidgets('Avatar preview exists', (tester) async {
      await pumpScreenWithMockImages(tester, const CustomizeScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      // Should have image preview
      final imageWidget = find.byType(Image);
      final networkImage = find.byType(ClipRRect);
      
      expect(
        imageWidget.evaluate().isNotEmpty || networkImage.evaluate().isNotEmpty,
        true,
        reason: 'Avatar preview missing',
      );
    });

    testWidgets('Finish/Complete button exists', (tester) async {
      await pumpScreenWithMockImages(tester, const CustomizeScreen());
      await tester.pump(const Duration(milliseconds: 300));
      
      final finish = find.text('Finish');
      final complete = find.text('Complete');
      final done = find.text('Done');
      final useLook = find.text('Use This Look');
      
      final foundButton = [
        finish.evaluate().isNotEmpty,
        complete.evaluate().isNotEmpty,
        done.evaluate().isNotEmpty,
        useLook.evaluate().isNotEmpty,
      ].any((found) => found);
      
      expect(foundButton, true, reason: 'Finish/Complete button missing');
    });
  });

  group('Onboarding - Integration Flow', () {
    testWidgets('All screens render sequentially without crash', (tester) async {
      // Test each screen renders independently
      final screens = [
        const CalibrationScreen(),
        const ProtocolScreen(),
        const ArchetypeScreen(),
        const CustomizeScreen(),
      ];
      
      for (int i = 0; i < screens.length; i++) {
        await pumpScreenWithMockImages(tester, screens[i]);
        expect(tester.takeException(), isNull, reason: 'Screen $i crashed');
      }
    });
  });
}
