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

  PrivateUserPersona({
    required this.id,
    required this.aliasName,
    this.aliasAge,
    this.aliasGender,
    this.aliasDescription,
    this.aliasBackground,
    this.isActive = false,
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
    return parts.join('. ') + '.';
  }

  PrivateUserPersona copyWith({
    String? aliasName,
    int? aliasAge,
    String? aliasGender,
    String? aliasDescription,
    String? aliasBackground,
    bool? isActive,
  }) {
    return PrivateUserPersona(
      id: id,
      aliasName: aliasName ?? this.aliasName,
      aliasAge: aliasAge ?? this.aliasAge,
      aliasGender: aliasGender ?? this.aliasGender,
      aliasDescription: aliasDescription ?? this.aliasDescription,
      aliasBackground: aliasBackground ?? this.aliasBackground,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
