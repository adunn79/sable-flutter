// ignore_for_file: avoid_print
/// ═══════════════════════════════════════════════════════════════════════════
/// OPERATION BREAKPOINT - STRESS TEST FRAMEWORK
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Core framework for parallel hostile testing:
/// - Coordinates multiple test "squads" with different attack vectors
/// - Aggregates results across all stress scenarios
/// - Generates auto-heal recommendations for identified issues
/// 
/// Run all stress tests: flutter test test/stress/
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/stress_test_helpers.dart';
import '../helpers/test_setup.dart';

/// Standard test timeout for stress tests (longer than normal)
const Duration stressTestTimeout = Duration(seconds: 30);

/// Threshold for UI freeze detection
const Duration freezeThreshold = Duration(seconds: 2);

/// Result categories for stress tests
enum StressResultType {
  crash,    // Unhandled exception
  freeze,   // UI unresponsive > 2.0s
  dataLoss, // User input not saved
  memoryLeak, // Build/dispose ratio off
  success,  // No issues detected
}

/// Individual stress test result
class StressTestResult {
  final String testName;
  final String squadName;
  final StressResultType resultType;
  final String? errorMessage;
  final String? stackTrace;
  final String? crashLocation;
  final Duration executionTime;
  final Map<String, dynamic> metrics;
  
  StressTestResult({
    required this.testName,
    required this.squadName,
    required this.resultType,
    this.errorMessage,
    this.stackTrace,
    this.crashLocation,
    this.executionTime = Duration.zero,
    this.metrics = const {},
  });
  
  bool get isFailure => resultType != StressResultType.success;
  
  String get icon {
    switch (resultType) {
      case StressResultType.crash:
        return '💥';
      case StressResultType.freeze:
        return '🧊';
      case StressResultType.dataLoss:
        return '💾';
      case StressResultType.memoryLeak:
        return '🔴';
      case StressResultType.success:
        return '✅';
    }
  }
  
  @override
  String toString() {
    return '$icon [$squadName] $testName${errorMessage != null ? ': $errorMessage' : ''}';
  }
}

/// Aggregates all stress test results for final reporting
class StressTestReport {
  final List<StressTestResult> results = [];
  final DateTime startTime = DateTime.now();
  DateTime? endTime;
  
  void addResult(StressTestResult result) {
    results.add(result);
    print(result.toString());
  }
  
  int get totalTests => results.length;
  int get crashes => results.where((r) => r.resultType == StressResultType.crash).length;
  int get freezes => results.where((r) => r.resultType == StressResultType.freeze).length;
  int get dataLosses => results.where((r) => r.resultType == StressResultType.dataLoss).length;
  int get memoryLeaks => results.where((r) => r.resultType == StressResultType.memoryLeak).length;
  int get successes => results.where((r) => r.resultType == StressResultType.success).length;
  
  bool get hasFailures => crashes > 0 || freezes > 0 || dataLosses > 0 || memoryLeaks > 0;
  
  String generateReport() {
    endTime = DateTime.now();
    final duration = endTime!.difference(startTime);
    
    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('╔══════════════════════════════════════════════════════════════════════════════╗');
    buffer.writeln('║               OPERATION BREAKPOINT - STRESS TEST REPORT                      ║');
    buffer.writeln('╠══════════════════════════════════════════════════════════════════════════════╣');
    buffer.writeln('║ Execution Time: ${duration.inSeconds}s                                                          ║');
    buffer.writeln('║ Total Tests:    $totalTests                                                              ║');
    buffer.writeln('╠══════════════════════════════════════════════════════════════════════════════╣');
    buffer.writeln('║ 💥 CRASHES:     $crashes                                                              ║');
    buffer.writeln('║ 🧊 FREEZES:     $freezes                                                              ║');
    buffer.writeln('║ 💾 DATA LOSS:   $dataLosses                                                              ║');
    buffer.writeln('║ 🔴 MEM LEAKS:   $memoryLeaks                                                              ║');
    buffer.writeln('║ ✅ SUCCESS:     $successes                                                              ║');
    buffer.writeln('╠══════════════════════════════════════════════════════════════════════════════╣');
    
    if (!hasFailures) {
      buffer.writeln('║ 🎉 STATUS: ALL STRESS TESTS PASSED - APP IS RESILIENT                        ║');
    } else {
      buffer.writeln('║ ⚠️  STATUS: ISSUES FOUND - REVIEW FAILURES BELOW                              ║');
    }
    buffer.writeln('╚══════════════════════════════════════════════════════════════════════════════╝');
    
    // List failures
    if (hasFailures) {
      buffer.writeln('');
      buffer.writeln('🔴 FAILURES REQUIRING ATTENTION:');
      buffer.writeln('');
      
      for (final result in results.where((r) => r.isFailure)) {
        buffer.writeln('  ${result.icon} [${result.squadName}] ${result.testName}');
        if (result.crashLocation != null) {
          buffer.writeln('     📍 Location: ${result.crashLocation}');
        }
        if (result.errorMessage != null) {
          buffer.writeln('     └── ${result.errorMessage}');
        }
      }
      
      // Auto-heal recommendations
      buffer.writeln('');
      buffer.writeln('🩹 AUTO-HEAL RECOMMENDATIONS:');
      buffer.writeln('');
      
      for (final recommendation in CrashAnalyzer.generateRecommendations()) {
        buffer.writeln('  📍 ${recommendation.location}');
        buffer.writeln('     Issue: ${recommendation.issue}');
        buffer.writeln('     Fix: ${recommendation.fix}');
        buffer.writeln('');
      }
    }
    
    return buffer.toString();
  }
}

