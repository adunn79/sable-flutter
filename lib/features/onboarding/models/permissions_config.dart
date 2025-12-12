import 'dart:convert';

class PermissionsConfig {
  final bool gpsEnabled;
  final bool webAccessEnabled;
  final bool calendarEnabled;
  final bool micEnabled;
  final bool cameraEnabled;
  final bool contactsEnabled;
  final bool photosEnabled;
  final bool healthEnabled;
  final bool remindersEnabled;
  final bool speechEnabled;

  PermissionsConfig({
    required this.gpsEnabled,
    required this.webAccessEnabled,
    this.calendarEnabled = false,
    this.micEnabled = false,
    this.cameraEnabled = false,
    this.contactsEnabled = false,
    this.photosEnabled = false,
    this.healthEnabled = false,
    this.remindersEnabled = false,
    this.speechEnabled = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'gpsEnabled': gpsEnabled,
      'webAccessEnabled': webAccessEnabled,
      'calendarEnabled': calendarEnabled,
      'micEnabled': micEnabled,
      'cameraEnabled': cameraEnabled,
      'contactsEnabled': contactsEnabled,
      'photosEnabled': photosEnabled,
      'healthEnabled': healthEnabled,
      'remindersEnabled': remindersEnabled,
      'speechEnabled': speechEnabled,
    };
  }

  factory PermissionsConfig.fromJson(Map<String, dynamic> json) {
    return PermissionsConfig(
      gpsEnabled: json['gpsEnabled'] as bool? ?? false,
      webAccessEnabled: json['webAccessEnabled'] as bool? ?? false,
      calendarEnabled: json['calendarEnabled'] as bool? ?? false,
      micEnabled: json['micEnabled'] as bool? ?? false,
      cameraEnabled: json['cameraEnabled'] as bool? ?? false,
      contactsEnabled: json['contactsEnabled'] as bool? ?? false,
      photosEnabled: json['photosEnabled'] as bool? ?? false,
      healthEnabled: json['healthEnabled'] as bool? ?? false,
      remindersEnabled: json['remindersEnabled'] as bool? ?? false,
      speechEnabled: json['speechEnabled'] as bool? ?? false,
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
    bool? micEnabled,
    bool? cameraEnabled,
    bool? contactsEnabled,
    bool? photosEnabled,
    bool? healthEnabled,
    bool? remindersEnabled,
    bool? speechEnabled,
  }) {
    return PermissionsConfig(
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      webAccessEnabled: webAccessEnabled ?? this.webAccessEnabled,
      calendarEnabled: calendarEnabled ?? this.calendarEnabled,
      micEnabled: micEnabled ?? this.micEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      contactsEnabled: contactsEnabled ?? this.contactsEnabled,
      photosEnabled: photosEnabled ?? this.photosEnabled,
      healthEnabled: healthEnabled ?? this.healthEnabled,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      speechEnabled: speechEnabled ?? this.speechEnabled,
    );
  }
}
