import 'dart:convert';

class PermissionsConfig {
  final bool gpsEnabled;
  final bool webAccessEnabled;

  PermissionsConfig({
    required this.gpsEnabled,
    required this.webAccessEnabled,
  });

  Map<String, dynamic> toJson() {
    return {
      'gpsEnabled': gpsEnabled,
      'webAccessEnabled': webAccessEnabled,
    };
  }

  factory PermissionsConfig.fromJson(Map<String, dynamic> json) {
    return PermissionsConfig(
      gpsEnabled: json['gpsEnabled'] as bool? ?? false,
      webAccessEnabled: json['webAccessEnabled'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PermissionsConfig.fromJsonString(String jsonString) {
    return PermissionsConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  PermissionsConfig copyWith({
    bool? gpsEnabled,
    bool? webAccessEnabled,
  }) {
    return PermissionsConfig(
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      webAccessEnabled: webAccessEnabled ?? this.webAccessEnabled,
    );
  }
}
