import 'package:shared_preferences/shared_preferences.dart';

/// Feedback Learning Service - Learn from user reactions
/// 
/// Inspired by Replika's learning system:
/// - Track thumbs up/down on responses
/// - Learn preferred response styles
/// - Adjust behavior based on patterns
class FeedbackLearning {
  SharedPreferences? _prefs;
  
  // Cumulative feedback tracking
  int _totalPositive = 0;
  int _totalNegative = 0;
  
  // Style-specific feedback
  int _positiveHumor = 0;
  int _negativeHumor = 0;
  int _positiveLong = 0;
  int _negativeLong = 0;
  int _positiveEmotional = 0;
  int _negativeEmotional = 0;
  int _positiveDirect = 0;
  int _negativeDirect = 0;
  
  // Recent feedback buffer (last 20)
  List<FeedbackEntry> _recentFeedback = [];
  static const int _maxRecentFeedback = 20;
  
  FeedbackLearning() {
    _loadFeedback();
  }
  
  Future<void> _loadFeedback() async {
    _prefs = await SharedPreferences.getInstance();
    
    _totalPositive = _prefs?.getInt('fb_total_positive') ?? 0;
    _totalNegative = _prefs?.getInt('fb_total_negative') ?? 0;
    _positiveHumor = _prefs?.getInt('fb_positive_humor') ?? 0;
    _negativeHumor = _prefs?.getInt('fb_negative_humor') ?? 0;
    _positiveLong = _prefs?.getInt('fb_positive_long') ?? 0;
    _negativeLong = _prefs?.getInt('fb_negative_long') ?? 0;
    _positiveEmotional = _prefs?.getInt('fb_positive_emotional') ?? 0;
    _negativeEmotional = _prefs?.getInt('fb_negative_emotional') ?? 0;
    _positiveDirect = _prefs?.getInt('fb_positive_direct') ?? 0;
    _negativeDirect = _prefs?.getInt('fb_negative_direct') ?? 0;
  }
  
  Future<void> _saveFeedback() async {
    await _prefs?.setInt('fb_total_positive', _totalPositive);
    await _prefs?.setInt('fb_total_negative', _totalNegative);
    await _prefs?.setInt('fb_positive_humor', _positiveHumor);
    await _prefs?.setInt('fb_negative_humor', _negativeHumor);
    await _prefs?.setInt('fb_positive_long', _positiveLong);
    await _prefs?.setInt('fb_negative_long', _negativeLong);
    await _prefs?.setInt('fb_positive_emotional', _positiveEmotional);
    await _prefs?.setInt('fb_negative_emotional', _negativeEmotional);
    await _prefs?.setInt('fb_positive_direct', _positiveDirect);
    await _prefs?.setInt('fb_negative_direct', _negativeDirect);
  }
  
  /// Record feedback on a message
  void recordFeedback(
    String messageId, 
    bool positive, {
    bool wasHumorous = false,
    bool wasLong = false,
    bool wasEmotional = false,
    bool wasDirect = false,
  }) {
    // Update totals
    if (positive) {
      _totalPositive++;
    } else {
      _totalNegative++;
    }
    
    // Update style-specific counts
    if (wasHumorous) {
      if (positive) _positiveHumor++; else _negativeHumor++;
    }
    if (wasLong) {
      if (positive) _positiveLong++; else _negativeLong++;
    }
    if (wasEmotional) {
      if (positive) _positiveEmotional++; else _negativeEmotional++;
    }
    if (wasDirect) {
      if (positive) _positiveDirect++; else _negativeDirect++;
    }
    
    // Add to recent buffer
    _recentFeedback.add(FeedbackEntry(
      messageId: messageId,
      positive: positive,
      wasHumorous: wasHumorous,
      wasLong: wasLong,
      wasEmotional: wasEmotional,
      wasDirect: wasDirect,
      timestamp: DateTime.now(),
    ));
    
    // Trim buffer
    while (_recentFeedback.length > _maxRecentFeedback) {
      _recentFeedback.removeAt(0);
    }
    
    _saveFeedback();
  }
  
