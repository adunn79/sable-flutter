// ignore_for_file: avoid_print
/// STRESS TEST HELPER UTILITIES
/// 
/// Provides simulation utilities for hostile testing conditions:
/// - Network failure simulation
/// - Storage exhaustion simulation
/// - Memory pressure tracking
/// - UI responsiveness measurement
/// - Crash stack trace analysis

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Simulates network conditions for stress testing
class NetworkConditionSimulator {
  static bool _isNetworkDisabled = false;
  static Duration? _artificialLatency;
  
  /// Cut all network connectivity
  static void disableNetwork() {
    _isNetworkDisabled = true;
  }
  
  /// Restore network connectivity
  static void enableNetwork() {
    _isNetworkDisabled = false;
    _artificialLatency = null;
  }
  
  /// Add artificial latency to all requests
  static void setLatency(Duration latency) {
    _artificialLatency = latency;
  }
  
  /// Check if network simulation is active
  static bool get isNetworkDisabled => _isNetworkDisabled;
  static Duration? get artificialLatency => _artificialLatency;
  
  /// Simulate network chaos during a callback
  static Future<T> withNetworkChaos<T>({
    required Future<T> Function() operation,
    Duration? latency,
    bool disconnectMidway = false,
    double failureChance = 0.0,
  }) async {
    if (latency != null) {
      await Future.delayed(latency);
    }
    
    if (failureChance > 0 && DateTime.now().millisecond % 100 < failureChance * 100) {
      throw const SocketException('Network connection failed (simulated)');
    }
    
    if (disconnectMidway) {
      // Start operation, then cut it off
      final completer = Completer<T>();
      Timer(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted) {
          completer.completeError(
            const SocketException('Connection lost mid-transfer (simulated)')
          );
        }
      });
      
      operation().then((result) {
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }).catchError((error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });
      
      return completer.future;
    }
    
    return operation();
  }
}

/// Simulates storage exhaustion conditions
class StorageConditionSimulator {
  static bool _isStorageFull = false;
  
  /// Simulate storage being full
  static void simulateFullStorage() {
    _isStorageFull = true;
  }
  
  /// Restore normal storage
  static void restoreStorage() {
    _isStorageFull = false;
  }
  
  /// Check if storage is simulated as full
  static bool get isStorageFull => _isStorageFull;
  
  /// Wrap a write operation to fail if storage is "full"
  static Future<void> guardedWrite(Future<void> Function() writeOperation) async {
    if (_isStorageFull) {
      throw const FileSystemException('No space left on device (simulated)');
    }
    await writeOperation();
  }
}

/// Tracks memory allocations and potential leaks during tests
class MemoryPressureTracker {
  static final List<String> _allocations = [];
  static int _widgetBuildCount = 0;
  static int _disposalCount = 0;
  
  /// Record a widget build
  static void recordBuild(String widgetName) {
    _widgetBuildCount++;
    _allocations.add('BUILD: $widgetName at ${DateTime.now()}');
  }
  
  /// Record a widget disposal
  static void recordDisposal(String widgetName) {
    _disposalCount++;
    _allocations.add('DISPOSE: $widgetName at ${DateTime.now()}');
  }
  
  /// Get build/dispose ratio (should be close to 1.0 for no leaks)
  static double get buildDisposeRatio {
    if (_widgetBuildCount == 0) return 1.0;
    return _disposalCount / _widgetBuildCount;
  }
  
  /// Check for potential memory leaks
  static bool get hasPotentialLeaks {
    // If we have significantly more builds than disposals, potential leak
    return _widgetBuildCount - _disposalCount > 5;
  }
  
  /// Get memory tracking report
  static String get report {
    return '''
╔═══════════════════════════════════════════╗
║           MEMORY PRESSURE REPORT          ║
╠═══════════════════════════════════════════╣
║ Widget Builds:  $_widgetBuildCount
║ Widget Disposals: $_disposalCount
║ Build/Dispose Ratio: ${buildDisposeRatio.toStringAsFixed(2)}
║ Potential Leaks: ${hasPotentialLeaks ? '⚠️ YES' : '✅ NO'}
╚═══════════════════════════════════════════╝
''';
  }
  
  /// Reset tracking
  static void reset() {
    _allocations.clear();
    _widgetBuildCount = 0;
    _disposalCount = 0;
  }
}

/// Measures UI responsiveness and detects freezes
class UIResponseTimer {
  static final Stopwatch _stopwatch = Stopwatch();
  static Duration _freezeThreshold = const Duration(seconds: 2);
  static final List<Duration> _frameTimes = [];
  
  /// Set the threshold for what counts as a "freeze"
  static void setFreezeThreshold(Duration threshold) {
    _freezeThreshold = threshold;
  }
  
