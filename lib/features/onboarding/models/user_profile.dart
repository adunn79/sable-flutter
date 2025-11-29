import 'dart:convert';

class UserProfile {
  final String name;
  final DateTime dateOfBirth;
  final String location;
  final String? genderIdentity;

  UserProfile({
    required this.name,
    required this.dateOfBirth,
    required this.location,
    this.genderIdentity,
  });

  /// Check if user is 17 years or older
  bool isOver17() {
    final now = DateTime.now();
    final age = now.year - dateOfBirth.year;
    
    // Check if birthday hasn't occurred yet this year
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      return age - 1 >= 17;
    }
    
    return age >= 17;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'location': location,
      'genderIdentity': genderIdentity,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String,
      dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
      location: json['location'] as String,
      genderIdentity: json['genderIdentity'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJsonString(String jsonString) {
    return UserProfile.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}
