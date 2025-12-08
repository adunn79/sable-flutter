import 'package:hive/hive.dart';

part 'journal_entry.g.dart';

/// Journal entry model with Hive TypeAdapter
@HiveType(typeId: 0)
class JournalEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String content; // Rich text JSON from flutter_quill

  @HiveField(2)
  String plainText; // Plain text for search/analysis

  @HiveField(3)
  DateTime timestamp;

  @HiveField(4)
  DateTime? updatedAt;

  @HiveField(5)
  String bucketId; // Which journal this belongs to

  @HiveField(6)
  List<String> tags;

  @HiveField(7)
  int? moodScore; // 1-5 scale (1=sad, 5=happy)

  @HiveField(8)
  bool isPrivate; // Eye toggle - false = Avatar can see

  @HiveField(9)
  String? location; // City/place name

  @HiveField(10)
  double? latitude;

  @HiveField(11)
  double? longitude;

  @HiveField(12)
  String? weather; // e.g., "Partly Cloudy, 46°F"

  @HiveField(13)
  List<String> mediaUrls; // Attached photos/audio/video

  @HiveField(14)
  String? embeddingRef; // Reference to vector DB entry

  @HiveField(15)
  bool isSynced; // Whether synced to Firestore

  @HiveField(16)
  String? firestoreId; // Firestore document ID

  @HiveField(17)
  bool isHidden; // Hidden from timeline view
  
  @HiveField(18)
  int? stepCount; // Steps from device at time of entry
  
  @HiveField(19)
  String? nowPlayingTrack; // Song playing when entry created
  
  @HiveField(20)
  String? nowPlayingArtist; // Artist of song playing
  
  @HiveField(21)
  double? weightLbs; // Weight if user tracking
  
  @HiveField(22)
  int? heartRate; // Heart rate if available

  JournalEntry({
    required this.id,
    required this.content,
    required this.plainText,
    required this.timestamp,
    this.updatedAt,
    required this.bucketId,
    this.tags = const [],
    this.moodScore,
    this.isPrivate = false,
    this.location,
    this.latitude,
    this.longitude,
    this.weather,
    this.mediaUrls = const [],
    this.embeddingRef,
    this.isSynced = false,
    this.firestoreId,
    this.isHidden = false,
    this.stepCount,
    this.nowPlayingTrack,
    this.nowPlayingArtist,
    this.weightLbs,
    this.heartRate,
  });

  /// Create a copy with updated fields
  JournalEntry copyWith({
    String? id,
    String? content,
    String? plainText,
    DateTime? timestamp,
    DateTime? updatedAt,
    String? bucketId,
    List<String>? tags,
    int? moodScore,
    bool? isPrivate,
    String? location,
    double? latitude,
    double? longitude,
    String? weather,
    List<String>? mediaUrls,
    String? embeddingRef,
    bool? isSynced,
    String? firestoreId,
    bool? isHidden,
    int? stepCount,
    String? nowPlayingTrack,
    String? nowPlayingArtist,
    double? weightLbs,
    int? heartRate,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      plainText: plainText ?? this.plainText,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
      bucketId: bucketId ?? this.bucketId,
      tags: tags ?? this.tags,
      moodScore: moodScore ?? this.moodScore,
      isPrivate: isPrivate ?? this.isPrivate,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      weather: weather ?? this.weather,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      embeddingRef: embeddingRef ?? this.embeddingRef,
      isSynced: isSynced ?? this.isSynced,
      firestoreId: firestoreId ?? this.firestoreId,
      isHidden: isHidden ?? this.isHidden,
      stepCount: stepCount ?? this.stepCount,
      nowPlayingTrack: nowPlayingTrack ?? this.nowPlayingTrack,
      nowPlayingArtist: nowPlayingArtist ?? this.nowPlayingArtist,
      weightLbs: weightLbs ?? this.weightLbs,
      heartRate: heartRate ?? this.heartRate,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'content': content,
      'plainText': plainText,
      'timestamp': timestamp.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'bucketId': bucketId,
      'tags': tags,
      'moodScore': moodScore,
      'isPrivate': isPrivate,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'weather': weather,
      'mediaUrls': mediaUrls,
      'embeddingRef': embeddingRef,
      'stepCount': stepCount,
      'nowPlayingTrack': nowPlayingTrack,
      'nowPlayingArtist': nowPlayingArtist,
      'weightLbs': weightLbs,
      'heartRate': heartRate,
    };
  }

  /// Create from Firestore document
  factory JournalEntry.fromFirestore(Map<String, dynamic> data, String docId) {
    return JournalEntry(
      id: data['id'] ?? docId,
      content: data['content'] ?? '',
      plainText: data['plainText'] ?? '',
      timestamp: DateTime.parse(data['timestamp']),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : null,
      bucketId: data['bucketId'] ?? 'default',
      tags: List<String>.from(data['tags'] ?? []),
      moodScore: data['moodScore'],
      isPrivate: data['isPrivate'] ?? false,
      location: data['location'],
      latitude: data['latitude'],
      longitude: data['longitude'],
      weather: data['weather'],
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      embeddingRef: data['embeddingRef'],
      isSynced: true,
      firestoreId: docId,
      stepCount: data['stepCount'],
      nowPlayingTrack: data['nowPlayingTrack'],
      nowPlayingArtist: data['nowPlayingArtist'],
      weightLbs: (data['weightLbs'] as num?)?.toDouble(),
      heartRate: data['heartRate'],
    );
  }
}