  /// Start timing a UI operation
  static void startMeasurement() {
    _stopwatch.reset();
    _stopwatch.start();
  }
  
  /// Stop timing and record the measurement
  static Duration stopMeasurement() {
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed;
    _frameTimes.add(elapsed);
    return elapsed;
  }
  
  /// Check if the last operation caused a freeze
  static bool get wasFreeze => _stopwatch.elapsed > _freezeThreshold;
  
  /// Get the longest recorded operation time
  static Duration get longestOperation {
    if (_frameTimes.isEmpty) return Duration.zero;
    return _frameTimes.reduce((a, b) => a > b ? a : b);
  }
  
  /// Get average operation time
  static Duration get averageOperationTime {
    if (_frameTimes.isEmpty) return Duration.zero;
    final totalMs = _frameTimes.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ _frameTimes.length);
  }
  
  /// Check if any freezes were detected
  static bool get hadFreezes {
    return _frameTimes.any((d) => d > _freezeThreshold);
  }
  
  /// Get responsiveness report
  static String get report {
    return '''
╔═══════════════════════════════════════════╗
║         UI RESPONSIVENESS REPORT          ║
╠═══════════════════════════════════════════╣
║ Operations Measured: ${_frameTimes.length}
║ Average Time: ${averageOperationTime.inMilliseconds}ms
║ Longest Time: ${longestOperation.inMilliseconds}ms
║ Freeze Threshold: ${_freezeThreshold.inMilliseconds}ms
║ Freezes Detected: ${hadFreezes ? '⚠️ YES' : '✅ NO'}
╚═══════════════════════════════════════════╝
''';
  }
  
  /// Reset all measurements
  static void reset() {
    _stopwatch.reset();
    _frameTimes.clear();
  }
}

/// Analyzes crash stack traces and recommends safeguards
class CrashAnalyzer {
  static final List<CrashReport> _crashes = [];
  
  /// Record a crash with its stack trace
  static void recordCrash(Object error, StackTrace stackTrace) {
    final report = CrashReport(
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      crashLocation: _extractCrashLocation(stackTrace),
    );
    _crashes.add(report);
    print('🔴 CRASH RECORDED: ${report.crashLocation}');
    print('   Error: ${error.toString().split('\n').first}');
  }
  
  /// Extract the crash location from stack trace
  static String _extractCrashLocation(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    for (final line in lines) {
      // Look for lines with our app code (package:sable)
      if (line.contains('package:sable/')) {
        final match = RegExp(r'package:sable/(.+):(\d+)').firstMatch(line);
        if (match != null) {
          return 'lib/${match.group(1)}:${match.group(2)}';
        }
      }
    }
    return lines.isNotEmpty ? lines.first : 'Unknown location';
  }
  
  /// Get all recorded crashes
  static List<CrashReport> get crashes => List.unmodifiable(_crashes);
  
  /// Check if any crashes were recorded
  static bool get hasCrashes => _crashes.isNotEmpty;
  
  /// Generate safeguard recommendations for recorded crashes
  static List<SafeguardRecommendation> generateRecommendations() {
    final recommendations = <SafeguardRecommendation>[];
    
    for (final crash in _crashes) {
      final errorString = crash.error.toString();
      
      if (errorString.contains('Null check operator')) {
        recommendations.add(SafeguardRecommendation(
          location: crash.crashLocation,
          issue: 'Null check operator used on null value',
          fix: 'Replace `value!` with null-safe pattern:\n'
               'if (value == null) { return fallback; }',
        ));
      } else if (errorString.contains('disposed')) {
        recommendations.add(SafeguardRecommendation(
          location: crash.crashLocation,
          issue: 'Controller accessed after disposal',
          fix: 'Add mounted check before using controller:\n'
               'if (!mounted) return;',
        ));
      } else if (errorString.contains('RangeError')) {
        recommendations.add(SafeguardRecommendation(
          location: crash.crashLocation,
          issue: 'Array/List index out of bounds',
          fix: 'Add bounds checking:\n'
               'if (index >= 0 && index < list.length) { ... }',
        ));
      } else if (errorString.contains('TimeoutException') || 
                 errorString.contains('SocketException')) {
        recommendations.add(SafeguardRecommendation(
          location: crash.crashLocation,
          issue: 'Network operation failed',
          fix: 'Wrap in try-catch with user feedback:\n'
               'try { await api.call(); } catch (e) { showError(); }',
        ));
      } else {
        recommendations.add(SafeguardRecommendation(
          location: crash.crashLocation,
          issue: errorString.split('\n').first,
          fix: 'Add try-catch safeguard around this code block',
        ));
      }
    }
    
    return recommendations;
  }
  
