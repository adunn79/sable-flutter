import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStateService {
  static const String _keyOnboardingComplete = 'onboarding_complete';
  static const String _keyRemainingGenerations = 'remaining_generations';
  static const int _initialGenerations = 3;

  static const String _keyAvatarUrl = 'avatar_url';
  static const String _keySelectedVoiceId = 'selected_voice_id';

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

  static const String _keyAiOrigin = 'ai_origin';
  static const String _keyUserName = 'user_name';
  static const String _keyUserDob = 'user_dob';
  static const String _keyUserLocation = 'user_location'; // Birth place
  static const String _keyUserCurrentLocation = 'user_current_location'; // Current location
  static const String _keyUserGender = 'user_gender';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserEmail = 'user_email';
  
  // Daily news tracking
  static const String _keyLastInteractionDate = 'last_interaction_date';
  static const String _keyNewsEnabled = 'news_enabled';
  static const String _keyNewsCategories = 'news_categories';

  /// Save user profile data
  Future<void> saveUserProfile({
    required String name,
    required DateTime dob,
    required String location,
    String? currentLocation,
    String? gender,
    String? voiceId,
    String? aiOrigin,
    String? phone,
    String? email,
  }) async {
    await _prefs.setString(_keyUserName, name);
    await _prefs.setString(_keyUserDob, dob.toIso8601String());
    await _prefs.setString(_keyUserLocation, location);
    if (currentLocation != null) {
      await _prefs.setString(_keyUserCurrentLocation, currentLocation);
    }
    if (gender != null) {
      await _prefs.setString(_keyUserGender, gender);
    }
    if (voiceId != null) {
      await _prefs.setString(_keySelectedVoiceId, voiceId);
    }
    if (aiOrigin != null) {
      await _prefs.setString(_keyAiOrigin, aiOrigin);
    }
    if (phone != null) {
      await _prefs.setString(_keyUserPhone, phone);
    }
    if (email != null) {
      await _prefs.setString(_keyUserEmail, email);
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

  /// Get user location (birth place)
  String? get userLocation => _prefs.getString(_keyUserLocation);

  /// Get user current location
  String? get userCurrentLocation => _prefs.getString(_keyUserCurrentLocation);

  /// Get user gender
  String? get userGender => _prefs.getString(_keyUserGender);

  /// Get user phone
  String? get userPhone => _prefs.getString(_keyUserPhone);

  /// Get user email
  String? get userEmail => _prefs.getString(_keyUserEmail);

  /// Get selected voice ID
  String? get selectedVoiceId => _prefs.getString(_keySelectedVoiceId);

  /// Get AI Origin
  String? get aiOrigin => _prefs.getString(_keyAiOrigin);

  static const String _keyConversationCount = 'conversation_count';
  
  /// Get conversation count (for first-time feature introductions)
  int get conversationCount => _prefs.getInt(_keyConversationCount) ?? 0;
  
  /// Increment conversation count
  Future<void> incrementConversationCount() async {
    final current = conversationCount;
    await _prefs.setInt(_keyConversationCount, current + 1);
  }
  
  // ============================================
  // DAILY NEWS TRACKING
  // ============================================
  
  /// Check if this is the first interaction today
  Future<bool> isFirstInteractionToday() async {
    final lastDateStr = _prefs.getString(_keyLastInteractionDate);
    if (lastDateStr == null) return true;
    
    final lastDate = DateTime.parse(lastDateStr);
    final today = DateTime.now();
    
    // Check if dates are different days
    return lastDate.year != today.year ||
           lastDate.month != today.month ||
           lastDate.day != today.day;
  }
  
  /// Update last interaction date to today
  Future<void> updateLastInteractionDate() async {
    final today = DateTime.now().toIso8601String();
    await _prefs.setString(_keyLastInteractionDate, today);
  }
  
  /// Get last interaction date
  DateTime? get lastInteractionDate {
    final dateStr = _prefs.getString(_keyLastInteractionDate);
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }
  
  /// Check if daily news is enabled
  bool get newsEnabled {
    return _prefs.getBool(_keyNewsEnabled) ?? true; // Default enabled
  }
  
  /// Set news enabled/disabled
  Future<void> setNewsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNewsEnabled, enabled);
  }
  
  /// Get news categories
  List<String> get newsCategories {
    final categoriesStr = _prefs.getStringList(_keyNewsCategories);
    return categoriesStr ?? ['local', 'tech', 'national']; // Defaults
  }
  
  /// Set news categories
  Future<void> setNewsCategories(List<String> categories) async {
    await _prefs.setStringList(_keyNewsCategories, categories);
  }
  
  // ============================================
  // VAULT / MEMORY MANAGEMENT
  // ============================================
  
  static const String _keyMemoryItems = 'structured_memory_items';
  
  /// Get structured memory items (The Vault)
  List<String> get memoryItems {
    return _prefs.getStringList(_keyMemoryItems) ?? [
      // Default/Initial memories for demonstration if empty
      'User prefers concise answers.',
      'User is interested in AI technology.',
      'User values privacy and security.',
    ]; 
  }
  
  /// Add a memory item
  Future<void> addMemoryItem(String item) async {
    final items = memoryItems;
    items.add(item);
    await _prefs.setStringList(_keyMemoryItems, items);
  }
  
  /// Remove a memory item
  Future<void> removeMemoryItem(int index) async {
    final items = memoryItems;
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      await _prefs.setStringList(_keyMemoryItems, items);
    }
  }
  
  /// Wipe all memory (The Vault reset)
  Future<void> wipeAllMemory() async {
    await _prefs.remove(_keyMemoryItems);
    // Also clear other personal data if "Complete Wipe" is implied?
    // User said "wipe the Ai's memory completely". 
    // We might want to clear conversation history too if we had it stored here.
  }
  
  static const String _keyNewsTimingFirst = 'news_timing_first';
  static const String _keyNewsTimingOnDemand = 'news_timing_ondemand';
  static const String _keyDailyNewsContent = 'daily_news_content';
  static const String _keyDailyNewsDate = 'daily_news_date';

  /// Check if news categories have been set by user
  bool get hasSetNewsCategories {
    return _prefs.getStringList(_keyNewsCategories) != null;
  }

  /// Get news timing: First Interaction
  bool get newsTimingFirstInteraction {
    return _prefs.getBool(_keyNewsTimingFirst) ?? true;
  }

  /// Set news timing: First Interaction
  Future<void> setNewsTimingFirstInteraction(bool value) async {
    await _prefs.setBool(_keyNewsTimingFirst, value);
  }

  /// Get news timing: On Demand
  bool get newsTimingOnDemand {
    return _prefs.getBool(_keyNewsTimingOnDemand) ?? false;
  }

  /// Set news timing: On Demand
  Future<void> setNewsTimingOnDemand(bool value) async {
    await _prefs.setBool(_keyNewsTimingOnDemand, value);
  }

  // ============================================
  // FEEDBACK SETTINGS (Haptics & Sound)
  // ============================================
  static const String _keyHapticsEnabled = 'haptics_enabled';
  static const String _keySoundsEnabled = 'sounds_enabled';
  static const String _keyPersonalityId = 'selected_personality_id';

  /// Get haptics enabled status (Default: true)
  bool get hapticsEnabled => _prefs.getBool(_keyHapticsEnabled) ?? true;

  /// Set haptics enabled status
  Future<void> setHapticsEnabled(bool enabled) async {
    await _prefs.setBool(_keyHapticsEnabled, enabled);
  }

  /// Get UI sounds enabled status (Default: true)
  bool get soundsEnabled => _prefs.getBool(_keySoundsEnabled) ?? true;

  /// Set UI sounds enabled status
  Future<void> setSoundsEnabled(bool enabled) async {
    await _prefs.setBool(_keySoundsEnabled, enabled);
  }

  static const String _keyBrainCreativity = 'brain_creativity';
  static const String _keyBrainEmpathy = 'brain_empathy';
  static const String _keyBrainHumor = 'brain_humor';

  /// Get brain creativity level (Default: 0.5)
  double get brainCreativity => _prefs.getDouble(_keyBrainCreativity) ?? 0.5;

  /// Set brain creativity level
  Future<void> setBrainCreativity(double value) async {
    await _prefs.setDouble(_keyBrainCreativity, value);
  }

  /// Get brain empathy level (Default: 0.7)
  double get brainEmpathy => _prefs.getDouble(_keyBrainEmpathy) ?? 0.7;

  /// Set brain empathy level
  Future<void> setBrainEmpathy(double value) async {
    await _prefs.setDouble(_keyBrainEmpathy, value);
  }

  /// Get brain humor level (Default: 0.3)
  double get brainHumor => _prefs.getDouble(_keyBrainHumor) ?? 0.3;

  /// Set brain humor level
  Future<void> setBrainHumor(double value) async {
    await _prefs.setDouble(_keyBrainHumor, value);
  }

  /// Get selected personality ID (Default: 'sassy_realist')
  String get selectedPersonalityId => _prefs.getString(_keyPersonalityId) ?? 'sassy_realist';

  /// Set selected personality ID
  Future<void> setPersonalityId(String id) async {
    await _prefs.setString(_keyPersonalityId, id);
  }

  // ============================================
  // PERMISSIONS
  // ============================================
  static const String _keyPermissionGps = 'permission_gps';
  static const String _keyPermissionMic = 'permission_mic';
  static const String _keyPermissionCamera = 'permission_camera';

  /// Get GPS permission status (Default: true)
  bool get permissionGps => _prefs.getBool(_keyPermissionGps) ?? true;

  /// Set GPS permission status
  Future<void> setPermissionGps(bool enabled) async {
    await _prefs.setBool(_keyPermissionGps, enabled);
  }

  /// Get Microphone permission status (Default: true)
  bool get permissionMic => _prefs.getBool(_keyPermissionMic) ?? true;

  /// Set Microphone permission status
  Future<void> setPermissionMic(bool enabled) async {
    await _prefs.setBool(_keyPermissionMic, enabled);
  }

  ///Get Camera permission status (Default: false)
  bool get permissionCamera => _prefs.getBool(_keyPermissionCamera) ?? false;

  /// Set Camera permission status
  Future<void> setPermissionCamera(bool enabled) async {
    await _prefs.setBool(_keyPermissionCamera, enabled);
  }

  /// Save daily news content
  Future<void> saveDailyNewsContent(String content) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _prefs.setString(_keyDailyNewsContent, content);
    await _prefs.setString(_keyDailyNewsDate, today);
  }

  /// Get stored daily news content if it matches today's date
  String? getDailyNewsContent() {
    final storedDate = _prefs.getString(_keyDailyNewsDate);
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    if (storedDate == today) {
      return _prefs.getString(_keyDailyNewsContent);
    }
    return null;
  }
  /// Clear all onboarding data (for testing)
  Future<void> clearOnboardingData() async {
    await _prefs.remove(_keyOnboardingComplete);
    await _prefs.remove(_keyRemainingGenerations);
    await _prefs.remove(_keyAvatarUrl);
    await _prefs.remove(_keyUserName);
    await _prefs.remove(_keyUserDob);
    await _prefs.remove(_keyUserLocation);
    await _prefs.remove(_keyUserCurrentLocation);
    await _prefs.remove(_keyUserGender);
    await _prefs.remove(_keySelectedVoiceId);
    await _prefs.remove(_keyAiOrigin);
    await _prefs.remove(_keyConversationCount);
  }

  /// Get default voice ID based on origin (place of birth) and gender
  static String? getDefaultVoiceForOrigin(String? origin, String? gender) {
    if (origin == null) return null;
    
    final originLower = origin.toLowerCase();
    final isFemale = gender?.toLowerCase().contains('female') ?? false;
    final isMale = gender?.toLowerCase().contains('male') ?? false;
    
    // Russia
    if (originLower.contains('russia') || originLower.contains('russian')) {
      return isFemale ? 'gedzfqL7OGdwm0ynTP' : 'ODq5zmih8GrVes37Dizd'; // Nadia or Patrick
    }
    
    // Sweden
    if (originLower.contains('sweden') || originLower.contains('swedish')) {
      return isFemale ? 'XrExE9yKIg1WjnnlVkGX' : 'ODq5zmih8GrVes37Dizd'; // Matilda or Patrick (fallback)
    }
    
    // United Kingdom
    if (originLower.contains('uk') || originLower.contains('britain') || originLower.contains('england')) {
      return isFemale ? 'XB0fDUnXU5powFXDhCwa' : 'VR6AewLTigWG4xSOukaG'; // Charlotte or Arnold
    }
    
    // Australia
    if (originLower.contains('australia') || originLower.contains('aussie')) {
      return isFemale ? 'XB0fDUnXU5powFXDhCwa' : 'IKne3meq5aSn9XLyUdCD'; // Charlotte (fallback) or Charlie
    }
    
    // Ireland
    if (originLower.contains('ireland') || originLower.contains('irish')) {
      return isFemale ? 'XB0fDUnXU5powFXDhCwa' : 'bVMeCyTHy58xNoL34h3p'; // Charlotte (fallback) or Jeremy
    }
    
    // France
    if (originLower.contains('france') || originLower.contains('french')) {
      return isFemale ? 'T558JOxAYVRUXPcjLmWL' : 'ZQe5CZNOzWyzPSCn5a3c'; // Serena or Liam
    }
    
    // Italy
    if (originLower.contains('italy') || originLower.contains('italian')) {
      return isFemale ? 'MF3mGyEYCl7XYWbV9V6O' : '21m00Tcm4TlvDq8ikWAM'; // Elli or Rachel (fallback)
    }
    
    // Spain
    if (originLower.contains('spain') || originLower.contains('spanish')) {
      return isFemale ? '21m00Tcm4TlvDq8ikWAM' : 'GBv7mTt0atIp3Br8iCZE'; // Rachel (fallback) or Thomas
    }
    
    // USA / Default
    return isFemale ? 'cgSgspJ2msm6clMCkdW9' : 'TxGEqnHWrfWFTfGW9XjX'; // Jessica or Josh
  }
}
