import 'dart:convert';

class LocalVibeSettings {
  final bool useCurrentLocation;
  final double radiusMiles;
  final List<String> targetCities;
  final List<String> activeCategories;
  final List<String> customCategories;

  const LocalVibeSettings({
    this.useCurrentLocation = true,
    this.radiusMiles = 10.0,
    this.targetCities = const [],
    this.activeCategories = const [
      'Hyper-local News',
      'Events',
      'Concerts',
      'Sales',
      'Community Meetings'
    ],
    this.customCategories = const [],
  });

  LocalVibeSettings copyWith({
    bool? useCurrentLocation,
    double? radiusMiles,
    List<String>? targetCities,
    List<String>? activeCategories,
    List<String>? customCategories,
  }) {
    return LocalVibeSettings(
      useCurrentLocation: useCurrentLocation ?? this.useCurrentLocation,
      radiusMiles: radiusMiles ?? this.radiusMiles,
      targetCities: targetCities ?? this.targetCities,
      activeCategories: activeCategories ?? this.activeCategories,
      customCategories: customCategories ?? this.customCategories,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'useCurrentLocation': useCurrentLocation,
      'radiusMiles': radiusMiles,
      'targetCities': targetCities,
      'activeCategories': activeCategories,
      'customCategories': customCategories,
    };
  }

  factory LocalVibeSettings.fromMap(Map<String, dynamic> map) {
    return LocalVibeSettings(
      useCurrentLocation: map['useCurrentLocation'] ?? true,
      radiusMiles: (map['radiusMiles'] ?? 10.0).toDouble(),
      targetCities: List<String>.from(map['targetCities'] ?? []),
      activeCategories: List<String>.from(map['activeCategories'] ?? [
        'Hyper-local News',
        'Events',
        'Concerts',
        'Sales',
        'Community Meetings'
      ]),
      customCategories: List<String>.from(map['customCategories'] ?? []),
    );
  }

  String toJson() => json.encode(toMap());

  factory LocalVibeSettings.fromJson(String source) => LocalVibeSettings.fromMap(json.decode(source));
}
