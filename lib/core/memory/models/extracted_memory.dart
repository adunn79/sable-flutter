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
/// Enhanced with rich contextual data for immersive time capsules
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

  // === LOCATION CONTEXT ===
  @HiveField(7)
  final String? locationName; // "Mission District, SF"
  
  @HiveField(8)
  final double? latitude;
  
  @HiveField(9)
  final double? longitude;
  
  @HiveField(10)
  final String? weather; // "Sunny, 72°F"

  // === VIBE CAPTURE ===
  @HiveField(11)
  final int? energyLevel; // 1-10 slider
  
  @HiveField(12)
  final String? vibeColor; // Hex gradient "#FFD700"
  
  @HiveField(13)
  final String? ambientDescription; // "Busy café, rain outside"

  // === SOCIAL CONTEXT ===
  @HiveField(14)
  final List<String> taggedPeople; // ["Mom", "Jake"]
  
  @HiveField(15)
  final bool isGroupActivity;

  // === MEDIA ===
  @HiveField(16)
  final String? nowPlayingTrack; // "Song - Artist"
  
  @HiveField(17)
  final String? nowPlayingService; // "spotify" or "apple_music"
  
  @HiveField(18)
  final List<String> attachedPhotoPaths;

  // === WORLD CONTEXT ===
  @HiveField(19)
  final String? topHeadline; // Breaking news
  
  @HiveField(20)
  final String? onThisDay; // Historical event

  // === HEALTH (optional) ===
  @HiveField(21)
  final int? sleepHours;
  
  @HiveField(22)
  final int? stepCount;

  // === SUMMARY ===
  @HiveField(23)
  final String? oneSentenceSummary; // User's title

  ExtractedMemory({
    required this.id,
    required this.content,
    required this.category,
    required this.extractedAt,
    this.sourceMessageId,
    this.tags = const [],
    this.importance = 3,
    // Location
    this.locationName,
    this.latitude,
    this.longitude,
    this.weather,
    // Vibe
    this.energyLevel,
    this.vibeColor,
    this.ambientDescription,
    // Social
    this.taggedPeople = const [],
    this.isGroupActivity = false,
    // Media
    this.nowPlayingTrack,
    this.nowPlayingService,
    this.attachedPhotoPaths = const [],
    // World
    this.topHeadline,
    this.onThisDay,
    // Health
    this.sleepHours,
    this.stepCount,
    // Summary
    this.oneSentenceSummary,
  });

  factory ExtractedMemory.create({
    required String content,
    required MemoryCategory category,
    String? sourceMessageId,
    List<String> tags = const [],
    int importance = 3,
    // Location
    String? locationName,
    double? latitude,
    double? longitude,
    String? weather,
    // Vibe
    int? energyLevel,
    String? vibeColor,
    String? ambientDescription,
    // Social
    List<String> taggedPeople = const [],
    bool isGroupActivity = false,
    // Media
    String? nowPlayingTrack,
    String? nowPlayingService,
    List<String> attachedPhotoPaths = const [],
    // World
    String? topHeadline,
    String? onThisDay,
    // Health
    int? sleepHours,
    int? stepCount,
    // Summary
    String? oneSentenceSummary,
  }) {
    return ExtractedMemory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      category: category,
      extractedAt: DateTime.now(),
      sourceMessageId: sourceMessageId,
      tags: tags,
      importance: importance,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      weather: weather,
      energyLevel: energyLevel,
      vibeColor: vibeColor,
      ambientDescription: ambientDescription,
      taggedPeople: taggedPeople,
      isGroupActivity: isGroupActivity,
      nowPlayingTrack: nowPlayingTrack,
      nowPlayingService: nowPlayingService,
      attachedPhotoPaths: attachedPhotoPaths,
      topHeadline: topHeadline,
      onThisDay: onThisDay,
      sleepHours: sleepHours,
      stepCount: stepCount,
      oneSentenceSummary: oneSentenceSummary,
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
    // Location
    'locationName': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'weather': weather,
    // Vibe
    'energyLevel': energyLevel,
    'vibeColor': vibeColor,
    'ambientDescription': ambientDescription,
    // Social
    'taggedPeople': taggedPeople,
    'isGroupActivity': isGroupActivity,
    // Media
    'nowPlayingTrack': nowPlayingTrack,
    'nowPlayingService': nowPlayingService,
    'attachedPhotoPaths': attachedPhotoPaths,
    // World
    'topHeadline': topHeadline,
    'onThisDay': onThisDay,
    // Health
    'sleepHours': sleepHours,
    'stepCount': stepCount,
    // Summary
    'oneSentenceSummary': oneSentenceSummary,
  };

  /// Check if this memory matches search query
  bool matchesQuery(String query) {
    final lowerQuery = query.toLowerCase();
    return content.toLowerCase().contains(lowerQuery) ||
        tags.any((tag) => tag.toLowerCase().contains(lowerQuery)) ||
        (locationName?.toLowerCase().contains(lowerQuery) ?? false) ||
        taggedPeople.any((p) => p.toLowerCase().contains(lowerQuery)) ||
        (oneSentenceSummary?.toLowerCase().contains(lowerQuery) ?? false);
  }
  
  /// Get a display-friendly location string
  String get locationDisplay {
    if (locationName != null) return locationName!;
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
    }
    return 'Unknown location';
  }
  
  /// Get vibe summary string
  String get vibeSummary {
    final parts = <String>[];
    if (energyLevel != null) parts.add('Energy: $energyLevel/10');
    if (weather != null) parts.add(weather!);
    if (ambientDescription != null) parts.add(ambientDescription!);
    return parts.isEmpty ? 'No vibe captured' : parts.join(' • ');
  }
}

