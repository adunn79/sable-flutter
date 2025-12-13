import 'package:hive/hive.dart';

part 'private_user_persona.g.dart';

/// User's alternate persona/alias for Private Space
/// Allows complete roleplay immersion with different identity
@HiveType(typeId: 51)
class PrivateUserPersona extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String aliasName;

  @HiveField(2)
  int? aliasAge;

  @HiveField(3)
  String? aliasGender; // 'male', 'female', 'non-binary', 'other', or custom

  @HiveField(4)
  String? aliasDescription; // Brief character description

  @HiveField(5)
  String? aliasBackground; // Backstory for roleplay context

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  double libido; // 0.0 to 1.0

  @HiveField(9)
  double creativity;

  @HiveField(10)
  double empathy;

  @HiveField(11)
  double humor;

  @HiveField(12)
  String? avatarId; // Specific avatar for this persona

  @HiveField(13)
  double intelligence; // 0.0 to 1.0

  PrivateUserPersona({
    required this.id,
    required this.aliasName,
    this.aliasAge = 21, // Private default: 21
    this.aliasGender,
    this.aliasDescription,
    this.aliasBackground,
    this.isActive = false,
    this.libido = 0.5,
    this.creativity = 0.7,
    this.empathy = 0.8,
    this.humor = 0.6,
    this.avatarId,
    this.intelligence = 0.35, // Private default: 35% (-10% from main 45%)
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PrivateUserPersona.create({
    required String name,
    int? age,
    String? gender,
    String? description,
    String? background,
  }) {
    return PrivateUserPersona(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      aliasName: name,
      aliasAge: age,
      aliasGender: gender,
      aliasDescription: description,
      aliasBackground: background,
    );
  }

  /// Get a formatted introduction for AI context
  String getAIContext() {
    final parts = <String>[];
    parts.add('My name is $aliasName');
    if (aliasAge != null) parts.add('I am $aliasAge years old');
    if (aliasGender != null) parts.add('I identify as $aliasGender');
    if (aliasDescription != null) parts.add(aliasDescription!);
    if (aliasBackground != null) parts.add('Background: $aliasBackground');
    
    // Add personality/drive context for AI
    parts.add('Libido/Drive Level: ${(libido * 100).toInt()}%');
    parts.add('Desired Companion Vibe: Creativity ${(creativity * 100).toInt()}%, Empathy ${(empathy * 100).toInt()}%, Humor ${(humor * 100).toInt()}%');
    
    return parts.join('. ') + '.';
  }

  PrivateUserPersona copyWith({
    String? aliasName,
    int? aliasAge,
    String? aliasGender,
    String? aliasDescription,
    String? aliasBackground,
    bool? isActive,
    double? libido,
    double? creativity,
    double? empathy,
    double? humor,
    String? avatarId,
    double? intelligence,
  }) {
    return PrivateUserPersona(
      id: id,
      aliasName: aliasName ?? this.aliasName,
      aliasAge: aliasAge ?? this.aliasAge,
      aliasGender: aliasGender ?? this.aliasGender,
      aliasDescription: aliasDescription ?? this.aliasDescription,
      aliasBackground: aliasBackground ?? this.aliasBackground,
      isActive: isActive ?? this.isActive,
      libido: libido ?? this.libido,
      creativity: creativity ?? this.creativity,
      empathy: empathy ?? this.empathy,
      humor: humor ?? this.humor,
      avatarId: avatarId ?? this.avatarId,
      intelligence: intelligence ?? this.intelligence,
      createdAt: createdAt,
    );
  }
}
