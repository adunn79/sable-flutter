import 'package:hive/hive.dart';

part 'extracted_memory.g.dart';

/// Categories for extracted memories
@HiveType(typeId: 11)
enum MemoryCategory {
  @HiveField(0)
  people,      // Names of family, friends, coworkers

  @HiveField(1)
  preferences, // Likes, dislikes, favorites

  @HiveField(2)
  dates,       // Birthdays, anniversaries, important dates

  @HiveField(3)
  life,        // Job, hobbies, living situation

  @HiveField(4)
  emotional,   // Emotional patterns, triggers, coping

  @HiveField(5)
  goals,       // Goals, aspirations, dreams

  @HiveField(6)
  misc,        // Other important facts
}

/// Extracted memory from conversations
/// AI identifies key facts and stores them for recall
@HiveType(typeId: 12)
class ExtractedMemory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content; // The actual memory/fact

  @HiveField(2)
  final MemoryCategory category;

  @HiveField(3)
  final DateTime extractedAt;

  @HiveField(4)
  final String? sourceMessageId; // Which message this came from

  @HiveField(5)
  final List<String> tags; // Searchable tags

  @HiveField(6)
  final int importance; // 1-5, for prioritization

  ExtractedMemory({
    required this.id,
    required this.content,
    required this.category,
    required this.extractedAt,
    this.sourceMessageId,
    this.tags = const [],
    this.importance = 3,
  });

  factory ExtractedMemory.create({
    required String content,
    required MemoryCategory category,
    String? sourceMessageId,
    List<String> tags = const [],
    int importance = 3,
  }) {
    return ExtractedMemory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      category: category,
      extractedAt: DateTime.now(),
      sourceMessageId: sourceMessageId,
      tags: tags,
      importance: importance,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'category': category.name,
    'extractedAt': extractedAt.toIso8601String(),
    'sourceMessageId': sourceMessageId,
    'tags': tags,
    'importance': importance,
  };

  /// Check if this memory matches search query
  bool matchesQuery(String query) {
    final lowerQuery = query.toLowerCase();
    return content.toLowerCase().contains(lowerQuery) ||
        tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
  }
}
