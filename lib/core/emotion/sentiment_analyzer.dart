/// Sentiment analysis for user messages
/// Detects emotional tone and interaction patterns
class SentimentAnalyzer {
  /// Analyze sentiment of user message
  /// Returns score from -1.0 (very negative) to 1.0 (very positive)
  static SentimentScore analyze(String message) {
    final lowerMessage = message.toLowerCase();
    
    double polarity = 0.0;
    bool isInsult = false;
    bool isAppreciation = false;
    bool isQuestion = false;
    bool isSharing = false;

    // Check for questions (shows engagement)
    if (lowerMessage.contains('?') || 
        lowerMessage.startsWith('what ') ||
        lowerMessage.startsWith('how ') ||
        lowerMessage.startsWith('why ') ||
        lowerMessage.startsWith('when ') ||
        lowerMessage.startsWith('where ')) {
      isQuestion = true;
      polarity += 0.1; // Slight positive for engagement
    }

    // Check for sharing/personal information
    final sharingPhrases = ['i feel', 'i think', 'i believe', 'my', 'i\'m', 'i am'];
    if (sharingPhrases.any((phrase) => lowerMessage.contains(phrase))) {
      isSharing = true;
      polarity += 0.2; // Positive for trust/openness
    }

    // Check for appreciation
    final appreciationWords = [
      'thank', 'thanks', 'appreciate', 'grateful', 'love', 'like',
      'amazing', 'awesome', 'great', 'wonderful', 'perfect', 'nice',
      'good', 'helpful', 'kind', 'sweet', 'beautiful'
    ];
    int appreciationCount = 0;
    for (var word in appreciationWords) {
      if (lowerMessage.contains(word)) {
        appreciationCount++;
        polarity += 0.15;
      }
    }
    if (appreciationCount > 0) isAppreciation = true;

    // Check for insults/mistreatment
    final insultWords = [
      'stupid', 'dumb', 'idiot', 'shut up', 'boring', 'useless',
      'waste', 'annoying', 'hate', 'suck', 'terrible', 'awful',
      'pathetic', 'loser', 'fuck', 'shit', 'bitch', 'ass'
    ];
    int insultCount = 0;
    for (var word in insultWords) {
      if (lowerMessage.contains(word)) {
        insultCount++;
        polarity -= 0.3;
      }
    }
    if (insultCount > 0) isInsult = true;

    // Check for dismissiveness
    final dismissivePhrase = [
      'whatever', 'don\'t care', 'boring', 'shut up', 'leave me alone',
      'go away', 'stop', 'enough', 'nevermind'
    ];
    for (var phrase in dismissivePhrase) {
      if (lowerMessage.contains(phrase)) {
        polarity -= 0.2;
      }
    }

    // Check for positive emotions
    final positiveWords = [
      'happy', 'excited', 'joy', 'fun', 'cool', 'yes', 'yeah',
      'sure', 'absolutely', 'definitely', 'lol', 'haha', '!'
    ];
    for (var word in positiveWords) {
      if (lowerMessage.contains(word)) {
        polarity += 0.1;
      }
    }

    // Check for negative emotions
    final negativeWords = [
      'sad', 'upset', 'angry', 'frustrated', 'annoyed', 'tired',
      'stressed', 'bad', 'no', 'nope', 'nah'
    ];
    for (var word in negativeWords) {
      if (lowerMessage.contains(word)) {
        polarity -= 0.1;
      }
    }

    // Clamp polarity
    polarity = polarity.clamp(-1.0, 1.0);

    return SentimentScore(
      polarity: polarity,
      isInsult: isInsult,
      isAppreciation: isAppreciation,
      isQuestion: isQuestion,
      isSharing: isSharing,
    );
  }
}

/// Result of sentiment analysis
class SentimentScore {
  final double polarity; // -1.0 (very negative) to 1.0 (very positive)
  final bool isInsult;
  final bool isAppreciation;
  final bool isQuestion;
  final bool isSharing; // User sharing personal info (trust signal)

  SentimentScore({
    required this.polarity,
    required this.isInsult,
    required this.isAppreciation,
    required this.isQuestion,
    required this.isSharing,
  });

  bool get isMistreatment => isInsult || polarity < -0.3;
  bool get isPositive => isAppreciation || isSharing || polarity > 0.3;

  @override
  String toString() {
    return 'SentimentScore(polarity: $polarity, insult: $isInsult, appreciation: $isAppreciation)';
  }
}
