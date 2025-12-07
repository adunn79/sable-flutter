import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepTrackingService {
  StepTrackingService._();
  static final StepTrackingService instance = StepTrackingService._();

  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream;
  
  // Current session data
  int? _sessionStartSteps;
  int _currentPedometerSteps = 0;
  bool _isWalking = false;
  DateTime? _walkStartTime;

  final _stepController = StreamController<int>.broadcast();
  Stream<int> get sessionStepsStream => _stepController.stream;

  bool get isWalking => _isWalking;

  /// Initialize and request permissions
  Future<bool> init() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _initPedometer();
      return true;
    }
    // iOS Motion
    if (await Permission.sensors.request().isGranted) {
       _initPedometer();
       return true;
    }
    return false;
  }

  void _initPedometer() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(_onStepCount).onError(_onStepCountError);
  }

  void _onStepCount(StepCount event) {
    _currentPedometerSteps = event.steps;
    
    if (_isWalking && _sessionStartSteps != null) {
      final sessionSteps = _currentPedometerSteps - _sessionStartSteps!;
      // Emit current session steps
      _stepController.add(sessionSteps > 0 ? sessionSteps : 0);
    }
  }

  void _onStepCountError(error) {
    debugPrint('Pedometer Error: $error');
  }

  /// Start a new Walk Session
  void startWalk() {
    _isWalking = true;
    _walkStartTime = DateTime.now();
    _sessionStartSteps = _currentPedometerSteps;
    _stepController.add(0);
    debugPrint('Walk Started at steps: $_sessionStartSteps');
  }

  /// Stop Walk Session and return total steps
  int stopWalk() {
    _isWalking = false;
    if (_sessionStartSteps == null) return 0;
    
    final total = _currentPedometerSteps - _sessionStartSteps!;
    _sessionStartSteps = null;
    _walkStartTime = null;
    
    debugPrint('Walk Stopped. Total: $total');
    return total > 0 ? total : 0;
  }
}
