import 'dart:convert';

class AvatarConfig {
  final String archetype; // Sable, Kai, or Echo
  final int apparentAge; // Min 18
  final String origin; // Country and region for accent
  final String build; // Petite, Athletic, Curvy, Lean/Tall
  final String skinTone; // Porcelain, Fair (Cool), etc.
  final String eyeColor; // Onyx Black, Steel Grey, etc.
  final String hairStyle; // Platinum Bob, Jet Black Sleek, etc.
  final String fashionAesthetic; // Executive, Casual, etc.
  final String distinguishingMark; // None, Beauty Mark, etc.

  AvatarConfig({
    required this.archetype,
    required this.apparentAge,
    required this.origin,
    required this.build,
    required this.skinTone,
    required this.eyeColor,
    required this.hairStyle,
    required this.fashionAesthetic,
    required this.distinguishingMark,
  });

  /// Generate fal.ai prompt from configuration
  String toPrompt() {
    String markText = distinguishingMark == 'None (Flawless)' ? '' : ', $distinguishingMark';
    return "A high-quality, cinematic portrait of a $apparentAge year old $build build $archetype "
        "with $skinTone skin tone, $eyeColor eyes, $hairStyle hairstyle. "
        "Wearing $fashionAesthetic style clothing$markText. "
        "Origin: $origin for accent. "
        "Detailed skin texture, futuristic lighting, 8k resolution, unreal engine 5 render.";
  }

  Map<String, dynamic> toJson() {
    return {
      'archetype': archetype,
      'apparentAge': apparentAge,
      'origin': origin,
      'build': build,
      'skinTone': skinTone,
      'eyeColor': eyeColor,
      'hairStyle': hairStyle,
      'fashionAesthetic': fashionAesthetic,
      'distinguishingMark': distinguishingMark,
    };
  }

  factory AvatarConfig.fromJson(Map<String, dynamic> json) {
    return AvatarConfig(
      archetype: json['archetype'] as String,
      apparentAge: json['apparentAge'] as int,
      origin: json['origin'] as String,
      build: json['build'] as String,
      skinTone: json['skinTone'] as String,
      eyeColor: json['eyeColor'] as String,
      hairStyle: json['hairStyle'] as String,
      fashionAesthetic: json['fashionAesthetic'] as String,
      distinguishingMark: json['distinguishingMark'] as String,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AvatarConfig.fromJsonString(String jsonString) {
    return AvatarConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  AvatarConfig copyWith({
    String? archetype,
    int? apparentAge,
    String? origin,
    String? build,
    String? skinTone,
    String? eyeColor,
    String? hairStyle,
    String? fashionAesthetic,
    String? distinguishingMark,
  }) {
    return AvatarConfig(
      archetype: archetype ?? this.archetype,
      apparentAge: apparentAge ?? this.apparentAge,
      origin: origin ?? this.origin,
      build: build ?? this.build,
      skinTone: skinTone ?? this.skinTone,
      eyeColor: eyeColor ?? this.eyeColor,
      hairStyle: hairStyle ?? this.hairStyle,
      fashionAesthetic: fashionAesthetic ?? this.fashionAesthetic,
      distinguishingMark: distinguishingMark ?? this.distinguishingMark,
    );
  }
}
