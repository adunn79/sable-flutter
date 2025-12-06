import 'package:hive/hive.dart';

part 'journal_bucket.g.dart';

/// Journal bucket (notebook) model - allows multiple journals
@HiveType(typeId: 1)
class JournalBucket extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String icon; // Emoji or icon name

  @HiveField(3)
  int colorValue; // Color as int for storage

  @HiveField(4)
  bool isVault; // If true, forces all entries to be private

  @HiveField(5)
  bool avatarAccessDefault; // Default privacy state for new entries

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  int entryCount; // Cached count for UI

  @HiveField(8)
  int sortOrder; // For reordering journals

  JournalBucket({
    required this.id,
    required this.name,
    this.icon = '📓',
    this.colorValue = 0xFF6B7280, // Default gray
    this.isVault = false,
    this.avatarAccessDefault = true, // Avatar can see by default
    DateTime? createdAt,
    this.entryCount = 0,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated fields
  JournalBucket copyWith({
    String? id,
    String? name,
    String? icon,
    int? colorValue,
    bool? isVault,
    bool? avatarAccessDefault,
    DateTime? createdAt,
    int? entryCount,
    int? sortOrder,
  }) {
    return JournalBucket(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      isVault: isVault ?? this.isVault,
      avatarAccessDefault: avatarAccessDefault ?? this.avatarAccessDefault,
      createdAt: createdAt ?? this.createdAt,
      entryCount: entryCount ?? this.entryCount,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'colorValue': colorValue,
      'isVault': isVault,
      'avatarAccessDefault': avatarAccessDefault,
      'createdAt': createdAt.toIso8601String(),
      'entryCount': entryCount,
      'sortOrder': sortOrder,
    };
  }

  /// Create from Firestore document
  factory JournalBucket.fromFirestore(Map<String, dynamic> data, String docId) {
    return JournalBucket(
      id: data['id'] ?? docId,
      name: data['name'] ?? 'Untitled',
      icon: data['icon'] ?? '📓',
      colorValue: data['colorValue'] ?? 0xFF6B7280,
      isVault: data['isVault'] ?? false,
      avatarAccessDefault: data['avatarAccessDefault'] ?? true,
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']) 
          : DateTime.now(),
      entryCount: data['entryCount'] ?? 0,
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  /// Default buckets for new users
  static List<JournalBucket> getDefaultBuckets() {
    return [
      JournalBucket(
        id: 'personal',
        name: 'Personal',
        icon: '✨',
        colorValue: 0xFF8B5CF6, // Purple
        avatarAccessDefault: true,
        sortOrder: 0,
      ),
      JournalBucket(
        id: 'gratitude',
        name: 'Gratitude',
        icon: '🙏',
        colorValue: 0xFF10B981, // Green
        avatarAccessDefault: true,
        sortOrder: 1,
      ),
      JournalBucket(
        id: 'vault',
        name: 'Private Vault',
        icon: '🔒',
        colorValue: 0xFFEF4444, // Red
        isVault: true,
        avatarAccessDefault: false,
        sortOrder: 2,
      ),
    ];
  }
}
