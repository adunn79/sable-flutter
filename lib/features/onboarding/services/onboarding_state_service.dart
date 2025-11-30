import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStateService {
  static const String _keyOnboardingComplete = 'onboarding_complete';
  static const String _keyRemainingGenerations = 'remaining_generations';
  static const int _initialGenerations = 3;

  static const String _keyAvatarUrl = 'avatar_url';

  final SharedPreferences _prefs;

  OnboardingStateService(this._prefs);

  static Future<OnboardingStateService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingStateService(prefs);
  }

  /// Check if onboarding has been completed
  bool get isOnboardingComplete {
    return _prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    await _prefs.setBool(_keyOnboardingComplete, true);
  }

  /// Get remaining avatar generations
  int get remainingGenerations {
    return _prefs.getInt(_keyRemainingGenerations) ?? _initialGenerations;
  }

  /// Check if user has generations remaining
  bool get hasGenerationsRemaining {
    return remainingGenerations > 0;
  }

  /// Decrement generation count
  Future<bool> decrementGenerations() async {
    final current = remainingGenerations;
    if (current > 0) {
      await _prefs.setInt(_keyRemainingGenerations, current - 1);
      return true;
    }
    return false;
  }

  /// Reset generation count (for testing or purchases)
  Future<void> resetGenerations([int count = 3]) async {
    await _prefs.setInt(_keyRemainingGenerations, count);
  }

  /// Get saved avatar URL
  String? get avatarUrl {
    return _prefs.getString(_keyAvatarUrl);
  }

  /// Save avatar URL
  Future<void> saveAvatarUrl(String url) async {
    await _prefs.setString(_keyAvatarUrl, url);
  }

  static const String _keyUserName = 'user_name';
  static const String _keyUserDob = 'user_dob';
  static const String _keyUserLocation = 'user_location';
  static const String _keyUserGender = 'user_gender';

  /// Save user profile data
  Future<void> saveUserProfile({
    required String name,
    required DateTime dob,
    required String location,
    String? gender,
  }) async {
    await _prefs.setString(_keyUserName, name);
    await _prefs.setString(_keyUserDob, dob.toIso8601String());
    await _prefs.setString(_keyUserLocation, location);
    if (gender != null) {
      await _prefs.setString(_keyUserGender, gender);
    }
  }

  /// Get user name
  String? get userName => _prefs.getString(_keyUserName);

  /// Get user date of birth
  DateTime? get userDob {
    final dobStr = _prefs.getString(_keyUserDob);
    if (dobStr == null) return null;
    return DateTime.tryParse(dobStr);
  }

  /// Get user location
  String? get userLocation => _prefs.getString(_keyUserLocation);

  /// Get user gender
  String? get userGender => _prefs.getString(_keyUserGender);

  /// Clear all onboarding data (for testing)
  Future<void> clearOnboardingData() async {
    await _prefs.remove(_keyOnboardingComplete);
    await _prefs.remove(_keyRemainingGenerations);
    await _prefs.remove(_keyAvatarUrl);
    await _prefs.remove(_keyUserName);
    await _prefs.remove(_keyUserDob);
    await _prefs.remove(_keyUserLocation);
    await _prefs.remove(_keyUserGender);
  }
}
