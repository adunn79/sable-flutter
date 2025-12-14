import 'package:flutter/foundation.dart';

/// Performance alert threshold in milliseconds
const int _performanceAlertThresholdMs = 1500;

/// Maximum number of entries to keep in the ring buffer
const int _maxRingBufferSize = 1000;

/// A single latency measurement
class LatencyEntry {
  final String requestId;
  final String modelId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? latencyMs;
  final bool? success;

  LatencyEntry({
    required this.requestId,
    required this.modelId,
    required this.startTime,
    this.endTime,
    this.latencyMs,
    this.success,
  });

  LatencyEntry complete(DateTime end, bool succeeded) {
    return LatencyEntry(
      requestId: requestId,
      modelId: modelId,
      startTime: startTime,
      endTime: end,
      latencyMs: end.difference(startTime).inMilliseconds,
      success: succeeded,
    );
  }
}

/// Performance statistics for a model
class ModelStats {
  final String modelId;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final double averageLatencyMs;
  final int minLatencyMs;
  final int maxLatencyMs;
  final double p50LatencyMs;
  final double p95LatencyMs;
  final bool isPerformanceAlert;

  const ModelStats({
    required this.modelId,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageLatencyMs,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.p50LatencyMs,
    required this.p95LatencyMs,
    required this.isPerformanceAlert,
  });

  @override
  String toString() =>
      'ModelStats($modelId: avg=${averageLatencyMs.toStringAsFixed(0)}ms, '
      'p95=${p95LatencyMs.toStringAsFixed(0)}ms, '
      'success=${successfulRequests}/${totalRequests}, '
      'alert=$isPerformanceAlert)';
}

/// Latency Monitor for tracking AI model performance
/// 
/// Singleton service for app-wide latency tracking with:
/// - Real-time latency measurement per request
/// - Rolling average calculations per model
/// - Performance alerts when avg > 1.5s
/// - Ring buffer storage (last 1000 requests)
class LatencyMonitor {
  // Singleton
  static final LatencyMonitor _instance = LatencyMonitor._();
  static LatencyMonitor get instance => _instance;
  LatencyMonitor._();

  // Active requests being timed
  final Map<String, LatencyEntry> _activeRequests = {};

  // Completed request history (ring buffer)
  final List<LatencyEntry> _history = [];

  // Performance alert callbacks
  final List<void Function(String modelId, double avgLatency)> _alertCallbacks = [];

  /// Start timing a request
  void startTimer(String requestId, String modelId) {
    _activeRequests[requestId] = LatencyEntry(
      requestId: requestId,
      modelId: modelId,
      startTime: DateTime.now(),
    );
  }

  /// End timing a request and return latency in ms
  /// Returns -1 if request not found
  int endTimer(String requestId, {bool success = true}) {
    final entry = _activeRequests.remove(requestId);
    if (entry == null) {
      debugPrint('⚠️ LatencyMonitor: Request $requestId not found');
      return -1;
    }

    final completed = entry.complete(DateTime.now(), success);
    _addToHistory(completed);

    // Check for performance alerts
    _checkPerformanceAlert(completed.modelId);

    return completed.latencyMs ?? -1;
  }

  /// Cancel a request timer without recording (e.g., user cancelled)
  void cancelTimer(String requestId) {
    _activeRequests.remove(requestId);
  }

  void _addToHistory(LatencyEntry entry) {
    _history.add(entry);
    
    // Ring buffer: remove oldest if over limit
    while (_history.length > _maxRingBufferSize) {
      _history.removeAt(0);
    }
  }

  void _checkPerformanceAlert(String modelId) {
    final stats = getModelStats(modelId);
    if (stats.isPerformanceAlert) {
      debugPrint('🚨 Performance Alert: $modelId avg ${stats.averageLatencyMs.toStringAsFixed(0)}ms');
      for (final callback in _alertCallbacks) {
        callback(modelId, stats.averageLatencyMs);
      }
    }
  }

