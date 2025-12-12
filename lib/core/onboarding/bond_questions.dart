/// Bond Building Question Bank
///
/// Natural, conversational questions the AI asks to learn about the user.
/// These feel like talking to a curious friend, not a survey.
library;

class BondQuestions {
  /// Basic getting-to-know-you questions (Day 1-2)
  static const List<String> basics = [
    "What should I call you?",
    "Where are you based? I like knowing what timezone you're in.",
    "What do you do for work - or if you'd rather not talk shop, what do you do for fun?",
    "Quick one: do you prefer texts or calls in real life?",
  ];

  /// Personality and preference questions (Day 2-3)
  static const List<String> personality = [
    "Are you more of a planner or go-with-the-flow type?",
    "Morning person or night owl? No judgment either way.",
    "What's something you're really into right now?",
    "Do you like being reminded about things or does that feel nagging?",
  ];

  /// Deeper connection questions (Day 4-5)
  static const List<String> deeper = [
    "What's been on your mind lately?",
    "Is there anything stressing you out that you'd want to talk through?",
    "What's a goal you're working toward right now?",
    "What does a really good day look like for you?",
  ];

  /// Fun, lighthearted questions (anytime)
  static const List<String> fun = [
    "Random one: what's the last show you binged?",
    "If you could be anywhere right now, where would it be?",
    "What song's been stuck in your head lately?",
    "Coffee, tea, or something else entirely?",
    "What's your comfort food?",
  ];

  /// Wellness-related questions (when appropriate)
  static const List<String> wellness = [
    "How have you been sleeping lately?",
    "Do you have any wellness routines you try to stick to?",
    "What helps you unwind after a long day?",
    "Are you someone who tracks fitness stuff, or prefer to go by feel?",
  ];

  /// Get a random question from a category
  static String getRandomQuestion(String category) {
    final List<String> questions;
    switch (category) {
      case 'basics':
        questions = basics;
        break;
      case 'personality':
        questions = personality;
        break;
      case 'deeper':
        questions = deeper;
        break;
      case 'fun':
        questions = fun;
        break;
      case 'wellness':
        questions = wellness;
        break;
      default:
        questions = basics;
    }
    
    final index = DateTime.now().millisecondsSinceEpoch % questions.length;
    return questions[index];
  }

  /// Get the next appropriate question based on days since first use
  static String getAppropriateQuestion(int daysSinceFirstUse, Set<String> askedQuestions) {
    List<String> pool;
    
    if (daysSinceFirstUse <= 1) {
      pool = basics;
    } else if (daysSinceFirstUse <= 3) {
      pool = [...basics, ...personality, ...fun];
    } else if (daysSinceFirstUse <= 5) {
      pool = [...personality, ...deeper, ...fun];
    } else {
      pool = [...deeper, ...wellness, ...fun];
    }
    
    // Filter out already asked questions
    final unasked = pool.where((q) => !askedQuestions.contains(q)).toList();
    
    if (unasked.isEmpty) {
      // All questions asked, pick from fun
      return fun[DateTime.now().millisecondsSinceEpoch % fun.length];
    }
    
    return unasked[DateTime.now().millisecondsSinceEpoch % unasked.length];
  }
}
