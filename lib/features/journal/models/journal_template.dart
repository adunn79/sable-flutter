/// Journal template for structured entries
class JournalTemplate {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<TemplateField> fields;
  final String category;

  const JournalTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.fields,
    required this.category,
  });
}

/// Field in a template
class TemplateField {
  final String id;
  final String label;
  final String placeholder;
  final TemplateFieldType type;
  final bool required;
  final int? maxLines;

  const TemplateField({
    required this.id,
    required this.label,
    required this.placeholder,
    this.type = TemplateFieldType.text,
    this.required = false,
    this.maxLines,
  });
}

enum TemplateFieldType {
  text,
  multiline,
  number,
  mood,
}

/// Pre-defined templates
class JournalTemplates {
  static const List<JournalTemplate> all = [
    // Gratitude
    JournalTemplate(
      id: 'gratitude',
      name: 'Gratitude Journal',
      emoji: '🙏',
      description: 'Reflect on what you\'re thankful for',
      category: 'Reflection',
      fields: [
        TemplateField(
          id: 'thing1',
          label: 'I\'m grateful for...',
          placeholder: 'Something that made you smile today',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
        TemplateField(
          id: 'thing2',
          label: 'I\'m also grateful for...',
          placeholder: 'A person, experience, or opportunity',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
        TemplateField(
          id: 'thing3',
          label: 'And I\'m grateful for...',
          placeholder: 'Something you might take for granted',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
      ],
    ),
    
    // Daily Reflection
    JournalTemplate(
      id: 'daily_reflection',
      name: 'Daily Reflection',
      emoji: '✨',
      description: 'Review your day and plan ahead',
      category: 'Reflection',
      fields: [
        TemplateField(
          id: 'went_well',
          label: 'What went well today?',
          placeholder: 'Your wins, big or small',
          type: TemplateFieldType.multiline,
          maxLines: 3,
        ),
        TemplateField(
          id: 'could_improve',
          label: 'What could I improve?',
          placeholder: 'Lessons learned or areas to work on',
          type: TemplateFieldType.multiline,
          maxLines: 3,
        ),
        TemplateField(
          id: 'thankful',
          label: 'One thing I\'m thankful for:',
          placeholder: 'Express gratitude',
          type: TemplateFieldType.text,
        ),
        TemplateField(
          id: 'tomorrow',
          label: 'Tomorrow, I will...',
          placeholder: 'Set intention for tomorrow',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
      ],
    ),
    
    // Dream Log
    JournalTemplate(
      id: 'dream_log',
      name: 'Dream Log',
      emoji: '💭',
      description: 'Record and analyze your dreams',
      category: 'Personal',
      fields: [
        TemplateField(
          id: 'dream',
          label: 'My dream:',
          placeholder: 'Describe what you remember...',
          type: TemplateFieldType.multiline,
          maxLines: 5,
        ),
        TemplateField(
          id: 'symbols',
          label: 'Key symbols or themes:',
          placeholder: 'People, places, emotions, objects',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
        TemplateField(
          id: 'feeling',
          label: 'How it made me feel:',
          placeholder: 'Emotional response',
          type: TemplateFieldType.text,
        ),
      ],
    ),
    
    // Workout/Health
    JournalTemplate(
      id: 'workout',
      name: 'Workout & Health',
      emoji: '💪',
      description: 'Track fitness and wellness',
      category: 'Health',
      fields: [
        TemplateField(
          id: 'exercise',
          label: 'Exercise:',
          placeholder: 'What did you do? (e.g., 30 min run, yoga)',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
        TemplateField(
          id: 'meals',
          label: 'Meals:',
          placeholder: 'What you ate today',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
        TemplateField(
          id: 'sleep',
          label: 'Sleep quality:',
          placeholder: 'Hours slept and how you feel',
          type: TemplateFieldType.text,
        ),
        TemplateField(
          id: 'energy',
          label: 'Energy level (1-5):',
          placeholder: '1 = exhausted, 5 = energized',
          type: TemplateFieldType.number,
        ),
      ],
    ),
    
    // Travel
    JournalTemplate(
      id: 'travel',
      name: 'Travel Entry',
      emoji: '✈️',
      description: 'Document your adventures',
      category: 'Personal',
      fields: [
        TemplateField(
          id: 'destination',
          label: 'Destination:',
          placeholder: 'Where are you?',
          type: TemplateFieldType.text,
          required: true,
        ),
        TemplateField(
          id: 'highlights',
          label: 'Highlights:',
          placeholder: 'Best moments or experiences',
          type: TemplateFieldType.multiline,
          maxLines: 3,
        ),
        TemplateField(
          id: 'food',
          label: 'Food & drinks:',
          placeholder: 'What you tried',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
        TemplateField(
          id: 'people',
          label: 'People I met:',
          placeholder: 'New friends or locals',
          type: TemplateFieldType.text,
        ),
      ],
    ),
    
    // Meeting Notes
    JournalTemplate(
      id: 'meeting',
      name: 'Meeting Notes',
      emoji: '📝',
      description: 'Capture meeting details',
      category: 'Work',
      fields: [
        TemplateField(
          id: 'attendees',
          label: 'Attendees:',
          placeholder: 'Who was there?',
          type: TemplateFieldType.text,
        ),
        TemplateField(
          id: 'topics',
          label: 'Topics discussed:',
          placeholder: 'Main points covered',
          type: TemplateFieldType.multiline,
          maxLines: 3,
        ),
        TemplateField(
          id: 'action_items',
          label: 'Action items:',
          placeholder: 'What needs to be done?',
          type: TemplateFieldType.multiline,
          maxLines: 3,
        ),
      ],
    ),
    
    // Goal Setting
    JournalTemplate(
      id: 'goal',
      name: 'Goal Setting',
      emoji: '🎯',
      description: 'Define and track goals',
      category: 'Growth',
      fields: [
        TemplateField(
          id: 'goal',
          label: 'My goal:',
          placeholder: 'What do you want to achieve?',
          type: TemplateFieldType.text,
          required: true,
        ),
        TemplateField(
          id: 'why',
          label: 'Why this matters:',
          placeholder: 'Your motivation',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
        TemplateField(
          id: 'steps',
          label: 'Steps to achieve it:',
          placeholder: 'Break it down into actionable steps',
          type: TemplateFieldType.multiline,
          maxLines: 3,
        ),
        TemplateField(
          id: 'deadline',
          label: 'Target date:',
          placeholder: 'When do you want to complete this?',
          type: TemplateFieldType.text,
        ),
      ],
    ),
    
    // Mood Check-in
    JournalTemplate(
      id: 'mood_checkin',
      name: 'Mood Check-in',
      emoji: '💙',
      description: 'Deep emotional reflection',
      category: 'Wellness',
      fields: [
        TemplateField(
          id: 'feeling',
          label: 'Right now I feel...',
          placeholder: 'Name your emotion(s)',
          type: TemplateFieldType.text,
        ),
        TemplateField(
          id: 'why',
          label: 'Because...',
          placeholder: 'What\'s contributing to this feeling?',
          type: TemplateFieldType.multiline,
          maxLines: 3,
        ),
        TemplateField(
          id: 'need',
          label: 'What I need right now:',
          placeholder: 'Support, rest, connection, etc.',
          type: TemplateFieldType.text,
        ),
      ],
    ),
    
    // Creative Ideas
    JournalTemplate(
      id: 'creative',
      name: 'Creative Ideas',
      emoji: '💡',
      description: 'Brainstorm and capture inspiration',
      category: 'Growth',
      fields: [
        TemplateField(
          id: 'idea',
          label: 'The idea:',
          placeholder: 'What\'s the concept?',
          type: TemplateFieldType.multiline,
          maxLines: 3,
        ),
        TemplateField(
          id: 'inspiration',
          label: 'Inspired by:',
          placeholder: 'What sparked this?',
          type: TemplateFieldType.text,
        ),
        TemplateField(
          id: 'next',
          label: 'Next steps:',
          placeholder: 'How to develop this further',
          type: TemplateFieldType.multiline,
          maxLines: 2,
        ),
      ],
    ),
    
    // Blank
    JournalTemplate(
      id: 'blank',
      name: 'Blank Entry',
      emoji: '📄',
      description: 'Free-form writing',
      category: 'General',
      fields: [
        TemplateField(
          id: 'content',
          label: 'Start writing...',
          placeholder: 'Whatever\'s on your mind',
          type: TemplateFieldType.multiline,
          maxLines: 10,
        ),
      ],
    ),
  ];
  
  static JournalTemplate? getById(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
  
  static List<JournalTemplate> getByCategory(String category) {
    return all.where((t) => t.category == category).toList();
  }
  
  static List<String> get categories {
    return all.map((t) => t.category).toSet().toList()..sort();
  }
}
