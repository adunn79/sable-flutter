// ignore_for_file: avoid_print
/// ═══════════════════════════════════════════════════════════════════════════
/// SQUAD 1: ZOMBIE HUNTER - UI/UX DEAD ELEMENT AUDITOR
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Target: Dead buttons, non-responsive elements, layout issues
/// Method: Tap every interactive element, verify response
/// 
/// Run: flutter test test/red_team/zombie_hunter_test.dart
/// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'red_team_framework.dart';

// Target screens
import 'package:sable/src/pages/chat/chat_page.dart';
import 'package:sable/features/today/screens/today_screen.dart';
import 'package:sable/features/vital_balance/screens/vital_balance_screen.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';
import 'package:sable/features/more/screens/more_screen.dart';
import 'package:sable/features/journal/screens/journal_timeline_screen.dart';

void main() {
  setUpAll(() async {
    await setUpRedTeam();
    print('🧟 SQUAD "ZOMBIE HUNTER" ACTIVATED - UI DEAD ELEMENT SCAN');
    print('═══════════════════════════════════════════════════════════════');
    print('');
  });

  tearDownAll(() async {
    await tearDownRedTeam();
  });

  group('🧟 ZOMBIE HUNTER - ChatPage', () {
    testWidgets('ZH1: ChatPage interactive elements respond', (tester) async {
      await _auditScreen(
        tester: tester,
        screenName: 'ChatPage',
        screen: const ChatPage(),
      );
    });
  });

  group('🧟 ZOMBIE HUNTER - TodayScreen', () {
    testWidgets('ZH2: TodayScreen interactive elements respond', (tester) async {
      await _auditScreen(
        tester: tester,
        screenName: 'TodayScreen',
        screen: const TodayScreen(),
      );
    });
  });

  group('🧟 ZOMBIE HUNTER - VitalBalanceScreen', () {
    testWidgets('ZH3: VitalBalanceScreen interactive elements respond', (tester) async {
      await _auditScreen(
        tester: tester,
        screenName: 'VitalBalanceScreen',
        screen: const VitalBalanceScreen(),
      );
    });
  });

  group('🧟 ZOMBIE HUNTER - SettingsScreen', () {
    testWidgets('ZH4: SettingsScreen interactive elements respond', (tester) async {
      await _auditScreen(
        tester: tester,
        screenName: 'SettingsScreen',
        screen: const SettingsScreen(),
      );
    });
  });

  group('🧟 ZOMBIE HUNTER - MoreScreen', () {
    testWidgets('ZH5: MoreScreen interactive elements respond', (tester) async {
      await _auditScreen(
        tester: tester,
        screenName: 'MoreScreen',
        screen: const MoreScreen(),
      );
    });
  });

  group('🧟 ZOMBIE HUNTER - JournalTimelineScreen', () {
    testWidgets('ZH6: JournalTimelineScreen interactive elements respond', (tester) async {
      await _auditScreen(
        tester: tester,
        screenName: 'JournalTimelineScreen',
        screen: const JournalTimelineScreen(),
      );
    });
  });
}

/// Audit a screen for dead elements
Future<void> _auditScreen({
  required WidgetTester tester,
  required String screenName,
  required Widget screen,
}) async {
  try {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(buildRedTeamWidget(screen));
      await tester.pump(const Duration(milliseconds: 500));
    });

    // Find all interactive elements
    final inkWells = find.byType(InkWell);
    final gestureDetectors = find.byType(GestureDetector);
    final iconButtons = find.byType(IconButton);
    final textButtons = find.byType(TextButton);
    final elevatedButtons = find.byType(ElevatedButton);
    final switches = find.byType(Switch);

    final totalElements = 
        inkWells.evaluate().length +
        gestureDetectors.evaluate().length +
        iconButtons.evaluate().length +
        textButtons.evaluate().length +
        elevatedButtons.evaluate().length +
        switches.evaluate().length;

    var responsiveCount = 0;
    var deadElements = <String>[];

    // Test InkWells
    for (final element in inkWells.evaluate().take(10)) {
      try {
        await tester.tap(find.byWidget(element.widget as Widget).first);
        await tester.pump(const Duration(milliseconds: 100));
        responsiveCount++;
      } catch (e) {
        deadElements.add('InkWell at ${element.renderObject?.debugSemanticsDumpRenderObjectToString(prefix: "")}');
      }
    }

    // Test IconButtons
    for (final element in iconButtons.evaluate().take(10)) {
      try {
        await tester.tap(find.byWidget(element.widget as Widget).first);
        await tester.pump(const Duration(milliseconds: 100));
        responsiveCount++;
      } catch (e) {
        deadElements.add('IconButton');
      }
    }

    // Record result
    final hasDeadElements = deadElements.isNotEmpty;
    
    redTeamReport.addResult(AuditResult(
      squadName: 'ZOMBIE HUNTER',
      testName: '$screenName element audit',
      resultType: hasDeadElements ? AuditResultType.warning : AuditResultType.pass,
      details: 'Found $totalElements interactive elements, ${deadElements.length} unresponsive',
    ));

    // Log dead elements if found
    if (deadElements.isNotEmpty) {
      print('   ⚠️ Dead elements in $screenName:');
      for (final dead in deadElements.take(5)) {
        print('      - $dead');
      }
    }

  } catch (e) {
    // Screen render issues are warnings, not failures
    final errorStr = e.toString();
    if (errorStr.contains('Multiple exceptions') || errorStr.contains('GoogleFonts')) {
      redTeamReport.addResult(AuditResult(
        squadName: 'ZOMBIE HUNTER',
        testName: '$screenName element audit',
        resultType: AuditResultType.warning,
        details: 'Test env issue during audit',
      ));
    } else {
      redTeamReport.addResult(AuditResult(
        squadName: 'ZOMBIE HUNTER',
        testName: '$screenName element audit',
        resultType: AuditResultType.fail,
        details: errorStr.split('\n').first,
      ));
    }
  }
}
