import 'package:flutter/foundation.dart';
import 'package:sable/core/ai/room_brain/room_brain_base.dart';
import 'package:sable/core/ai/agent_context.dart';
import 'package:sable/core/ai/memory_spine.dart';
import 'package:sable/core/ai/tool_registry.dart';

/// Vital Balance Brain - Domain expertise for health & wellness
/// Handles: biometric tracking, goal setting, recovery suggestions, health insights
class VitalBalanceBrain extends RoomBrain {
  VitalBalanceBrain({
    required super.memorySpine,
    required super.tools,
  });

  @override
  String get domain => 'vital_balance';

  @override
  List<String> get capabilities => [
    'health_coaching',
    'biometric_tracking',
    'goal_setting',
    'recovery_suggestions',
    'wellness_insights',
    'hrv_analysis',
  ];

  @override
  bool canHandle(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Health/wellness keywords
    final healthKeywords = [
      'health',
      'wellness',
      'hrv',
      'sleep',
      'recovery',
      'exercise',
      'goal',
      'fitness',
      'stress',
      'energy',
      'vital',
      'biometric',
    ];
    
    return healthKeywords.any((kw) => lowerQuery.contains(kw));
  }

  @override
  Future<BrainResponse> processQuery(String query, AgentContext context) async {
    final lowerQuery = query.toLowerCase();

    // Intent detection - Check health stats?
    if (_isHealthCheckIntent(lowerQuery)) {
      debugPrint('💓 Vital Balance Brain: Health check intent detected');
      
      final healthState = memorySpine.read('HEALTH_STATE');
      final hrv = healthState['hrv'];
      final sleepHours = healthState['sleep_hours'];
      final moodScore = healthState['mood_score'];
      final steps = healthState['steps'];
      
      if (hrv != null || sleepHours != null) {
        final parts = <String>[];
        if (hrv != null) {
          parts.add('HRV: ${hrv.toStringAsFixed(0)}ms ${_getHRVStatus(hrv)}');
        }
        if (sleepHours != null) {
          parts.add('Sleep: ${sleepHours.toStringAsFixed(1)}h ${_getSleepStatus(sleepHours)}');
        }
        if (moodScore != null) {
          parts.add('Mood: ${_getMoodEmoji(moodScore)}');
        }
        if (steps != null) {
          parts.add('Steps: ${steps.toStringAsFixed(0)}');
        }
        
        return BrainResponse.simple(
          "📊 Your vital stats:\n${parts.join('\n')}\n\n"
          "${_getHealthRecommendation(hrv, sleepHours)}",
        );
      } else {
        return BrainResponse.simple(
          "You haven't logged any health data yet. Tap 'Log Data' to start tracking your vitals!",
        );
      }
    }

    // Intent detection - Set a goal?
    if (_isGoalSettingIntent(lowerQuery)) {
      debugPrint('🎯 Vital Balance Brain: Goal setting intent detected');
      
      return BrainResponse.simple(
        "Let's set a health goal! What would you like to focus on?\n\n"
        "Examples:\n"
        "• Sleep 8 hours per night\n"
        "• Walk 10,000 steps daily\n"
        "• Meditate for 10 minutes\n"
        "• Improve HRV by 10%",
      );
    }

    // Intent detection - Recovery advice?
    if (_isRecoveryAdviceIntent(lowerQuery)) {
      debugPrint('🧘 Vital Balance Brain: Recovery advice intent detected');
      
      final healthState = memorySpine.read('HEALTH_STATE');
      final hrv = healthState['hrv'];
      
      return BrainResponse.simple(
        _getRecoveryAdvice(hrv),
      );
    }

    // Default: General health guidance
    return BrainResponse.simple(
      "I'm your wellness coach! I can help you track vitals, set health goals, "
      "and optimize your recovery. What would you like to work on?",
    );
  }

  // ========== INTENT DETECTION ==========

  bool _isHealthCheckIntent(String query) {
    return (query.contains('how') || query.contains('what')) &&
           (query.contains('health') || query.contains('vital') || 
            query.contains('hrv') || query.contains('sleep') || 
            query.contains('stats') || query.contains('doing'));
  }

  bool _isGoalSettingIntent(String query) {
    return query.contains('goal') || 
           query.contains('target') ||
           (query.contains('want to') && (query.contains('improve') || query.contains('get')));
  }

  bool _isRecoveryAdviceIntent(String query) {
    return query.contains('recovery') || 
           query.contains('rest') ||
           query.contains('tired') ||
           query.contains('exhausted') ||
           query.contains('should i');
  }

  // ========== HELPERS ==========

  String _getHRVStatus(double hrv) {
    if (hrv >= 60) return '✅ Excellent';
    if (hrv >= 40) return '👍 Good';
    if (hrv >= 25) return '⚠️ Fair';
    return '🔴 Low - prioritize recovery';
  }

  String _getSleepStatus(double hours) {
    if (hours >= 7.5) return '✅';
    if (hours >= 6.5) return '⚠️';
    return '🔴 Too low';
  }

  String _getMoodEmoji(int score) {
    if (score >= 4) return '😊 Great';
    if (score >= 3) return '🙂 Good';
    if (score >= 2) return '😐 Okay';
    return '😔 Low';
  }

  String _getHealthRecommendation(double? hrv, double? sleepHours) {
    if (hrv != null && hrv < 30) {
      return "💡 Recommendation: Your HRV is low. Focus on recovery today - gentle movement, hydration, and stress management.";
    }
    if (sleepHours != null && sleepHours < 6.5) {
      return "💡 Recommendation: You're under-slept. Prioritize 8 hours tonight and consider a 20-min nap if possible.";
    }
    if (hrv != null && hrv >= 60) {
      return "💡 You're recovered! Great time for a challenging workout or important tasks.";
    }
    return "💡 Keep tracking your vitals daily for personalized insights!";
  }

  String _getRecoveryAdvice(double? hrv) {
    if (hrv == null) {
      return "Track your HRV for personalized recovery advice! For now: prioritize 8h sleep, stay hydrated, and move gently.";
    }
    
    if (hrv < 30) {
      return "🧘 Deep recovery needed:\n"
          "• Skip intense workouts today\n"
          "• 20-min meditation or breathwork\n"
          "• Aim for 9h sleep tonight\n"
          "• Light walk in nature";
    } else if (hrv < 50) {
      return "⚖️ Moderate recovery:\n"
          "• Light cardio okay (Zone 2)\n"
          "• 30-min walk or yoga\n"
          "• 7-8h sleep\n"
          "• Stay hydrated";
    } else {
      return "🚀 Well recovered!\n"
          "• Feel free to train hard\n"
          "• Good day for PRs\n"
          "• Carpe diem!";
    }
  }
}
