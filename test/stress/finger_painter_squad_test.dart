// ignore_for_file: avoid_print
/// ═══════════════════════════════════════════════════════════════════════════
/// SQUAD "FINGER PAINTER" - GESTURE CHAOS TESTS
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Directive: Input chaos:
/// - Multi-touch gestures (3 fingers) on screens designed for single taps
/// - Swipe diagonally on horizontal scrollers
/// - Rotate device orientation continuously
/// 
/// Goal: Break the layout engine and navigation stack.
/// 
/// Run: flutter test test/stress/finger_painter_squad_test.dart
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
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
    print('🎨 SQUAD "FINGER PAINTER" ACTIVATED - GESTURE CHAOS TESTS');
    print('═════════════════════════════════════════════════════════');
    print('');
  });

  tearDownAll(() async {
    await tearDownStressTests();
  });

  group('🎨 FINGER PAINTER SQUAD - Multi-Touch Chaos', () {
    
    testWidgets('F1: ChatPage - Diagonal swipes on text input', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'ChatPage diagonal swipes',
        squadName: 'FINGER PAINTER',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          await t.pump(const Duration(milliseconds: 500));
          
          // Perform diagonal swipes across the screen
          for (var i = 0; i < 10; i++) {
            await t.dragFrom(
              const Offset(50, 200),
              const Offset(250, 400), // Diagonal down-right
            );
            await t.pump(const Duration(milliseconds: 50));
            
            await t.dragFrom(
              const Offset(300, 500),
              const Offset(50, 100), // Diagonal up-left
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });

    testWidgets('F2: TodayScreen - Chaos gestures on calendar area', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'TodayScreen gesture chaos',
        squadName: 'FINGER PAINTER',
        targetScreen: const TodayScreen(),
        stressAction: (t) async {
          await t.pump(const Duration(milliseconds: 500));
          
          // Random gesture chaos
          await t.gestureChaos(
            const Rect.fromLTWH(0, 100, 375, 500),
            gestures: 20,
          );
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });

    testWidgets('F3: VitalBalanceScreen - Swipe during animations', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'VitalBalance gesture + animation',
        squadName: 'FINGER PAINTER',
        targetScreen: const VitalBalanceScreen(),
        stressAction: (t) async {
          // Let animations start
          await t.pump(const Duration(milliseconds: 300));
          
          // Gesture chaos while animations are running
          for (var i = 0; i < 15; i++) {
            await t.dragFrom(
              Offset(50.0 + i * 10, 200.0 + i * 10),
              Offset(100.0 + i * 10, 300.0 + i * 10),
            );
            await t.pump(const Duration(milliseconds: 30));
          }
          
          // Let animations settle
          await t.pump(const Duration(milliseconds: 500));
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });
  });

  group('🎨 FINGER PAINTER SQUAD - Orientation Changes', () {
    
    testWidgets('F4: ChatPage - Rapid orientation changes', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'ChatPage orientation chaos',
        squadName: 'FINGER PAINTER',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          // Rapid orientation changes
          for (var i = 0; i < 10; i++) {
            await t.rotateScreen();
          }
          
          // After all rotations, should still be functional
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });

    testWidgets('F5: TodayScreen - Orientation mid-scroll', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'TodayScreen orientation mid-scroll',
        squadName: 'FINGER PAINTER',
        targetScreen: const TodayScreen(),
        stressAction: (t) async {
          final scrollables = find.byType(Scrollable);
          
          for (var i = 0; i < 5; i++) {
            // Start scrolling
            if (scrollables.evaluate().isNotEmpty) {
              await t.drag(scrollables.first, const Offset(0, -100));
              await t.pump(const Duration(milliseconds: 50));
            }
            
            // Rotate mid-scroll
            await t.rotateScreen();
            
            // Continue scrolling
            if (scrollables.evaluate().isNotEmpty) {
              await t.drag(scrollables.first, const Offset(0, -100));
              await t.pump(const Duration(milliseconds: 50));
            }
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });

    testWidgets('F6: SettingsScreen - Orientation during toggle', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Settings orientation mid-toggle',
        squadName: 'FINGER PAINTER',
        targetScreen: const SettingsScreen(),
        stressAction: (t) async {
          final switches = find.byType(Switch);
          
          if (switches.evaluate().isNotEmpty) {
            for (var i = 0; i < 5; i++) {
              // Tap switch
              await t.tap(switches.first, warnIfMissed: false);
              await t.pump(const Duration(milliseconds: 50));
              
              // Immediately rotate
              await t.rotateScreen();
            }
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });
  });

  group('🎨 FINGER PAINTER SQUAD - Edge Swipes', () {
    
    testWidgets('F7: Edge swipe conflicts with navigation', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Edge swipe navigation conflict',
        squadName: 'FINGER PAINTER',
        targetScreen: const MoreScreen(),
        stressAction: (t) async {
          await t.pump(const Duration(milliseconds: 500));
          
          // Left edge swipes (iOS back gesture area)
          for (var i = 0; i < 10; i++) {
            await t.dragFrom(
              const Offset(5, 400), // Near left edge
              const Offset(200, 400),
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          
          // Right edge swipes
          for (var i = 0; i < 10; i++) {
            await t.dragFrom(
              const Offset(370, 400), // Near right edge
              const Offset(100, 400),
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });

    testWidgets('F8: Top/Bottom edge swipes', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Top/Bottom edge swipes',
        squadName: 'FINGER PAINTER',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          await t.pump(const Duration(milliseconds: 500));
          
          // Top edge swipes (notification center area)
          for (var i = 0; i < 5; i++) {
            await t.dragFrom(
              const Offset(187, 10), // Near top edge
              const Offset(187, 300),
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          
          // Bottom edge swipes (home indicator area)
          for (var i = 0; i < 5; i++) {
            await t.dragFrom(
              const Offset(187, 800), // Near bottom
              const Offset(187, 500),
            );
            await t.pump(const Duration(milliseconds: 50));
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });
  });

  group('🎨 FINGER PAINTER SQUAD - Conflicting Gestures', () {
    
    testWidgets('F9: Tap while scrolling', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Tap while scrolling',
        squadName: 'FINGER PAINTER',
        targetScreen: const TodayScreen(),
        stressAction: (t) async {
          await t.pump(const Duration(milliseconds: 500));
          
          final scrollables = find.byType(Scrollable);
          final inkWells = find.byType(InkWell);
          
          // Alternate between scrolling and tapping
          for (var i = 0; i < 10; i++) {
            if (scrollables.evaluate().isNotEmpty) {
              await t.drag(scrollables.first, const Offset(0, -50));
              await t.pump(const Duration(milliseconds: 20));
            }
            
            if (inkWells.evaluate().isNotEmpty) {
              await t.tap(inkWells.first, warnIfMissed: false);
              await t.pump(const Duration(milliseconds: 20));
            }
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });

    testWidgets('F10: Long press during drag', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Long press during drag',
        squadName: 'FINGER PAINTER',
        targetScreen: const ChatPage(),
        stressAction: (t) async {
          await t.pump(const Duration(milliseconds: 500));
          
          // Simulate conflicting gestures
          for (var i = 0; i < 5; i++) {
            // Start a drag
            await t.dragFrom(
              const Offset(100, 300),
              const Offset(200, 300),
            );
            await t.pump(const Duration(milliseconds: 50));
            
            // Long press in another location
            await t.longPress(find.byType(Scaffold).first);
            await t.pump(const Duration(milliseconds: 100));
          }
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });
  });

  group('🎨 FINGER PAINTER SQUAD - Layout Stress', () {
    
    testWidgets('F11: Extreme size changes', (tester) async {
      try {
        await mockNetworkImagesFor(() async {
          final sizes = [
            const Size(375, 812),  // iPhone Portrait
            const Size(812, 375),  // iPhone Landscape
            const Size(1024, 768), // iPad Portrait
            const Size(768, 1024), // iPad Landscape
            const Size(320, 568),  // iPhone SE
            const Size(428, 926),  // iPhone Pro Max
          ];
          
          for (final size in sizes) {
            await tester.pumpWidget(
              buildStressTestWidget(const ChatPage(), screenSize: size),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
        });
        
        stressReport.addResult(StressTestResult(
          testName: 'Extreme size changes',
          squadName: 'FINGER PAINTER',
          resultType: StressResultType.success,
        ));
      } catch (e, stack) {
        CrashAnalyzer.recordCrash(e, stack);
        stressReport.addResult(StressTestResult(
          testName: 'Extreme size changes',
          squadName: 'FINGER PAINTER',
          resultType: StressResultType.crash,
          errorMessage: e.toString().split('\n').first,
        ));
      }
    });

    testWidgets('F12: Size change mid-animation', (tester) async {
      await executeStressTest(
        tester: tester,
        testName: 'Size change mid-animation',
        squadName: 'FINGER PAINTER',
        targetScreen: const VitalBalanceScreen(),
        stressAction: (t) async {
          // Let animations start
          await t.pump(const Duration(milliseconds: 200));
          
          // Change size multiple times during animation
          for (var i = 0; i < 5; i++) {
            await t.binding.setSurfaceSize(const Size(375, 812));
            await t.pump(const Duration(milliseconds: 100));
            await t.binding.setSurfaceSize(const Size(812, 375));
            await t.pump(const Duration(milliseconds: 100));
          }
          
          // Reset to normal
          await t.binding.setSurfaceSize(const Size(375, 812));
          await t.pump(const Duration(milliseconds: 500));
          
          expect(find.byType(Scaffold), findsAtLeast(1));
        },
      );
    });
  });
}
