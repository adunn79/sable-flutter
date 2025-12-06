import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage avatar display preferences
class AvatarDisplaySettings {
  static const String _avatarModeKey = 'avatar_display_mode';
  static const String _backgroundColorKey = 'avatar_background_color';
  
  // Avatar display modes
  static const String modeFullscreen = 'fullscreen';
  static const String modeIcon = 'icon';
  static const String modeOrb = 'orb'; // Magic orb mode - animated flowing colors
  static const String modePortrait = 'portrait'; // High-quality avatar at top 30%
  
  // Background colors
  static const String colorBlack = 'black';
  static const String colorWhite = 'white';

  /// Get the current avatar display mode
  /// Returns 'fullscreen', 'icon', or 'orb', defaults to 'fullscreen'
  Future<String> getAvatarDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarModeKey) ?? modeFullscreen;
  }

  /// Set the avatar display mode
  Future<void> setAvatarDisplayMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarModeKey, mode);
  }

  /// Get the background color for icon mode
  /// Returns 'black' or 'white', defaults to 'black'
  Future<String> getBackgroundColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backgroundColorKey) ?? colorBlack;
  }

  /// Set the background color for icon mode
  Future<void> setBackgroundColor(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundColorKey, color);
  }
}