/// Global report instance
final stressReport = StressTestReport();

/// Standard testable widget wrapper with providers
Widget buildStressTestWidget(Widget child, {Size screenSize = const Size(375, 812)}) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: child,
      ),
    ),
  );
}

/// Execute a stress test with proper error handling and reporting
Future<void> executeStressTest({
  required WidgetTester tester,
  required String testName,
  required String squadName,
  required Widget targetScreen,
  required Future<void> Function(WidgetTester tester) stressAction,
  Duration timeout = stressTestTimeout,
  bool trackMemory = true,
}) async {
  final stopwatch = Stopwatch()..start();
  
  if (trackMemory) {
    MemoryPressureTracker.reset();
  }
  
  try {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(buildStressTestWidget(targetScreen));
      await tester.pump(const Duration(milliseconds: 500));
      
      // Execute the stress action
      await stressAction(tester);
      
      // Pump frames to let things settle
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    
    // Check for exceptions (filter out font loading errors which are test env issues)
    final exception = tester.takeException();
    if (exception != null) {
      final errorStr = exception.toString();
      if (!errorStr.contains('GoogleFonts') && 
          !errorStr.contains('Failed to load font') &&
          !errorStr.contains('font was not found')) {
        throw exception;
      }
      // Font loading errors are ignored - they're test environment issues, not app crashes
      print('   ⚠️ Font loading warning (test env issue, not app crash)');
    }
    
    stopwatch.stop();
    
    // Check for freezes
    if (UIResponseTimer.hadFreezes) {
      stressReport.addResult(StressTestResult(
        testName: testName,
        squadName: squadName,
        resultType: StressResultType.freeze,
        errorMessage: 'UI freeze detected: ${UIResponseTimer.longestOperation.inMilliseconds}ms',
        executionTime: stopwatch.elapsed,
      ));
      return;
    }
    
    // Check for memory leaks
    if (trackMemory && MemoryPressureTracker.hasPotentialLeaks) {
      stressReport.addResult(StressTestResult(
        testName: testName,
        squadName: squadName,
        resultType: StressResultType.memoryLeak,
        errorMessage: 'Potential leak: ${MemoryPressureTracker.buildDisposeRatio.toStringAsFixed(2)} build/dispose ratio',
        executionTime: stopwatch.elapsed,
      ));
      return;
    }
    
    // Success!
    stressReport.addResult(StressTestResult(
      testName: testName,
      squadName: squadName,
      resultType: StressResultType.success,
      executionTime: stopwatch.elapsed,
    ));
    
  } catch (e, stack) {
    stopwatch.stop();
    
    // Record crash
    CrashAnalyzer.recordCrash(e, stack);
    
    stressReport.addResult(StressTestResult(
      testName: testName,
      squadName: squadName,
      resultType: StressResultType.crash,
      errorMessage: e.toString().split('\n').first,
      stackTrace: stack.toString(),
      crashLocation: CrashAnalyzer.crashes.last.crashLocation,
      executionTime: stopwatch.elapsed,
    ));
  }
}

/// Setup for stress tests - call in setUpAll
Future<void> setUpStressTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Enable Google Fonts runtime fetching to prevent font loading errors
  GoogleFonts.config.allowRuntimeFetching = true;
  
  // Mock SharedPreferences
  SharedPreferences.setMockInitialValues({});
  
  await setUpTestEnvironment();
  resetAllStressUtilities();
}

/// Cleanup after stress tests - call in tearDownAll
Future<void> tearDownStressTests() async {
  print(stressReport.generateReport());
  print(MemoryPressureTracker.report);
  print(UIResponseTimer.report);
  print(CrashAnalyzer.report);
  await tearDownTestEnvironment();
}
