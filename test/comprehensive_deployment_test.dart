// ignore_for_file: avoid_print
/// COMPREHENSIVE DEPLOYMENT TEST SUITE
/// Tests ALL screens in the Aeliana AI app for deployment readiness
/// 
/// This test validates:
/// - All screens render without crashes
/// - No overflow errors
/// - Basic structure exists (Scaffold)
/// - Critical elements are present
/// 
/// Run with: flutter test test/comprehensive_deployment_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';

// Feature Screens (excluding those with missing dependencies)
import 'package:sable/features/clock/screens/alarm_screen.dart';
import 'package:sable/features/clock/screens/clock_mode_screen.dart';
// Note: PrescriptionListScreen, DocumentScanScreen excluded - need google_mlkit package
import 'package:sable/features/journal/screens/gratitude_mode_screen.dart';
import 'package:sable/features/journal/screens/insights_dashboard_screen.dart';
import 'package:sable/features/journal/screens/journal_calendar_screen.dart';
import 'package:sable/features/journal/screens/journal_timeline_screen.dart';
import 'package:sable/features/journal/screens/knowledge_center_screen.dart';
import 'package:sable/features/journal/screens/voice_journaling_screen.dart';
import 'package:sable/features/local_vibe/widgets/local_vibe_settings_screen.dart';
import 'package:sable/features/more/screens/about_screen.dart';
import 'package:sable/features/more/screens/help_support_screen.dart';
import 'package:sable/features/more/screens/more_screen.dart';
import 'package:sable/features/onboarding/screens/access_denied_screen.dart';
import 'package:sable/features/onboarding/screens/screen_1_calibration.dart';
import 'package:sable/features/onboarding/screens/screen_2_protocol.dart';
import 'package:sable/features/onboarding/screens/screen_3_archetype.dart';
import 'package:sable/features/onboarding/screens/screen_4_customize.dart';
import 'package:sable/features/private_space/screens/private_space_lock_screen.dart';
import 'package:sable/features/safety/screens/emergency_screen.dart';
import 'package:sable/features/settings/screens/avatar_gallery_screen.dart';
import 'package:sable/features/settings/screens/settings_screen.dart';
import 'package:sable/features/settings/screens/vault_screen.dart';
import 'package:sable/features/splash/splash_screen.dart';
import 'package:sable/features/subscription/screens/subscription_screen.dart';
import 'package:sable/features/today/screens/today_screen.dart';
// Note: HealthDashboard, LabResults, MedicationManager excluded - depend on MLKit
import 'package:sable/features/vital_balance/screens/vital_balance_screen.dart';

// Core Pages
import 'package:sable/src/pages/chat/chat_page.dart';

/// Test result tracking
class DeploymentResult {
  final String screenName;
  final bool passed;
  final String? error;
  
  DeploymentResult({required this.screenName, required this.passed, this.error});
}

/// Global results collection
final List<DeploymentResult> results = [];

/// Wrap widget in testable providers
Widget _testable(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// Test a screen with common checks
Future<void> _testScreen(
  WidgetTester tester,
  String name,
  Widget screen, {
  int pumpFrames = 3,
}) async {
  try {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_testable(screen));
      
      // Pump multiple frames for complex screens with animations
      for (int i = 0; i < pumpFrames; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    });
    
    // Check for render exceptions
    final exception = tester.takeException();
    if (exception != null) {
      throw exception;
    }
    
    // Verify basic structure
    expect(find.byType(Scaffold), findsAtLeast(1));
    
    results.add(DeploymentResult(screenName: name, passed: true));
    print('✅ $name');
  } catch (e) {
    results.add(DeploymentResult(screenName: name, passed: false, error: '$e'));
    print('❌ $name: $e');
    rethrow;
  }
}

