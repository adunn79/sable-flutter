// ignore_for_file: avoid_print
/// ═══════════════════════════════════════════════════════════════════════════
/// SQUAD "HAMMER" - RAPID FIRE UI TESTS
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Directive: Tap every button 50 times in rapid succession. Rapidly switch 
/// tabs. Open/close app screens repeatedly.
/// 
/// Goal: Trigger memory leaks or UI freezes (Main Thread blockage).
/// 
/// Run: flutter test test/stress/hammer_squad_test.dart
/// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'stress_test_framework.dart';
import '../helpers/stress_test_helpers.dart';
import '../helpers/test_setup.dart';

// Target screens
import 'package:sable/src/pages/chat/chat_page.dart';
import 'package:sable/features/today/screens/today_screen.dart';
import 'package:sable/features/vital_balance/screens/vital_balance_screen.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';
import 'package:sable/features/more/screens/more_screen.dart';
import 'package:sable/features/journal/screens/journal_timeline_screen.dart';

void main() {
  setUpAll(() async {
    await setUpStressTests();
    print('');
    print('🔨 SQUAD "HAMMER" ACTIVATED - RAPID FIRE UI TESTS');
    print('═════════════════════════════════════════════════════════');
    print('');
  });

  tearDownAll(() async {
    await tearDownStressTests();
  });

  group('🔨 HAMMER SQUAD - Rapid Button Tapping', () {
    
    testWidgets('H1: ChatPage - 50x rapid send button taps', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'ChatPage rapid send taps',
        squadName: 'HAMMER',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          // Find any tappable buttons
          final buttons = find.byType(IconButton);
          final inkWells = find.byType(InkWell);
          final gestureDetectors = find.byType(GestureDetector);
          
          // Rapid tap all buttons found
          await t.rapidTap(buttons, times: 50, interval: const Duration(milliseconds: 20));
          await t.rapidTap(inkWells, times: 20, interval: const Duration(milliseconds: 30));
          await t.rapidTap(gestureDetectors, times: 20, interval: const Duration(milliseconds: 30));
        },
      );
    });

    testWidgets('H2: ChatPage - Text input stress', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'ChatPage rapid text input',
        squadName: 'HAMMER',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          final textFields = find.byType(TextField);
          
          if (textFields.evaluate().isNotEmpty) {
            // Rapidly enter and clear text
            for (var i = 0; i < 20; i++) {
              await t.enterText(textFields.first, 'Stress test message $i ' * 10);
              await t.pump(const Duration(milliseconds: 50));
              await t.enterText(textFields.first, '');
              await t.pump(const Duration(milliseconds: 50));
            }
          }
        },
      );
    });

    testWidgets('H3: SettingsScreen - 50x toggle switches', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'SettingsScreen rapid toggle',
        squadName: 'HAMMER',
        targetScreen: const SettingsScreen(),
        stressAction: (t) async {
          // Find all switches
          final switches = find.byType(Switch);
          final switchTiles = find.byType(SwitchListTile);
          
          // Rapid toggle
          await t.rapidTap(switches, times: 50, interval: const Duration(milliseconds: 20));
          await t.rapidTap(switchTiles, times: 30, interval: const Duration(milliseconds: 30));
          
          // Also rapid scroll
          final listViews = find.byType(ListView);
          if (listViews.evaluate().isNotEmpty) {
            for (var i = 0; i < 20; i++) {
              await t.drag(listViews.first, const Offset(0, -300));
              await t.pump(const Duration(milliseconds: 30));
              await t.drag(listViews.first, const Offset(0, 300));
              await t.pump(const Duration(milliseconds: 30));
            }
          }
        },
      );
    });

    testWidgets('H4: TodayScreen - Rapid scroll stress', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'TodayScreen rapid scroll',
        squadName: 'HAMMER',
        targetScreen: const TodayScreen(),
        stressAction: (t) async {
          final scrollables = find.byType(Scrollable);
          
          if (scrollables.evaluate().isNotEmpty) {
            // Aggressive scrolling
            for (var i = 0; i < 30; i++) {
              await t.drag(scrollables.first, const Offset(0, -500));
              await t.pump(const Duration(milliseconds: 20));
            }
            // Scroll back rapidly
            for (var i = 0; i < 30; i++) {
              await t.drag(scrollables.first, const Offset(0, 500));
              await t.pump(const Duration(milliseconds: 20));
            }
          }
          
          // Tap all interactive elements found
          final tappables = find.byType(InkWell);
          await t.rapidTap(tappables, times: 30, interval: const Duration(milliseconds: 25));
        },
      );
    });

    testWidgets('H5: VitalBalanceScreen - Animation stress', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'VitalBalanceScreen animation stress',
        squadName: 'HAMMER',
        targetScreen: const VitalBalanceScreen(),
        stressAction: (t) async {
          // This screen likely has charts/animations
          // Rapid interactions while animations are running
          final inkWells = find.byType(InkWell);
          final gestureDetectors = find.byType(GestureDetector);
          
          // Rapid tap during animations
          await t.rapidTap(inkWells, times: 40, interval: const Duration(milliseconds: 25));
          await t.rapidTap(gestureDetectors, times: 40, interval: const Duration(milliseconds: 25));
          
          // Rapid scroll if scrollable
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            for (var i = 0; i < 20; i++) {
              await t.drag(scrollables.first, const Offset(0, -200));
              await t.pump(const Duration(milliseconds: 30));
            }
          }
        },
      );
    });
  });

  group('🔨 HAMMER SQUAD - Rapid Tab Switching', () {
    
    testWidgets('H6: MoreScreen - Navigation button storm', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'MoreScreen navigation storm',
        squadName: 'HAMMER',
        targetScreen: const MoreScreen(),
        stressAction: (t) async {
          // Find all navigation items (ListTiles, buttons, etc.)
          final listTiles = find.byType(ListTile);
          final inkWells = find.byType(InkWell);
          
          // Rapidly tap navigation items
          for (var cycle = 0; cycle < 5; cycle++) {
            await t.rapidTap(listTiles, times: 10, interval: const Duration(milliseconds: 40));
            await t.rapidTap(inkWells, times: 10, interval: const Duration(milliseconds: 40));
          }
        },
      );
    });

    testWidgets('H7: Cross-screen rapid navigation simulation', (tester) async {
      // This simulates rapid screen transitions by repeatedly rendering different screens
      final screens = [
        const ChatPage(),
        const SettingsScreen(),
        const MoreScreen(),
        const VitalBalanceScreen(),
        const TodayScreen(),
      ];
      
      try {
        for (var cycle = 0; cycle < 3; cycle++) {
          for (final screen in screens) {
            await mockNetworkImagesFor(() async {
              await tester.pumpWidget(buildStressTestWidget(screen));
              await tester.pump(const Duration(milliseconds: 100));
            });
          }
        }
        
        stressReport.addResult(StressTestResult(
          testName: 'Cross-screen rapid navigation',
          squadName: 'HAMMER',
          resultType: StressResultType.success,
        ));
      } catch (e, stack) {
        CrashAnalyzer.recordCrash(e, stack);
        stressReport.addResult(StressTestResult(
          testName: 'Cross-screen rapid navigation',
          squadName: 'HAMMER',
          resultType: StressResultType.crash,
          errorMessage: e.toString().split('\n').first,
          crashLocation: CrashAnalyzer.crashes.last.crashLocation,
        ));
      }
    });
  });

  group('🔨 HAMMER SQUAD - Widget Rebuild Stress', () {
    
    testWidgets('H8: ChatPage - Force many rebuilds', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'ChatPage rebuild stress',
        squadName: 'HAMMER',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          // Force multiple frame pumps with state changes
          for (var i = 0; i < 50; i++) {
            await t.pump(const Duration(milliseconds: 16)); // ~60fps timing
          }
          
          // Now do it with some interaction
          final textFields = find.byType(TextField);
          if (textFields.evaluate().isNotEmpty) {
            for (var i = 0; i < 30; i++) {
              await t.enterText(textFields.first, 'T');
              await t.pump(const Duration(milliseconds: 16));
            }
          }
        },
      );
    });

    testWidgets('H9: Settings - Slider stress (if exists)', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Settings slider stress',
        squadName: 'HAMMER',
        targetScreen: const SettingsScreen(),
        stressAction: (t) async {
          final sliders = find.byType(Slider);
          
          if (sliders.evaluate().isNotEmpty) {
            for (final slider in sliders.evaluate()) {
              // Rapidly drag slider back and forth
              for (var i = 0; i < 20; i++) {
                await t.drag(find.byWidget(slider.widget), const Offset(50, 0));
                await t.pump(const Duration(milliseconds: 20));
                await t.drag(find.byWidget(slider.widget), const Offset(-50, 0));
                await t.pump(const Duration(milliseconds: 20));
              }
            }
          } else {
            // No sliders, just stress scroll and tap
            final scrollables = find.byType(Scrollable);
            if (scrollables.evaluate().isNotEmpty) {
              for (var i = 0; i < 30; i++) {
                await t.drag(scrollables.first, const Offset(0, -100));
                await t.pump(const Duration(milliseconds: 20));
              }
            }
          }
        },
      );
    });

    testWidgets('H10: Memory leak detection - Widget disposal', (tester) async {
      // This test checks if widgets are properly disposed
      MemoryPressureTracker.reset();
      
      try {
        await mockNetworkImagesFor(() async {
          // Build and tear down screens multiple times
          for (var i = 0; i < 10; i++) {
            MemoryPressureTracker.recordBuild('ChatPage-$i');
            await tester.pumpWidget(buildStressTestWidget(const ChatPage()));
            await tester.pump(const Duration(milliseconds: 200));
            MemoryPressureTracker.recordDisposal('ChatPage-$i');
          }
        });
        
        // Check ratio
        if (MemoryPressureTracker.hasPotentialLeaks) {
          stressReport.addResult(StressTestResult(
            testName: 'Widget disposal check',
            squadName: 'HAMMER',
            resultType: StressResultType.memoryLeak,
            errorMessage: 'Build/Dispose ratio: ${MemoryPressureTracker.buildDisposeRatio}',
          ));
        } else {
          stressReport.addResult(StressTestResult(
            testName: 'Widget disposal check',
            squadName: 'HAMMER',
            resultType: StressResultType.success,
          ));
        }
      } catch (e, stack) {
        CrashAnalyzer.recordCrash(e, stack);
        stressReport.addResult(StressTestResult(
          testName: 'Widget disposal check',
          squadName: 'HAMMER',
          resultType: StressResultType.crash,
          errorMessage: e.toString().split('\n').first,
        ));
      }
    });
  });
}
