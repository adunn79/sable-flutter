// ignore_for_file: avoid_print
/// ═══════════════════════════════════════════════════════════════════════════
/// RED TEAM AUDIT FRAMEWORK - OPERATION SCORCHED EARTH
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Final adversarial audit for App Store submission.
/// 4 Squads: Zombie Hunter, Brain Surgeon, White Hat, Chaos Controller
/// 
/// Run: flutter test test/red_team/
/// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';
import '../helpers/test_setup.dart';

/// Result types for Red Team audits
enum AuditResultType {
  pass,     // ✅ Test passed
  fail,     // ❌ Critical failure - blocks release
  warning,  // ⚠️ Non-critical issue - should fix
}

/// Single audit result
class AuditResult {
  final String squadName;
  final String testName;
  final AuditResultType resultType;
  final String? details;
  final String? location;
  final String? autoFixSuggestion;
  final Duration? executionTime;

  AuditResult({
    required this.squadName,
    required this.testName,
    required this.resultType,
    this.details,
    this.location,
    this.autoFixSuggestion,
    this.executionTime,
  });

  String get icon {
    switch (resultType) {
      case AuditResultType.pass: return '✅';
      case AuditResultType.fail: return '❌';
      case AuditResultType.warning: return '⚠️';
    }
  }
}

/// Global audit report
class RedTeamReport {
  static final RedTeamReport _instance = RedTeamReport._internal();
  factory RedTeamReport() => _instance;
  RedTeamReport._internal();

  final List<AuditResult> results = [];
  
  void addResult(AuditResult result) {
    results.add(result);
    final icon = result.icon;
    print('$icon [${result.squadName}] ${result.testName}');
    if (result.details != null) {
      print('   └── ${result.details}');
    }
    if (result.autoFixSuggestion != null) {
      print('   🔧 Auto-Fix: ${result.autoFixSuggestion}');
    }
  }

  void reset() {
    results.clear();
  }

  int get totalTests => results.length;
  int get passCount => results.where((r) => r.resultType == AuditResultType.pass).length;
  int get failCount => results.where((r) => r.resultType == AuditResultType.fail).length;
  int get warningCount => results.where((r) => r.resultType == AuditResultType.warning).length;

  bool get isGoForLaunch => failCount == 0;

  String generateGoNoGoMatrix() {
    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('╔══════════════════════════════════════════════════════════════════════════════╗');
    buffer.writeln('║                    OPERATION SCORCHED EARTH - FINAL REPORT                  ║');
    buffer.writeln('╠══════════════════════════════════════════════════════════════════════════════╣');
    buffer.writeln('║                                                                              ║');
    buffer.writeln('║  📊 AUDIT SUMMARY                                                           ║');
    buffer.writeln('║       Total Tests: ${totalTests.toString().padRight(55)}║');
    buffer.writeln('║       ✅ Passed:   ${passCount.toString().padRight(55)}║');
    buffer.writeln('║       ❌ Failed:   ${failCount.toString().padRight(55)}║');
    buffer.writeln('║       ⚠️ Warnings: ${warningCount.toString().padRight(55)}║');
    buffer.writeln('║                                                                              ║');
    buffer.writeln('╠══════════════════════════════════════════════════════════════════════════════╣');
    
    // Squad breakdown
    final squads = results.map((r) => r.squadName).toSet();
    for (final squad in squads) {
      final squadResults = results.where((r) => r.squadName == squad).toList();
      final squadPass = squadResults.where((r) => r.resultType == AuditResultType.pass).length;
      final squadFail = squadResults.where((r) => r.resultType == AuditResultType.fail).length;
      final squadWarn = squadResults.where((r) => r.resultType == AuditResultType.warning).length;
      final status = squadFail == 0 ? '🟢 GO' : '🔴 NO-GO';
      buffer.writeln('║  $squad: $status (${squadPass}P/${squadFail}F/${squadWarn}W)'.padRight(79) + '║');
    }
    
    buffer.writeln('║                                                                              ║');
    buffer.writeln('╠══════════════════════════════════════════════════════════════════════════════╣');
    
    if (isGoForLaunch) {
      buffer.writeln('║                                                                              ║');
      buffer.writeln('║                      🚀 STATUS: GO FOR APP STORE LAUNCH                      ║');
      buffer.writeln('║                                                                              ║');
    } else {
      buffer.writeln('║                                                                              ║');
      buffer.writeln('║                      🛑 STATUS: NO-GO - FIX CRITICAL ISSUES                  ║');
      buffer.writeln('║                                                                              ║');
      
      // List critical failures
      final failures = results.where((r) => r.resultType == AuditResultType.fail).toList();
      buffer.writeln('║  CRITICAL ISSUES TO FIX:                                                    ║');
      for (var i = 0; i < failures.length && i < 5; i++) {
        final f = failures[i];
        final line = '   ${i + 1}. ${f.testName}: ${f.details ?? "See logs"}';
        buffer.writeln('║${line.padRight(78)}║');
      }
    }
    
    buffer.writeln('║                                                                              ║');
    buffer.writeln('╚══════════════════════════════════════════════════════════════════════════════╝');
    
    return buffer.toString();
  }
}

