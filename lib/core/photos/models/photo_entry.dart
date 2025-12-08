import 'package:hive_flutter/hive_flutter.dart';

part 'photo_entry.g.dart';

/// Represents a photo in the app library
/// Storage: References device photos by default, copies to encrypted storage if private
@HiveType(typeId: 60)
class PhotoEntry extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String originalPath; // Device photo path
  
  @HiveField(2)
  String? privatePath; // Encrypted copy path (only if isPrivate)
  
  @HiveField(3)
  String? thumbnailPath;
  
  @HiveField(4)
  bool isPrivate;
  
  @HiveField(5)
  final DateTime createdAt; // When added to app
  
  @HiveField(6)
  DateTime? takenAt; // From EXIF or file date
  
  @HiveField(7)
  String? location; // From EXIF GPS or manual
  
  @HiveField(8)
  String? caption;
  
  @HiveField(9)
  List<String> tags;
  
  @HiveField(10)
  String? linkedJournalId; // If attached to journal entry
  
  @HiveField(11)
  String? aiDescription; // AI-generated description (only for non-private)

  PhotoEntry({
    required this.id,
    required this.originalPath,
    this.privatePath,
    this.thumbnailPath,
    this.isPrivate = false,
    required this.createdAt,
    this.takenAt,
    this.location,
    this.caption,
    List<String>? tags,
    this.linkedJournalId,
    this.aiDescription,
  }) : tags = tags ?? [];

  /// Get the path to display this photo
  /// Returns private path if private and exists, otherwise original
  String get displayPath => (isPrivate && privatePath != null) ? privatePath! : originalPath;
  
  /// Check if this photo can be sent to AI
  bool get canSendToAI => !isPrivate;
  
  /// Create a copy with updated fields
  PhotoEntry copyWith({
    String? id,
    String? originalPath,
    String? privatePath,
    String? thumbnailPath,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? takenAt,
    String? location,
    String? caption,
    List<String>? tags,
    String? linkedJournalId,
    String? aiDescription,
  }) {
    return PhotoEntry(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      privatePath: privatePath ?? this.privatePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      takenAt: takenAt ?? this.takenAt,
      location: location ?? this.location,
      caption: caption ?? this.caption,
      tags: tags ?? List.from(this.tags),
      linkedJournalId: linkedJournalId ?? this.linkedJournalId,
      aiDescription: aiDescription ?? this.aiDescription,
    );
  }
  
  /// Convert to JSON for backup
  Map<String, dynamic> toJson() => {
    'id': id,
    'originalPath': originalPath,
    'privatePath': privatePath,
    'thumbnailPath': thumbnailPath,
    'isPrivate': isPrivate,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'takenAt': takenAt?.millisecondsSinceEpoch,
    'location': location,
    'caption': caption,
    'tags': tags,
    'linkedJournalId': linkedJournalId,
    'aiDescription': aiDescription,
  };
  
  /// Create from JSON (for restore)
  factory PhotoEntry.fromJson(Map<String, dynamic> json) => PhotoEntry(
    id: json['id'] as String,
    originalPath: json['originalPath'] as String,
    privatePath: json['privatePath'] as String?,
    thumbnailPath: json['thumbnailPath'] as String?,
    isPrivate: json['isPrivate'] as bool? ?? false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    takenAt: json['takenAt'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(json['takenAt'] as int) 
        : null,
    location: json['location'] as String?,
    caption: json['caption'] as String?,
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    linkedJournalId: json['linkedJournalId'] as String?,
    aiDescription: json['aiDescription'] as String?,
  );
}