  /// Register a callback for performance alerts
  void onPerformanceAlert(void Function(String modelId, double avgLatency) callback) {
    _alertCallbacks.add(callback);
  }

  /// Get average latency for a model in the last N days
  double getAverageLatency(String modelId, {int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final relevant = _history.where((e) =>
        e.modelId == modelId &&
        e.endTime != null &&
        e.endTime!.isAfter(cutoff) &&
        e.latencyMs != null);

    if (relevant.isEmpty) return 0;

    final total = relevant.fold<int>(0, (sum, e) => sum + e.latencyMs!);
    return total / relevant.length;
  }

  /// Check if a model has a performance alert (avg > threshold)
  bool isPerformanceAlert(String modelId) {
    final avg = getAverageLatency(modelId);
    return avg > _performanceAlertThresholdMs;
  }

  /// Get comprehensive stats for a model
  ModelStats getModelStats(String modelId, {int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final relevant = _history
        .where((e) =>
            e.modelId == modelId &&
            e.endTime != null &&
            e.endTime!.isAfter(cutoff))
        .toList();

    if (relevant.isEmpty) {
      return ModelStats(
        modelId: modelId,
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        averageLatencyMs: 0,
        minLatencyMs: 0,
        maxLatencyMs: 0,
        p50LatencyMs: 0,
        p95LatencyMs: 0,
        isPerformanceAlert: false,
      );
    }

    final successful = relevant.where((e) => e.success == true).length;
    final failed = relevant.where((e) => e.success == false).length;
    
    final latencies = relevant
        .where((e) => e.latencyMs != null)
        .map((e) => e.latencyMs!)
        .toList()
      ..sort();

    if (latencies.isEmpty) {
      return ModelStats(
        modelId: modelId,
        totalRequests: relevant.length,
        successfulRequests: successful,
        failedRequests: failed,
        averageLatencyMs: 0,
        minLatencyMs: 0,
        maxLatencyMs: 0,
        p50LatencyMs: 0,
        p95LatencyMs: 0,
        isPerformanceAlert: false,
      );
    }

    final avg = latencies.fold<int>(0, (sum, l) => sum + l) / latencies.length;
    final p50Index = (latencies.length * 0.5).floor();
    final p95Index = (latencies.length * 0.95).floor().clamp(0, latencies.length - 1);

    return ModelStats(
      modelId: modelId,
      totalRequests: relevant.length,
      successfulRequests: successful,
      failedRequests: failed,
      averageLatencyMs: avg,
      minLatencyMs: latencies.first,
      maxLatencyMs: latencies.last,
      p50LatencyMs: latencies[p50Index].toDouble(),
      p95LatencyMs: latencies[p95Index].toDouble(),
      isPerformanceAlert: avg > _performanceAlertThresholdMs,
    );
  }

  /// Get stats for all models
  Map<String, ModelStats> getAllModelStats({int days = 7}) {
    final modelIds = _history.map((e) => e.modelId).toSet();
    return {for (final id in modelIds) id: getModelStats(id, days: days)};
  }

  /// Get current active request count
  int get activeRequestCount => _activeRequests.length;

  /// Get history size
  int get historySize => _history.length;

  /// Export stats for analytics dashboard
  Map<String, dynamic> exportForAnalytics() {
    final allStats = getAllModelStats();
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'active_requests': activeRequestCount,
      'history_size': historySize,
      'models': allStats.map((k, v) => MapEntry(k, {
        'total_requests': v.totalRequests,
        'success_rate': v.totalRequests > 0 
            ? v.successfulRequests / v.totalRequests 
            : 0,
        'avg_latency_ms': v.averageLatencyMs,
        'p50_latency_ms': v.p50LatencyMs,
        'p95_latency_ms': v.p95LatencyMs,
        'is_alert': v.isPerformanceAlert,
      })),
    };
  }

  /// Clear all history (for testing)
  @visibleForTesting
  void clearHistory() {
    _history.clear();
    _activeRequests.clear();
  }
}