  /// Get preference score for a style (0.0 to 1.0)
  double _getPreference(int positive, int negative) {
    final total = positive + negative;
    if (total == 0) return 0.5; // Neutral
    return positive / total;
  }
  
  /// Get learned style preferences
  Map<String, double> getStylePreferences() {
    return {
      'humor': _getPreference(_positiveHumor, _negativeHumor),
      'length': _getPreference(_positiveLong, _negativeLong),
      'emotional': _getPreference(_positiveEmotional, _negativeEmotional),
      'directness': _getPreference(_positiveDirect, _negativeDirect),
    };
  }
  
  /// Get preference summary for AI context
  String getPreferenceSummary() {
    final prefs = getStylePreferences();
    final parts = <String>[];
    
    // Humor
    if (prefs['humor']! > 0.7) {
      parts.add('User enjoys humor (${(_totalPositive > 10) ? "strongly" : "slightly"})');
    } else if (prefs['humor']! < 0.3) {
      parts.add('User prefers less humor');
    }
    
    // Length
    if (prefs['length']! > 0.7) {
      parts.add('User appreciates detailed responses');
    } else if (prefs['length']! < 0.3) {
      parts.add('User prefers concise responses');
    }
    
    // Emotional
    if (prefs['emotional']! > 0.7) {
      parts.add('User responds well to emotional expressiveness');
    } else if (prefs['emotional']! < 0.3) {
      parts.add('User prefers more measured emotional tone');
    }
    
    // Direct
    if (prefs['directness']! > 0.7) {
      parts.add('User appreciates direct communication');
    } else if (prefs['directness']! < 0.3) {
      parts.add('User prefers softer approach');
    }
    
    if (parts.isEmpty) {
      return 'Still learning user preferences (${_totalPositive + _totalNegative} feedback points)';
    }
    
    return parts.join('\n');
  }
  
  /// Get overall satisfaction rate
  double get satisfactionRate {
    final total = _totalPositive + _totalNegative;
    if (total == 0) return 0.5;
    return _totalPositive / total;
  }
  
  /// Get recent trend (are things getting better or worse?)
  String getRecentTrend() {
    if (_recentFeedback.length < 5) return 'Not enough data';
    
    final last5 = _recentFeedback.sublist(_recentFeedback.length - 5);
    final positiveCount = last5.where((f) => f.positive).length;
    
    if (positiveCount >= 4) return 'Excellent - user is very happy!';
    if (positiveCount >= 3) return 'Good - mostly positive';
    if (positiveCount == 2) return 'Mixed - some adjustments needed';
    return 'Needs improvement - adapt approach';
  }
  
  /// Reset all feedback data
  Future<void> resetFeedback() async {
    _totalPositive = 0;
    _totalNegative = 0;
    _positiveHumor = 0;
    _negativeHumor = 0;
    _positiveLong = 0;
    _negativeLong = 0;
    _positiveEmotional = 0;
    _negativeEmotional = 0;
    _positiveDirect = 0;
    _negativeDirect = 0;
    _recentFeedback.clear();
    await _saveFeedback();
  }
  
  // ============== INSIGHT TRACKING ==============
  // For proactive awareness feature
  
  /// Get the last time we showed a proactive insight
  DateTime? getLastInsightTime() {
    final intValue = _prefs?.getInt('last_insight_time');
    if (intValue == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(intValue);
  }
  
  /// Record that we just showed an insight
  void recordInsightShown() {
    _prefs?.setInt('last_insight_time', DateTime.now().millisecondsSinceEpoch);
  }
}

/// Single feedback entry
class FeedbackEntry {
  final String messageId;
  final bool positive;
  final bool wasHumorous;
  final bool wasLong;
  final bool wasEmotional;
  final bool wasDirect;
  final DateTime timestamp;
  
  FeedbackEntry({
    required this.messageId,
    required this.positive,
    this.wasHumorous = false,
    this.wasLong = false,
    this.wasEmotional = false,
    this.wasDirect = false,
    required this.timestamp,
  });
}
