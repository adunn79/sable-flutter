import 'dart:convert';

class PermissionsConfig {
  final bool gpsEnabled;
  final bool webAccessEnabled;
  final bool calendarEnabled;

  PermissionsConfig({
    required this.gpsEnabled,
    required this.webAccessEnabled,
    this.calendarEnabled = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'gpsEnabled': gpsEnabled,
      'webAccessEnabled': webAccessEnabled,
      'calendarEnabled': calendarEnabled,
    };
  }

  factory PermissionsConfig.fromJson(Map<String, dynamic> json) {
    return PermissionsConfig(
      gpsEnabled: json['gpsEnabled'] as bool? ?? false,
      webAccessEnabled: json['webAccessEnabled'] as bool? ?? false,
      calendarEnabled: json['calendarEnabled'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PermissionsConfig.fromJsonString(String jsonString) {
    return PermissionsConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  PermissionsConfig copyWith({
    bool? gpsEnabled,
    bool? webAccessEnabled,
    bool? calendarEnabled,
  }) {
    return PermissionsConfig(
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      webAccessEnabled: webAccessEnabled ?? this.webAccessEnabled,
      calendarEnabled: calendarEnabled ?? this.calendarEnabled,
    );
  }
}