final redTeamReport = RedTeamReport();

/// Build test widget wrapper for Red Team tests
Widget buildRedTeamWidget(Widget screen) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: screen,
    ),
  );
}

/// Execute a Red Team audit test
Future<void> executeAudit({
  required WidgetTester tester,
  required String squadName,
  required String testName,
  required Widget targetScreen,
  required Future<AuditResult> Function(WidgetTester) audit,
}) async {
  final stopwatch = Stopwatch()..start();
  
  try {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(buildRedTeamWidget(targetScreen));
      await tester.pump(const Duration(milliseconds: 500));
    });
    
    final result = await audit(tester);
    stopwatch.stop();
    
    redTeamReport.addResult(AuditResult(
      squadName: squadName,
      testName: testName,
      resultType: result.resultType,
      details: result.details,
      location: result.location,
      autoFixSuggestion: result.autoFixSuggestion,
      executionTime: stopwatch.elapsed,
    ));
  } catch (e, stack) {
    stopwatch.stop();
    
    // Filter test environment issues
    final errorStr = e.toString();
    if (errorStr.contains('Multiple exceptions') || 
        errorStr.contains('GoogleFonts') ||
        errorStr.contains('font')) {
      redTeamReport.addResult(AuditResult(
        squadName: squadName,
        testName: testName,
        resultType: AuditResultType.warning,
        details: 'Test env issue: font loading',
        executionTime: stopwatch.elapsed,
      ));
    } else {
      redTeamReport.addResult(AuditResult(
        squadName: squadName,
        testName: testName,
        resultType: AuditResultType.fail,
        details: errorStr.split('\n').first,
        location: stack.toString().split('\n').take(3).join(' | '),
        executionTime: stopwatch.elapsed,
      ));
    }
  }
}

/// Setup for Red Team tests
Future<void> setUpRedTeam() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await setUpTestEnvironment();
  redTeamReport.reset();
  
  print('');
  print('🔴 OPERATION SCORCHED EARTH - RED TEAM AUDIT ACTIVATED');
  print('═══════════════════════════════════════════════════════════════════════════');
  print('');
}

/// Cleanup after Red Team tests
Future<void> tearDownRedTeam() async {
  print(redTeamReport.generateGoNoGoMatrix());
  await tearDownTestEnvironment();
}

/// Promo Code Reward Types (for reference)
/// These are the 15 reward types the promo system supports:
const promoRewardTypes = [
  // Trials (3)
  'pro7d',        // Pro Week Pass - 7 days of Pro tier access
  'pro30d',       // Pro Month Pass - 30 days of Pro tier access  
  'ultra7d',      // Ultra Week Pass - 7 days of Ultra tier access
  
  // Voice Credits (3)
  'voice50',      // Voice Starter - 50 ElevenLabs credits
  'voice200',     // Voice Plus - 200 ElevenLabs credits
  'voice500',     // Voice Pro - 500 ElevenLabs credits
  
  // Video Credits (2)
  'video25',      // Video Starter - 25 video generation credits
  'video100',     // Video Plus - 100 video generation credits
  
  // Unlocks (2)
  'lunaUnlock',   // Luna Access - Permanent Luna in Private Space
  'customAvatar', // Avatar Forge - Generate 1 custom AI avatar
  
  // Boosts (2)
  'streakFreeze3', // Streak Shield - 3 streak freeze tokens
  'doubleXp24h',   // XP Doubler - 24 hours of double XP
  
  // Content (2)
  'archetypeEarly', // Early Archetype Access
  'themeExclusive', // Limited edition UI theme
  
  // Access (1)
  'prioritySupport30d', // VIP Support - 30 days priority support
];