  /// Get crash analysis report
  static String get report {
    if (_crashes.isEmpty) {
      return '''
╔═══════════════════════════════════════════╗
║            CRASH ANALYSIS REPORT          ║
╠═══════════════════════════════════════════╣
║ ✅ No crashes detected                    ║
╚═══════════════════════════════════════════╝
''';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('╔═══════════════════════════════════════════════════════════════════════╗');
    buffer.writeln('║                       CRASH ANALYSIS REPORT                           ║');
    buffer.writeln('╠═══════════════════════════════════════════════════════════════════════╣');
    buffer.writeln('║ Total Crashes: ${_crashes.length}'.padRight(74) + '║');
    buffer.writeln('╠═══════════════════════════════════════════════════════════════════════╣');
    
    for (var i = 0; i < _crashes.length; i++) {
      final crash = _crashes[i];
      final location = crash.crashLocation.length > 55 
          ? '${crash.crashLocation.substring(0, 55)}...' 
          : crash.crashLocation;
      final errorStr = crash.error.toString().split('\n').first;
      final errorTrunc = errorStr.length > 55 
          ? '${errorStr.substring(0, 55)}...' 
          : errorStr;
      buffer.writeln('║ ${i + 1}. $location'.padRight(74) + '║');
      buffer.writeln('║    $errorTrunc'.padRight(74) + '║');
    }
    
    buffer.writeln('╠═══════════════════════════════════════════════════════════════════════╣');
    buffer.writeln('║ ⚠️  ACTION REQUIRED: Review and apply safeguards                      ║');
    buffer.writeln('╚═══════════════════════════════════════════════════════════════════════╝');
    
    return buffer.toString();
  }
  
  /// Reset crash tracking
  static void reset() {
    _crashes.clear();
  }
}

/// Represents a crash occurrence
class CrashReport {
  final Object error;
  final StackTrace stackTrace;
  final DateTime timestamp;
  final String crashLocation;
  
  CrashReport({
    required this.error,
    required this.stackTrace,
    required this.timestamp,
    required this.crashLocation,
  });
}

/// Represents a safeguard recommendation
class SafeguardRecommendation {
  final String location;
  final String issue;
  final String fix;
  
  SafeguardRecommendation({
    required this.location,
    required this.issue,
    required this.fix,
  });
  
  @override
  String toString() => '''
📍 Location: $location
⚠️ Issue: $issue
✅ Fix: $fix
''';
}

/// Widget tester extensions for stress testing
extension StressTestExtensions on WidgetTester {
  /// Rapidly tap a widget multiple times (taps first widget if multiple found)
  Future<void> rapidTap(Finder finder, {int times = 10, Duration interval = const Duration(milliseconds: 50)}) async {
    for (var i = 0; i < times; i++) {
      final elements = finder.evaluate();
      if (elements.isNotEmpty) {
        // Tap the first matching widget to avoid "multiple widgets found" error
        await tap(finder.first, warnIfMissed: false);
        await pump(interval);
      }
    }
  }
  
  /// Rapidly switch between different finders (simulate tab switching)
  Future<void> rapidSwitch(List<Finder> finders, {int cycles = 5}) async {
    for (var cycle = 0; cycle < cycles; cycle++) {
      for (final finder in finders) {
        if (finder.evaluate().isNotEmpty) {
          await tap(finder, warnIfMissed: false);
          await pump(const Duration(milliseconds: 100));
        }
      }
    }
  }
  
  /// Perform gesture chaos - multiple overlapping gestures
  Future<void> gestureChaos(Rect area, {int gestures = 10}) async {
    final random = DateTime.now().millisecond;
    
    for (var i = 0; i < gestures; i++) {
      final startX = area.left + (area.width * ((random + i * 17) % 100) / 100);
      final startY = area.top + (area.height * ((random + i * 23) % 100) / 100);
      final endX = area.left + (area.width * ((random + i * 31) % 100) / 100);
      final endY = area.top + (area.height * ((random + i * 37) % 100) / 100);
      
      await dragFrom(Offset(startX, startY), Offset(endX - startX, endY - startY));
      await pump(const Duration(milliseconds: 50));
    }
  }
  
  /// Simulate screen rotation
  Future<void> rotateScreen() async {
    // Toggle between portrait and landscape
    await binding.setSurfaceSize(const Size(375, 812)); // iPhone portrait
    await pump(const Duration(milliseconds: 100));
    await binding.setSurfaceSize(const Size(812, 375)); // iPhone landscape
    await pump(const Duration(milliseconds: 100));
    await binding.setSurfaceSize(const Size(375, 812)); // Back to portrait
    await pump(const Duration(milliseconds: 100));
  }
}

/// Reset all stress test utilities
void resetAllStressUtilities() {
  NetworkConditionSimulator.enableNetwork();
  StorageConditionSimulator.restoreStorage();
  MemoryPressureTracker.reset();
  UIResponseTimer.reset();
  CrashAnalyzer.reset();
}
