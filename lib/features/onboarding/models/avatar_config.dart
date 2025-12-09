import 'dart:convert';

class AvatarConfig {
  final String archetype; // Sable, Kai, or Echo
  final String gender; // Female, Male, Non-binary
  final int apparentAge; // Min 18
  final String origin; // Country and region for accent
  final String race; // Caucasian, Asian, Black, etc.
  final String build; // Petite, Athletic, Curvy, Lean/Tall
  final String skinTone; // Porcelain, Fair (Cool), etc.
  final String eyeColor; // Onyx Black, Steel Grey, etc.
  final String hairStyle; // Platinum Bob, Jet Black Sleek, etc.
  final String fashionAesthetic; // Executive, Casual, etc.
  final String distinguishingMark; // None, Beauty Mark, etc.
  final String? selectedVoiceId; // ElevenLabs voice ID (optional)

  AvatarConfig({
    required this.archetype,
    required this.gender,
    required this.apparentAge,
    required this.origin,
    required this.race,
    required this.build,
    required this.skinTone,
    required this.eyeColor,
    required this.hairStyle,
    required this.fashionAesthetic,
    required this.distinguishingMark,
    this.selectedVoiceId,
  });

  /// Generate fal.ai prompt from configuration
  String toPrompt() {
    String markText = distinguishingMark == 'None (Flawless)' ? '' : ', $distinguishingMark';
    
    // Determine gender term
    String genderTerm = 'person';
    if (gender.toLowerCase().contains('female') || gender.toLowerCase().contains('she')) {
      genderTerm = 'woman';
    } else if (gender.toLowerCase().contains('male') || gender.toLowerCase().contains('he')) {
      genderTerm = 'man';
    }

    return "A hyper-realistic, cinematic portrait of a $apparentAge year old $race $genderTerm, $build build. "
        "Appearance: $skinTone skin tone, $eyeColor eyes, $hairStyle hairstyle. "
        "Wearing $fashionAesthetic style clothing$markText. "
        "Style: Award-winning photography, 8k resolution, highly detailed, photorealistic, dramatic lighting, shot on 35mm lens. "
        "NO anime, NO cartoon, NO illustration, NO 3d render, NO drawing.";
  }

  Map<String, dynamic> toJson() {
    return {
      'archetype': archetype,
      'gender': gender,
      'apparentAge': apparentAge,
      'origin': origin,
      'race': race,
      'build': build,
      'skinTone': skinTone,
      'eyeColor': eyeColor,
      'hairStyle': hairStyle,
      'fashionAesthetic': fashionAesthetic,
      'distinguishingMark': distinguishingMark,
      'selectedVoiceId': selectedVoiceId,
    };
  }

  factory AvatarConfig.fromJson(Map<String, dynamic> json) {
    return AvatarConfig(
      archetype: json['archetype'] as String,
      gender: json['gender'] as String? ?? 'Female', // Default for backward compatibility
      apparentAge: json['apparentAge'] as int,
      origin: json['origin'] as String,
      race: json['race'] as String? ?? 'Synthetic Human', // Default
      build: json['build'] as String,
      skinTone: json['skinTone'] as String,
      eyeColor: json['eyeColor'] as String,
      hairStyle: json['hairStyle'] as String,
      fashionAesthetic: json['fashionAesthetic'] as String,
      distinguishingMark: json['distinguishingMark'] as String,
      selectedVoiceId: json['selectedVoiceId'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AvatarConfig.fromJsonString(String jsonString) {
    return AvatarConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  AvatarConfig copyWith({
    String? archetype,
    String? gender,
    int? apparentAge,
    String? origin,
    String? race,
    String? build,
    String? skinTone,
    String? eyeColor,
    String? hairStyle,
    String? fashionAesthetic,
    String? distinguishingMark,
    String? selectedVoiceId,
  }) {
    return AvatarConfig(
      archetype: archetype ?? this.archetype,
      gender: gender ?? this.gender,
      apparentAge: apparentAge ?? this.apparentAge,
      origin: origin ?? this.origin,
      race: race ?? this.race,
      build: build ?? this.build,
      skinTone: skinTone ?? this.skinTone,
      eyeColor: eyeColor ?? this.eyeColor,
      hairStyle: hairStyle ?? this.hairStyle,
      fashionAesthetic: fashionAesthetic ?? this.fashionAesthetic,
      distinguishingMark: distinguishingMark ?? this.distinguishingMark,
      selectedVoiceId: selectedVoiceId ?? this.selectedVoiceId,
    );
  }
}
