import 'package:hive/hive.dart';

part 'health_entry.g.dart';

/// Types of health/counseling entries
@HiveType(typeId: 13)
enum HealthEntryType {
  @HiveField(0)
  mood,          // Mood tracking

  @HiveField(1)
  counseling,    // Counseling session notes

  @HiveField(2)
  medication,    // Medication reminders/notes

  @HiveField(3)
  symptom,       // Symptom tracking

  @HiveField(4)
  therapy,       // Therapy exercises/notes

  @HiveField(5)
  crisis,        // Crisis moments

  @HiveField(6)
  achievement,   // Mental health wins
}

/// Health entry for encrypted storage
/// Contains sensitive health/counseling information
@HiveType(typeId: 14)
class HealthEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final HealthEntryType type;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final int? moodScore; // 1-10 for mood entries

  @HiveField(5)
  final List<String> tags;

  @HiveField(6)
  final bool isConfidential; // Extra flag for highly sensitive

  HealthEntry({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.moodScore,
    this.tags = const [],
    this.isConfidential = true,
  });

  factory HealthEntry.create({
    required HealthEntryType type,
    required String content,
    int? moodScore,
    List<String> tags = const [],
    bool isConfidential = true,
  }) {
    return HealthEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      content: content,
      timestamp: DateTime.now(),
      moodScore: moodScore,
      tags: tags,
      isConfidential: isConfidential,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'moodScore': moodScore,
    'tags': tags,
    'isConfidential': isConfidential,
  };
}
