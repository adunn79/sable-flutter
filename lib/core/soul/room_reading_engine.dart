import '../emotion/emotional_state_service.dart';
import '../emotion/sentiment_analyzer.dart';

/// Room Reading Engine - Context awareness for AI responses
/// 
/// Analyzes:
/// - User's emotional state from message
/// - Time of day context
/// - Message urgency/length
/// - Conversation velocity
/// - Environmental factors
class RoomReadingEngine {
  final EmotionalStateService emotionalService;
  
  RoomReadingEngine({required this.emotionalService});
  
  /// Read the "room" - understand context before responding
  Future<RoomReading> readRoom({
    required String message,
    required DateTime timeOfDay,
    List<String>? recentMessages,
  }) async {
    // Analyze message sentiment
    final sentiment = SentimentAnalyzer.analyze(message);
    
    // Time-based context
    final hour = timeOfDay.hour;
    final isLateNight = hour >= 22 || hour < 6;
    final isMorning = hour >= 6 && hour < 10;
    final isEvening = hour >= 18 && hour < 22;
    
    // Message analysis
    final messageLength = message.length;
    final isShortMessage = messageLength < 30;
    final isLongMessage = messageLength > 200;
    
    // Emotional indicators
    final lowerMessage = message.toLowerCase();
    final userSeemsSad = _detectSadness(lowerMessage, sentiment.polarity);
    final userSeemsAnxious = _detectAnxiety(lowerMessage);
    final userSeemsExcited = _detectExcitement(lowerMessage, sentiment.polarity);
    final userSeemsUrgent = _detectUrgency(lowerMessage, isShortMessage);
    final userSeemsDown = userSeemsSad || userSeemsAnxious;
    
    // Conversation velocity (are they sending many short messages?)
    final velocityHigh = recentMessages != null && 
        recentMessages.length >= 3 &&
        recentMessages.every((m) => m.length < 50);
    
    // Get current AI emotional state for context
    final aiMood = emotionalService.mood;
    final aiEnergy = emotionalService.energy;
    
    return RoomReading(
      sentimentPolarity: sentiment.polarity,
      isLateNight: isLateNight,
      isMorning: isMorning,
      isEvening: isEvening,
      messageLength: messageLength,
      isShortMessage: isShortMessage,
      isLongMessage: isLongMessage,
      userSeemsSad: userSeemsSad,
      userSeemsAnxious: userSeemsAnxious,
      userSeemsExcited: userSeemsExcited,
      userSeemsUrgent: userSeemsUrgent,
      userSeemsDown: userSeemsDown,
      velocityHigh: velocityHigh,
      aiMood: aiMood,
      aiEnergy: aiEnergy,
    );
  }
  
  bool _detectSadness(String message, double sentiment) {
    final sadKeywords = [
      'sad', 'depressed', 'down', 'lonely', 'hurt', 'crying', 'cry',
      'hopeless', 'empty', 'lost', 'miss', 'grief', 'broken', 'pain',
      'tired of', 'exhausted', 'can\'t anymore', 'don\'t care anymore',
      'worthless', 'useless', 'failure', 'fail', 'hate myself',
    ];
    
    for (final keyword in sadKeywords) {
      if (message.contains(keyword)) return true;
    }
    
    return sentiment < -0.5;
  }
  
  bool _detectAnxiety(String message) {
    final anxiousKeywords = [
      'anxious', 'anxiety', 'worried', 'stress', 'stressed', 'panic',
      'scared', 'afraid', 'nervous', 'overwhelmed', 'can\'t breathe',
      'freaking out', 'what if', 'freak', 'terrified', 'dread',
      'racing', 'heart pounding', 'can\'t stop thinking',
    ];
    
    for (final keyword in anxiousKeywords) {
      if (message.contains(keyword)) return true;
    }
    
    return false;
  }
  
  bool _detectExcitement(String message, double sentiment) {
    final excitedKeywords = [
      'excited', 'amazing', 'awesome', 'incredible', 'can\'t wait',
      'so happy', 'best day', 'love it', 'perfect', 'fantastic',
      'yay', 'woo', 'omg', 'finally', 'dream come true',
    ];
    
    // Check for multiple exclamation marks
    final hasExcitement = message.contains('!!') || message.contains('!!!');
    
    for (final keyword in excitedKeywords) {
      if (message.contains(keyword)) return true;
    }
    
    return hasExcitement && sentiment > 0.3;
  }
  
  bool _detectUrgency(String message, bool isShort) {
    final urgentKeywords = [
      'urgent', 'asap', 'quickly', 'hurry', 'emergency', 'help',
      'right now', 'immediately', 'fast', 'quick question',
    ];
    
    for (final keyword in urgentKeywords) {
      if (message.contains(keyword)) return true;
    }
    
    // Very short messages often indicate urgency
    return isShort && message.endsWith('?');
  }
}

/// Result of room reading analysis
class RoomReading {
  final double sentimentPolarity;
  final bool isLateNight;
  final bool isMorning;
  final bool isEvening;
  final int messageLength;
  final bool isShortMessage;
  final bool isLongMessage;
  final bool userSeemsSad;
  final bool userSeemsAnxious;
  final bool userSeemsExcited;
  final bool userSeemsUrgent;
  final bool userSeemsDown;
  final bool velocityHigh;
  final double aiMood;
  final double aiEnergy;
  
  RoomReading({
    required this.sentimentPolarity,
    required this.isLateNight,
    required this.isMorning,
    required this.isEvening,
    required this.messageLength,
    required this.isShortMessage,
    required this.isLongMessage,
    required this.userSeemsSad,
    required this.userSeemsAnxious,
    required this.userSeemsExcited,
    required this.userSeemsUrgent,
    required this.userSeemsDown,
    required this.velocityHigh,
    required this.aiMood,
    required this.aiEnergy,
  });
  
  /// Create a neutral reading for cache warming
  factory RoomReading.neutral() {
    return RoomReading(
      sentimentPolarity: 0.0,
      isLateNight: false,
      isMorning: false,
      isEvening: false,
      messageLength: 50,
      isShortMessage: false,
      isLongMessage: false,
      userSeemsSad: false,
      userSeemsAnxious: false,
      userSeemsExcited: false,
      userSeemsUrgent: false,
      userSeemsDown: false,
      velocityHigh: false,
      aiMood: 50.0,
      aiEnergy: 60.0,
    );
  }
  
  /// Get a summary of the room reading
  String get summary {
    final parts = <String>[];
    
    if (userSeemsSad) parts.add('sad');
    if (userSeemsAnxious) parts.add('anxious');
    if (userSeemsExcited) parts.add('excited');
    if (userSeemsUrgent) parts.add('urgent');
    if (isLateNight) parts.add('late-night');
    if (isMorning) parts.add('morning');
    if (velocityHigh) parts.add('rapid-fire');
    
    if (parts.isEmpty) {
      return 'neutral context';
    }
    
    return parts.join(', ');
  }
  
  /// Get the recommended response tone
  String get recommendedTone {
    if (userSeemsSad || userSeemsAnxious) return 'warm and supportive';
    if (userSeemsUrgent) return 'concise and helpful';
    if (userSeemsExcited) return 'enthusiastic and matching';
    if (isLateNight) return 'calm and gentle';
    if (isMorning) return 'energizing and positive';
    return 'balanced and natural';
  }
}
