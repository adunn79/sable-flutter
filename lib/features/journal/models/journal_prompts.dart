/// Enhanced journaling prompts with context awareness
class JournalPrompts {
  // Gratitude prompts
  static const List<String> gratitude = [
    "What's something small that brought you joy today?",
    "Who in your life are you thankful for right now?",
    "What's a challenge you faced that helped you grow?",
    "What ability or skill are you grateful to have?",
    "What's a comfort you often take for granted?",
    "Describe a moment today that made you smile.",
    "What's something about your body you appreciate?",
    "Who showed you kindness recently?",
    "What's a place that brings you peace?",
    "What technology or invention are you grateful for?",
  ];
  
  // Reflection prompts
  static const List<String> reflection = [
    "What was the highlight of your day?",
    "If you could redo one thing today, what would it be?",
    "What did you learn about yourself today?",
    "What's one thing you did well today?",
    "What conversation stuck with you today?",
    "How did you step out of your comfort zone?",
    "What would have made today even better?",
    "What emotion did you feel most today?",
    "What energized you today?",
    "What drained your energy today?",
  ];
  
  // Creative prompts
  static const List<String> creative = [
    "If you could live anywhere for a year, where would it be?",
    "Describe your ideal day from morning to night.",
    "What would you do if you knew you couldn't fail?",
    "Write a letter to your future self 10 years from now.",
    "If you could have dinner with anyone, who would it be?",
    "What's a dream you've never shared with anyone?",
    "Describe yourself in three words and explain why.",
    "What would you do with an extra hour every day?",
    "If you could master one skill instantly, what would it be?",
    "What's a story from your past you want to remember forever?",
  ];
  
  // Emotional check-in prompts
  static const List<String> emotional = [
    "How are you really feeling right now?",
    "What's weighing on your mind today?",
    "What do you need to let go of?",
    "What emotion are you avoiding?",
    "What would self-care look like for you today?",
    "What boundary do you need to set?",
    "What are you proud of yourself for today?",
    "What's something you're looking forward to?",
    "What fear is holding you back?",
    "What do you need to hear right now?",
  ];
  
  // Future/planning prompts
  static const List<String> future = [
    "What's one goal you want to achieve this month?",
    "What habit do you want to build?",
    "What does success look like to you?",
    "What's your biggest priority right now?",
    "What's something you want to start doing?",
    "What's something you want to stop doing?",
    "How do you want to feel a year from now?",
    "What's one step you can take toward your dreams?",
    "What would your ideal morning routine look like?",
    "What action would make you proud of yourself?",
  ];
  
  // Memory/mindfulness prompts
  static const List<String> mindfulness = [
    "What did you notice today that you usually miss?",
    "Describe what you can see, hear, and feel right now.",
    "What made you feel present today?",
    "What's a smell or sound that brings back a memory?",
    "What's the most beautiful thing you saw today?",
    "How does your body feel right now?",
    "What three things can you be grateful for in this moment?",
    "What's a sensation you're experiencing right now?",
    "What's different about today compared to yesterday?",
    "What moment today felt timeless?",
  ];
  
  // Relationship prompts
  static const List<String> relationships = [
    "How did you connect with someone today?",
    "What do you appreciate most about your best friend?",
    "What conversation do you need to have?",
    "Who do you want to reach out to?",
    "What's a nice thing someone did for you recently?",
    "How did you make someone's day better?",
    "What quality do you admire in someone close to you?",
    "When did you feel most connected to someone?",
    "What relationship are you grateful for?",
    "How can you show appreciation to someone tomorrow?",
  ];
  
  // Morning prompts
  static const List<String> morning = [
    "What's your intention for today?",
    "How do you want to feel by the end of today?",
    "What's one thing you're excited about today?",
    "What would make today great?",
    "What are you looking forward to?",
   "How can you make today meaningful?",
    "What's your focus for today?",
    "What energy do you want to bring to today?",
    "What's one act of kindness you can do today?",
    "What opportunity might today bring?",
  ];
  
  // Evening prompts
  static const List<String> evening = [
    "What's one thing you accomplished today?",
    "What made you laugh today?",
    "What challenged you today?",
    "What's something you're proud of from today?",
    "What surprised you today?",
    "What lesson did today teach you?",
    "What moment do you want to remember from today?",
    "How did you grow today?",
    "What can you celebrate about today?",
    "What do you want to release before sleep?",
  ];
  
  // Weekend prompts
  static const List<String> weekend = [
    "How do you want to spend your weekend?",
    "What would recharge you this weekend?",
    "What's something fun you want to try?",
    "How can you make this weekend memorable?",
    "What's one thing you want to avoid this weekend?",
    "What would make you feel rested and renewed?",
    "Who do you want to spend time with?",
    "What hobby or passion can you explore?",
    "What would your ideal Saturday look like?",
    "How can you balance rest and adventure?",
  ];
  
  // Get context-aware prompt
  static String getContextualPrompt() {
    final now = DateTime.now();
    final hour = now.hour;
    final dayOfWeek = now.weekday;
    
    // Morning (5am - 11am)
    if (hour >= 5 && hour < 12) {
      return _randomFrom(morning);
    }
    
    // Evening (7pm - midnight)
    if (hour >= 19 || hour < 5) {
      return _randomFrom(evening);
    }
    
    // Weekend
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      return _randomFrom(weekend);
    }
    
    // Default: reflection
    return _randomFrom(reflection);
  }
  
  // Get random prompt from category
  static String getPrompt(String category) {
    switch (category.toLowerCase()) {
      case 'gratitude':
        return _randomFrom(gratitude);
      case 'reflection':
        return _randomFrom(reflection);
      case 'creative':
        return _randomFrom(creative);
      case 'emotional':
        return _randomFrom(emotional);
      case 'future':
        return _randomFrom(future);
      case 'mindfulness':
        return _randomFrom(mindfulness);
      case 'relationships':
        return _randomFrom(relationships);
      case 'morning':
        return _randomFrom(morning);
      case 'evening':
        return _randomFrom(evening);
      case 'weekend':
        return _randomFrom(weekend);
      default:
        return getContextualPrompt();
    }
  }
  
  static String _randomFrom(List<String> prompts) {
    return prompts[DateTime.now().millisecondsSinceEpoch % prompts.length];
  }
  
  static List<String> get allCategories => [
    'Contextual', // Special: changes based on time/day
    'Gratitude',
    'Reflection',
    'Creative',
    'Emotional',
    'Future',
    'Mindfulness',
    'Relationships',
    'Morning',
    'Evening',
    'Weekend',
  ];
  
  // Get all prompts (for avoiding repeats)
  static List<String> get allPrompts => [
    ...gratitude,
    ...reflection,
    ...creative,
    ...emotional,
    ...future,
    ...mindfulness,
    ...relationships,
    ...morning,
    ...evening,
    ...weekend,
  ];
}