void main() {
  group('📱 COMPREHENSIVE DEPLOYMENT TEST SUITE', () {
    
    // ========== PRIORITY P0: MAIN NAVIGATION ==========
    
    testWidgets('P0: ChatPage', (t) async {
      await _testScreen(t, 'ChatPage', const ChatPage(), pumpFrames: 5);
    });
    
    testWidgets('P0: SettingsScreen', (t) async {
      await _testScreen(t, 'SettingsScreen', const SettingsScreen());
    });
    
    testWidgets('P0: MoreScreen', (t) async {
      await _testScreen(t, 'MoreScreen', const MoreScreen());
    });
    
    testWidgets('P0: TodayScreen', (t) async {
      await _testScreen(t, 'TodayScreen', const TodayScreen());
    });
    
    testWidgets('P0: VitalBalanceScreen', (t) async {
      await _testScreen(t, 'VitalBalanceScreen', const VitalBalanceScreen());
    });
    
    testWidgets('P0: JournalTimelineScreen', (t) async {
      await _testScreen(t, 'JournalTimelineScreen', const JournalTimelineScreen());
    });
    
    // ========== PRIORITY P1: ONBOARDING ==========
    
    testWidgets('P1: AelianaSplashScreen', (t) async {
      await _testScreen(t, 'SplashScreen', const AelianaSplashScreen());
    });
    
    testWidgets('P1: CalibrationScreen', (t) async {
      await _testScreen(t, 'CalibrationScreen', CalibrationScreen(onComplete: () {}));
    });
    
    testWidgets('P1: ProtocolScreen', (t) async {
      await _testScreen(t, 'ProtocolScreen', ProtocolScreen(onAccept: () {}));
    });
    
    testWidgets('P1: ArchetypeScreen', (t) async {
      await _testScreen(t, 'ArchetypeScreen', ArchetypeScreen(onComplete: (_) {}));
    });
    
    testWidgets('P1: CustomizeScreen', (t) async {
      await _testScreen(t, 'CustomizeScreen', CustomizeScreen(onComplete: () {}));
    });
    
    testWidgets('P1: AccessDeniedScreen', (t) async {
      await _testScreen(t, 'AccessDeniedScreen', const AccessDeniedScreen());
    });
    
    // ========== PRIORITY P1: SUBSCRIPTION & VAULT ==========
    
    testWidgets('P1: SubscriptionScreen', (t) async {
      await _testScreen(t, 'SubscriptionScreen', const SubscriptionScreen());
    });
    
    testWidgets('P1: VaultScreen', (t) async {
      await _testScreen(t, 'VaultScreen', const VaultScreen());
    });
    
    // ========== PRIORITY P1: INFO & HELP ==========
    
    testWidgets('P1: AboutScreen', (t) async {
      await _testScreen(t, 'AboutScreen', const AboutScreen());
    });
    
    testWidgets('P1: HelpSupportScreen', (t) async {
      await _testScreen(t, 'HelpSupportScreen', const HelpSupportScreen());
    });
    
    testWidgets('P1: EmergencyScreen', (t) async {
      await _testScreen(t, 'EmergencyScreen', const EmergencyScreen());
    });
    
    // ========== PRIORITY P2: JOURNAL ==========
    
    testWidgets('P2: JournalCalendarScreen', (t) async {
      await _testScreen(t, 'JournalCalendarScreen', const JournalCalendarScreen());
    });
    
    testWidgets('P2: InsightsDashboardScreen', (t) async {
      await _testScreen(t, 'InsightsDashboardScreen', const InsightsDashboardScreen());
    });
    
    testWidgets('P2: KnowledgeCenterScreen', (t) async {
      await _testScreen(t, 'KnowledgeCenterScreen', const KnowledgeCenterScreen());
    });
    
    testWidgets('P2: GratitudeModeScreen', (t) async {
      await _testScreen(t, 'GratitudeModeScreen', const GratitudeModeScreen());
    });
    
    testWidgets('P2: VoiceJournalingScreen', (t) async {
      await _testScreen(t, 'VoiceJournalingScreen', const VoiceJournalingScreen());
    });
    
    // ========== PRIORITY P2: HEALTH ==========
    // NOTE: HealthDashboardScreen, LabResultsScreen, MedicationManagerScreen, 
    //       PrescriptionListScreen excluded - require google_mlkit_text_recognition
    //       which is not in pubspec.yaml. Add these packages to enable health scanning.
    
    // ========== PRIORITY P2: CLOCK ==========
    
    testWidgets('P2: ClockModeScreen', (t) async {
      await _testScreen(t, 'ClockModeScreen', ClockModeScreen(onBack: () {}));
    });
    
    testWidgets('P2: AlarmScreen', (t) async {
      await _testScreen(t, 'AlarmScreen', const AlarmScreen());
    });
    
    // ========== PRIORITY P2: SETTINGS & CUSTOMIZATION ==========
    
    testWidgets('P2: AvatarGalleryScreen', (t) async {
      await _testScreen(t, 'AvatarGalleryScreen', const AvatarGalleryScreen());
    });
    
    testWidgets('P2: LocalVibeSettingsScreen', (t) async {
      await _testScreen(t, 'LocalVibeSettingsScreen', const LocalVibeSettingsScreen());
    });
    
    // ========== PRIORITY P3: PRIVATE SPACE ==========
    
    testWidgets('P3: PrivateSpaceLockScreen', (t) async {
      await _testScreen(t, 'PrivateSpaceLockScreen', PrivateSpaceLockScreen(onUnlock: () {}));
    });

    // ========== SUMMARY ==========
    
    tearDownAll(() {
      final passed = results.where((r) => r.passed).length;
      final failed = results.where((r) => !r.passed).length;
      final total = results.length;
      
      print('');
      print('╔════════════════════════════════════════════════════════════╗');
      print('║      COMPREHENSIVE DEPLOYMENT TEST RESULTS                 ║');
      print('╠════════════════════════════════════════════════════════════╣');
      print('║  Total Screens Tested: ${total.toString().padLeft(3)}                               ║');
      print('║  Passed:              ${passed.toString().padLeft(3)} ✅                            ║');
      print('║  Failed:              ${failed.toString().padLeft(3)} ❌                            ║');
      print('╠════════════════════════════════════════════════════════════╣');
      
      if (failed == 0) {
        print('║  STATUS: ✅ APP STORE READY                               ║');
      } else {
        print('║  STATUS: ❌ NEEDS FIXES                                   ║');
      }
      print('╚════════════════════════════════════════════════════════════╝');
      
      if (failed > 0) {
        print('');
        print('🔴 FAILED SCREENS:');
        for (final r in results.where((r) => !r.passed)) {
          print('  ❌ ${r.screenName}');
          if (r.error != null && r.error!.length < 100) {
            print('     └── ${r.error}');
          }
        }
      }
    });
  });
}
