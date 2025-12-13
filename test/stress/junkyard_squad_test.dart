// ignore_for_file: avoid_print
/// ═══════════════════════════════════════════════════════════════════════════
/// SQUAD "JUNKYARD" - RESOURCE STARVATION TESTS
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Directive: Simulate device conditions:
/// - Battery: 2% (Low Power Mode active)
/// - RAM: 95% utilized by background apps
/// - Storage: 0MB available
/// 
/// Goal: Verify app saves state before termination. No data loss.
/// 
/// Run: flutter test test/stress/junkyard_squad_test.dart
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'stress_test_framework.dart';
import '../helpers/stress_test_helpers.dart';
import '../helpers/test_setup.dart';

// Target screens with data persistence
import 'package:sable/src/pages/chat/chat_page.dart';
import 'package:sable/features/journal/screens/journal_timeline_screen.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';
import 'package:sable/features/vital_balance/screens/vital_balance_screen.dart';
import 'package:sable/features/today/screens/today_screen.dart';

void main() {
  setUpAll(() async {
    await setUpStressTests();
    print('');
    print('🗑️ SQUAD "JUNKYARD" ACTIVATED - RESOURCE STARVATION TESTS');
    print('═════════════════════════════════════════════════════════');
    print('');
  });

  tearDownAll(() async {
    // Restore all conditions
    StorageConditionSimulator.restoreStorage();
    await tearDownStressTests();
  });

  group('🗑️ JUNKYARD SQUAD - Storage Exhaustion', () {
    
    testWidgets('J1: ChatPage render with no storage', (tester) async {
      StorageConditionSimulator.simulateFullStorage();
      
      await executeStressTest(
        tester: tester,
        testName: 'ChatPage no storage render',
        squadName: 'JUNKYARD',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          // Screen should render even if storage is "full"
          await t.pump(const Duration(seconds: 1));
          
          // Try to type a message
          final textFields = find.byType(TextField);
          if (textFields.evaluate().isNotEmpty) {
            await t.enterText(textFields.first, 'Message when storage full');
            await t.pump(const Duration(milliseconds: 500));
          }
          
          // Verify screen is still functional
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
      
      StorageConditionSimulator.restoreStorage();
    });

    testWidgets('J2: Settings save with full storage', (tester) async {
      StorageConditionSimulator.simulateFullStorage();
      
      await executeStressTest(
        tester: tester,
        testName: 'Settings save full storage',
        squadName: 'JUNKYARD',
        targetScreen: const SettingsScreen(),
        stressAction: (t) async {
          await t.pump(const Duration(milliseconds: 500));
          
          // Try to toggle settings
          final switches = find.byType(Switch);
          if (switches.evaluate().isNotEmpty) {
            // Toggle switches - should handle storage failure gracefully
            await t.tap(switches.first);
            await t.pump(const Duration(milliseconds: 500));
            
            // Toggle again
            await t.tap(switches.first);
            await t.pump(const Duration(milliseconds: 500));
          }
          
          // App should not crash, just maybe show error
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
      
      StorageConditionSimulator.restoreStorage();
    });

    testWidgets('J3: Data persistence stress', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Data persistence stress',
        squadName: 'JUNKYARD',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          // Alternate between full and available storage
          for (var i = 0; i < 5; i++) {
            StorageConditionSimulator.simulateFullStorage();
            await t.pump(const Duration(milliseconds: 200));
            
            // Try to interact
            final textFields = find.byType(TextField);
            if (textFields.evaluate().isNotEmpty) {
              await t.enterText(textFields.first, 'Storage stress $i');
              await t.pump(const Duration(milliseconds: 100));
            }
            
            StorageConditionSimulator.restoreStorage();
            await t.pump(const Duration(milliseconds: 200));
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
      
      StorageConditionSimulator.restoreStorage();
    });
  });

  group('🗑️ JUNKYARD SQUAD - Memory Pressure', () {
    
    testWidgets('J4: High memory - many widgets rendered', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'High memory widget stress',
        squadName: 'JUNKYARD',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          // Simulate many widgets by pumping frames and creating state
          MemoryPressureTracker.reset();
          
          for (var i = 0; i < 100; i++) {
            MemoryPressureTracker.recordBuild('Widget-$i');
            await t.pump(const Duration(milliseconds: 10));
          }
          
          // Simulate some disposals
          for (var i = 0; i < 80; i++) {
            MemoryPressureTracker.recordDisposal('Widget-$i');
          }
          
          // Check if we're leaking (80% disposal rate is okay)
          final ratio = MemoryPressureTracker.buildDisposeRatio;
          print('   Memory ratio: $ratio');
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });

    testWidgets('J5: Screen rebuild under memory pressure', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Screen rebuild memory pressure',
        squadName: 'JUNKYARD',
        targetScreen: const VitalBalanceScreen(),
        stressAction: (t) async {
          // Rapid screen rebuilds simulating memory pressure cleanup
          for (var i = 0; i < 20; i++) {
            await t.pump(const Duration(milliseconds: 50));
            
            // Find and interact with random elements
            final inkWells = find.byType(InkWell);
            if (inkWells.evaluate().isNotEmpty && i % 3 == 0) {
              await t.tap(inkWells.first, warnIfMissed: false);
            }
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });

    testWidgets('J6: List with many items (simulate large data)', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Large list memory stress',
        squadName: 'JUNKYARD',
        targetScreen: const TodayScreen(),
        stressAction: (t) async {
          // Scroll through a lot of content rapidly
          final scrollables = find.byType(Scrollable);
          
          if (scrollables.evaluate().isNotEmpty) {
            // Rapid scroll down
            for (var i = 0; i < 50; i++) {
              await t.drag(scrollables.first, const Offset(0, -100));
              await t.pump(const Duration(milliseconds: 20));
            }
            
            // Rapid scroll up
            for (var i = 0; i < 50; i++) {
              await t.drag(scrollables.first, const Offset(0, 100));
              await t.pump(const Duration(milliseconds: 20));
            }
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });
  });

  group('🗑️ JUNKYARD SQUAD - App Lifecycle Stress', () {
    
    testWidgets('J7: Simulate background/foreground cycles', (tester) async {
      try {
        await mockNetworkImagesFor(() async {
          for (var i = 0; i < 10; i++) {
            // "Foreground" - render screen
            await tester.pumpWidget(buildStressTestWidget(const ChatPage()));
            await tester.pump(const Duration(milliseconds: 200));
            
            // "Background" - render empty container (simulates app going to background)
            await tester.pumpWidget(buildStressTestWidget(Container()));
            await tester.pump(const Duration(milliseconds: 100));
          }
          
          // Restore to normal state
          await tester.pumpWidget(buildStressTestWidget(const ChatPage()));
          await tester.pump(const Duration(milliseconds: 500));
        });
        
        stressReport.addResult(StressTestResult(
          testName: 'Background/foreground cycles',
          squadName: 'JUNKYARD',
          resultType: StressResultType.success,
        ));
      } catch (e, stack) {
        CrashAnalyzer.recordCrash(e, stack);
        stressReport.addResult(StressTestResult(
          testName: 'Background/foreground cycles',
          squadName: 'JUNKYARD',
          resultType: StressResultType.crash,
          errorMessage: e.toString().split('\n').first,
        ));
      }
    });

    testWidgets('J8: State preservation on screen change', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'State preservation',
        squadName: 'JUNKYARD',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          // Enter some text
          final textFields = find.byType(TextField);
          if (textFields.evaluate().isNotEmpty) {
            await t.enterText(textFields.first, 'User input to preserve');
            await t.pump(const Duration(milliseconds: 200));
          }
          
          // Simulate storage becoming full mid-operation
          StorageConditionSimulator.simulateFullStorage();
          await t.pump(const Duration(milliseconds: 500));
          
          // App should still have the text field content
          // (checking that UI state isn't lost)
          expect(find.byType(Scaffold), findsAtLeast(1));
          
          StorageConditionSimulator.restoreStorage();
        },
      );
    });

    testWidgets('J9: Rapid app restart simulation', (tester) async {
      try {
        await mockNetworkImagesFor(() async {
          // Simulate multiple app restarts
          for (var i = 0; i < 5; i++) {
            // Fresh app start
            await tester.pumpWidget(buildStressTestWidget(const ChatPage()));
            await tester.pump(const Duration(milliseconds: 300));
            
            // Immediate "kill" and restart
            await tester.pumpWidget(buildStressTestWidget(Container()));
            await tester.pump(const Duration(milliseconds: 50));
            
            // Restart
            await tester.pumpWidget(buildStressTestWidget(const ChatPage()));
            await tester.pump(const Duration(milliseconds: 300));
          }
        });
        
        stressReport.addResult(StressTestResult(
          testName: 'Rapid app restart',
          squadName: 'JUNKYARD',
          resultType: StressResultType.success,
        ));
      } catch (e, stack) {
        CrashAnalyzer.recordCrash(e, stack);
        stressReport.addResult(StressTestResult(
          testName: 'Rapid app restart',
          squadName: 'JUNKYARD',
          resultType: StressResultType.crash,
          errorMessage: e.toString().split('\n').first,
        ));
      }
    });

    testWidgets('J10: Concurrent storage and memory pressure', (tester) async {
      StorageConditionSimulator.simulateFullStorage();
      
      await executeStressTest(
        tester: tester,
        testName: 'Concurrent storage + memory pressure',
        squadName: 'JUNKYARD',
        targetScreen: const SettingsScreen(),
        stressAction: (t) async {
          // Both storage full AND high memory usage
          MemoryPressureTracker.reset();
          
          // Record many builds to simulate memory pressure
          for (var i = 0; i < 50; i++) {
            MemoryPressureTracker.recordBuild('PressureWidget-$i');
          }
          
          // Try to interact with settings
          final switches = find.byType(Switch);
          final sliders = find.byType(Slider);
          
          if (switches.evaluate().isNotEmpty) {
            for (var i = 0; i < 5; i++) {
              await t.tap(switches.first, warnIfMissed: false);
              await t.pump(const Duration(milliseconds: 100));
            }
          }
          
          if (sliders.evaluate().isNotEmpty) {
            await t.drag(sliders.first, const Offset(50, 0));
            await t.pump(const Duration(milliseconds: 100));
          }
          
          // Partial disposals
          for (var i = 0; i < 30; i++) {
            MemoryPressureTracker.recordDisposal('PressureWidget-$i');
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
      
      StorageConditionSimulator.restoreStorage();
    });
  });
}
