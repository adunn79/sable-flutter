import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Connectivity monitoring service for offline UX improvements
/// Provides network status without external dependencies
class ConnectivityService {
  static ConnectivityService? _instance;
  
  bool _isOnline = true;
  final _statusController = StreamController<bool>.broadcast();
  Timer? _checkTimer;
  
  ConnectivityService._();
  
  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }
  
  /// Stream of connectivity status changes
  Stream<bool> get onStatusChange => _statusController.stream;
  
  /// Current connectivity status
  bool get isOnline => _isOnline;
  
  /// Start monitoring connectivity
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(interval, (_) => checkConnectivity());
    // Initial check
    checkConnectivity();
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }
  
  /// Check connectivity by attempting to reach a reliable endpoint
  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      final wasOnline = _isOnline;
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (wasOnline != _isOnline) {
        debugPrint('📡 Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
        _statusController.add(_isOnline);
      }
      
      return _isOnline;
    } on SocketException catch (_) {
      if (_isOnline) {
        _isOnline = false;
        debugPrint('📡 Connectivity changed: OFFLINE');
        _statusController.add(false);
      }
      return false;
    } on TimeoutException catch (_) {
      if (_isOnline) {
        _isOnline = false;
        debugPrint('📡 Connectivity timeout: OFFLINE');
        _statusController.add(false);
      }
      return false;
    }
  }
  
  /// Execute a function with connectivity check
  /// Returns null if offline and offlineValue is not provided
  Future<T?> executeIfOnline<T>(
    Future<T> Function() action, {
    T? offlineValue,
    bool showMessage = true,
  }) async {
    if (!_isOnline) {
      await checkConnectivity(); // Double-check
    }
    
    if (!_isOnline) {
      debugPrint('⚠️ Action blocked: Device is offline');
      return offlineValue;
    }
    
    try {
      return await action();
    } on SocketException catch (e) {
      debugPrint('⚠️ Network error during action: $e');
      _isOnline = false;
      _statusController.add(false);
      return offlineValue;
    }
  }
  
  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}
