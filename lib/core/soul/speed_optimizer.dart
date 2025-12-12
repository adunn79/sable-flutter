import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Speed Optimizer - Sub-second response optimization
/// 
/// Strategies:
/// - Model selection based on task complexity
/// - Parallel context fetching
/// - Intelligent caching
/// - Streaming responses
/// - Prefetching on app open
class SpeedOptimizer {
  SharedPreferences? _prefs;
  
  // Performance tracking
  final List<int> _recentResponseTimes = [];
  static const int _maxTrackedResponses = 50;
  
  // Model recommendations based on task
  static const Map<TaskType, ModelRecommendation> _modelRecommendations = {
    TaskType.routing: ModelRecommendation(
      model: 'gemini-2.0-flash',
      maxTokens: 50,
      temperature: 0.3,
      expectedLatencyMs: 100,
    ),
    TaskType.simpleChat: ModelRecommendation(
      model: 'gemini-2.0-flash',
      maxTokens: 500,
      temperature: 0.7,
      expectedLatencyMs: 300,
    ),
    TaskType.emotionalSupport: ModelRecommendation(
      model: 'gpt-4o',
      maxTokens: 800,
      temperature: 0.8,
      expectedLatencyMs: 800,
    ),
    TaskType.creativeFun: ModelRecommendation(
      model: 'gpt-4o',
      maxTokens: 1000,
      temperature: 0.9,
      expectedLatencyMs: 1000,
    ),
    TaskType.factualQuery: ModelRecommendation(
      model: 'gemini-2.0-flash',
      maxTokens: 600,
      temperature: 0.5,
      expectedLatencyMs: 400,
    ),
    TaskType.deepConversation: ModelRecommendation(
      model: 'gpt-4o',
      maxTokens: 1200,
      temperature: 0.75,
      expectedLatencyMs: 1200,
    ),
  };
  
  SpeedOptimizer() {
    _loadPerformanceData();
  }
  
  Future<void> _loadPerformanceData() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Determine the task type from a message
  TaskType classifyTask(String message, {bool userSeemsEmotional = false}) {
    final lowerMessage = message.toLowerCase();
    
    // Emotional support needed
    if (userSeemsEmotional ||
        lowerMessage.contains('feeling') ||
        lowerMessage.contains('sad') ||
        lowerMessage.contains('anxious') ||
        lowerMessage.contains('stressed') ||
        lowerMessage.contains('help me feel')) {
      return TaskType.emotionalSupport;
    }
    
    // Creative/fun requests
    if (lowerMessage.contains('write me') ||
        lowerMessage.contains('story') ||
        lowerMessage.contains('imagine') ||
        lowerMessage.contains('roleplay') ||
        lowerMessage.contains('pretend')) {
      return TaskType.creativeFun;
    }
    
    // Factual queries
    if (lowerMessage.contains('what is') ||
        lowerMessage.contains('who is') ||
        lowerMessage.contains('how does') ||
        lowerMessage.contains('define') ||
        lowerMessage.contains('explain')) {
      return TaskType.factualQuery;
    }
    
    // Deep conversation
    if (lowerMessage.contains('why do') ||
        lowerMessage.contains('meaning of') ||
        lowerMessage.contains('philosophy') ||
        lowerMessage.contains('what do you think about') ||
        message.length > 200) {
      return TaskType.deepConversation;
    }
    
    // Simple short messages
    if (message.length < 50) {
      return TaskType.simpleChat;
    }
    
    return TaskType.simpleChat;
  }
  
  /// Get the recommended model configuration for a task
  ModelRecommendation getModelRecommendation(TaskType task) {
    return _modelRecommendations[task] ?? _modelRecommendations[TaskType.simpleChat]!;
  }
  
  /// Record a response time for performance tracking
  void recordResponseTime(int milliseconds) {
    _recentResponseTimes.add(milliseconds);
    
    // Trim list
    while (_recentResponseTimes.length > _maxTrackedResponses) {
      _recentResponseTimes.removeAt(0);
    }
    
    // Log if slow
    if (milliseconds > 2000) {
      debugPrint('⚠️ Slow response: ${milliseconds}ms');
    }
  }
  
  /// Get average response time
  double get averageResponseTime {
    if (_recentResponseTimes.isEmpty) return 0;
    return _recentResponseTimes.reduce((a, b) => a + b) / _recentResponseTimes.length;
  }
  
  /// Get performance summary
  String getPerformanceSummary() {
    if (_recentResponseTimes.isEmpty) {
      return 'No performance data yet';
    }
    
    final avg = averageResponseTime;
    final fastest = _recentResponseTimes.reduce((a, b) => a < b ? a : b);
    final slowest = _recentResponseTimes.reduce((a, b) => a > b ? a : b);
    final under1s = _recentResponseTimes.where((t) => t < 1000).length;
    
    return '''
Performance Summary:
- Average: ${avg.toStringAsFixed(0)}ms
- Fastest: ${fastest}ms
- Slowest: ${slowest}ms
- Under 1s: ${(under1s / _recentResponseTimes.length * 100).toStringAsFixed(0)}%
''';
  }
  
  /// Determine if we should use streaming for this message
  bool shouldUseStreaming(TaskType task) {
    switch (task) {
      case TaskType.routing:
        return false; // Too short
      case TaskType.simpleChat:
        return false; // Usually fast enough
      case TaskType.emotionalSupport:
        return true; // User wants to see response building
      case TaskType.creativeFun:
        return true; // Long responses benefit from streaming
      case TaskType.factualQuery:
        return false; // Better to show complete answer
      case TaskType.deepConversation:
        return true; // Long, thoughtful responses
    }
  }
  
  /// Get optimal context length to include
  int getOptimalContextLength(TaskType task) {
    switch (task) {
      case TaskType.routing:
        return 0; // No context needed
      case TaskType.simpleChat:
        return 5; // Last 5 messages
      case TaskType.emotionalSupport:
        return 15; // More history for emotional context
      case TaskType.creativeFun:
        return 10;
      case TaskType.factualQuery:
        return 3; // Just recent context
      case TaskType.deepConversation:
        return 20; // Full context for deep discussions
    }
  }
  
  /// Check if prefetching should be done
  bool shouldPrefetch() {
    // Prefetch if average is getting slow
    return averageResponseTime > 800;
  }
}

/// Types of tasks for model selection
enum TaskType {
  routing,
  simpleChat,
  emotionalSupport,
  creativeFun,
  factualQuery,
  deepConversation,
}

/// Model recommendation for a task type
class ModelRecommendation {
  final String model;
  final int maxTokens;
  final double temperature;
  final int expectedLatencyMs;
  
  const ModelRecommendation({
    required this.model,
    required this.maxTokens,
    required this.temperature,
    required this.expectedLatencyMs,
  });
}
