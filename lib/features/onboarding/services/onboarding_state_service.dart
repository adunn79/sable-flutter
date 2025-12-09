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
  
  // ============================================
  // VOICE CREDITS SYSTEM
  // ============================================
  static const String _keyVoiceCreditsUsed = 'voice_credits_used';
  static const String _keyVoiceCreditsDate = 'voice_credits_date';
  static const String _keyPremiumVoice = 'premium_voice_enabled';
  static const int _dailyVoiceCreditsLimit = 10; // Free tier limit
  
  /// Check if user has premium voice (unlimited)
  bool get hasPremiumVoice => _prefs.getBool(_keyPremiumVoice) ?? false;
  
  /// Set premium voice status
  Future<void> setPremiumVoice(bool enabled) async {
    await _prefs.setBool(_keyPremiumVoice, enabled);
  }
  
  /// Get remaining voice credits for today
  int get remainingVoiceCredits {
    if (hasPremiumVoice) return 999; // Unlimited for premium
    
    _resetCreditsIfNewDay();
    final used = _prefs.getInt(_keyVoiceCreditsUsed) ?? 0;
    return (_dailyVoiceCreditsLimit - used).clamp(0, _dailyVoiceCreditsLimit);
  }
  
  /// Get voice credits used today
  int get voiceCreditsUsedToday {
    _resetCreditsIfNewDay();
    return _prefs.getInt(_keyVoiceCreditsUsed) ?? 0;
  }
  
  /// Check if user can use voice (has credits remaining)
  bool get canUseVoice {
    if (hasPremiumVoice) return true;
    return remainingVoiceCredits > 0;
  }
  
  /// Use one voice credit (returns false if none remaining)
  Future<bool> useVoiceCredit() async {
    if (hasPremiumVoice) return true; // Premium always allowed
    
    _resetCreditsIfNewDay();
    final used = _prefs.getInt(_keyVoiceCreditsUsed) ?? 0;
    
    if (used >= _dailyVoiceCreditsLimit) return false;
    
    await _prefs.setInt(_keyVoiceCreditsUsed, used + 1);
    return true;
  }
  
  /// Reset credits if it's a new day
  void _resetCreditsIfNewDay() {
    final storedDate = _prefs.getString(_keyVoiceCreditsDate);
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    if (storedDate != today) {
      _prefs.setInt(_keyVoiceCreditsUsed, 0);
      _prefs.setString(_keyVoiceCreditsDate, today);
    }
  }
  
  /// Daily voice credits limit for display
  int get dailyVoiceCreditsLimit => hasPremiumVoice ? 999 : _dailyVoiceCreditsLimit;

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
  static const String _keyArchetypeId = 'selected_archetype_id';

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

  /// Get selected archetype ID (Sable, Kai, Echo) - Default: 'sable'
  String get selectedArchetypeId => _prefs.getString(_keyArchetypeId) ?? 'sable';

  /// Set selected archetype ID
  Future<void> setArchetypeId(String id) async {
    await _prefs.setString(_keyArchetypeId, id);
  }

  // Companion Age (18+)
  static const String _keyCompanionAge = 'companion_age';
  
  /// Get companion age - Default: 25
  int get companionAge => _prefs.getInt(_keyCompanionAge) ?? 25;
  
  /// Set companion age
  Future<void> setCompanionAge(int age) async {
    await _prefs.setInt(_keyCompanionAge, age);
  }

  // ============================================
  // PERMISSIONS
  // ============================================
  static const String _keyPermissionGps = 'permission_gps';
  static const String _keyPermissionMic = 'permission_mic';
  static const String _keyPermissionCamera = 'permission_camera';
  static const String _keyZodiacEnabled = 'zodiac_enabled';

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

  /// Get zodiac sign enabled status (Default: false - OFF)
  bool get zodiacEnabled => _prefs.getBool(_keyZodiacEnabled) ?? false;

  /// Set zodiac sign enabled status
  Future<void> setZodiacEnabled(bool enabled) async {
    await _prefs.setBool(_keyZodiacEnabled, enabled);
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
  
  // ============================================
  // AVATAR AGE TRACKING & GALLERY
  // ============================================
  
  static const String _keyAvatarGeneratedAge = 'avatar_generated_age';
  static const String _keyAvatarGallery = 'avatar_gallery';
  static const String _keyStructuredAvatarGallery = 'structured_avatar_gallery';
  static const String _keyArchetypeAvatars = 'archetype_avatars'; // Maps archetype -> avatar URL
  static const String _keyAvatarRegenerationDismissed = 'avatar_regen_dismissed_at';
  static const String _keyAvatarRegenCountYear = 'avatar_regen_count_year';
  static const String _keyAvatarRegenCount = 'avatar_regen_count';
  
  /// Get the age when the avatar was last generated
  int? get avatarGeneratedAge => _prefs.getInt(_keyAvatarGeneratedAge);
  
  /// Save the age when avatar was generated
  Future<void> setAvatarGeneratedAge(int age) async {
    await _prefs.setInt(_keyAvatarGeneratedAge, age);
  }
  
  /// Get all saved avatar URLs (legacy - simple list for backwards compatibility)
  List<String> get avatarGallery {
    return _prefs.getStringList(_keyAvatarGallery) ?? [];
  }
  
  /// Get structured avatar gallery with metadata
  List<SavedAvatar> get structuredAvatarGallery {
    final jsonList = _prefs.getStringList(_keyStructuredAvatarGallery);
    if (jsonList == null || jsonList.isEmpty) {
      // Migrate from legacy format if exists
      final legacyList = avatarGallery;
      if (legacyList.isNotEmpty) {
        return legacyList.map((url) => SavedAvatar(
          url: url,
          archetypeId: selectedArchetypeId, // Default to current archetype
          isLocked: false,
          createdAt: DateTime.now(),
        )).toList();
      }
      return [];
    }
    
    return jsonList.map((json) => SavedAvatar.fromJson(json)).toList();
  }
  
  /// Save structured avatar gallery
  Future<void> _saveStructuredGallery(List<SavedAvatar> avatars) async {
    final jsonList = avatars.map((a) => a.toJson()).toList();
    await _prefs.setStringList(_keyStructuredAvatarGallery, jsonList);
  }
  
  /// Add an avatar to the gallery with metadata
  Future<void> addToAvatarGallery(String url, {String? archetypeId}) async {
    final avatars = structuredAvatarGallery;
    
    // Check if already exists
    if (avatars.any((a) => a.url == url)) return;
    
    avatars.add(SavedAvatar(
      url: url,
      archetypeId: archetypeId ?? selectedArchetypeId,
      isLocked: false,
      createdAt: DateTime.now(),
    ));
    
    await _saveStructuredGallery(avatars);
    
    // Also update legacy list for backwards compatibility
    final legacy = avatarGallery;
    if (!legacy.contains(url)) {
      legacy.add(url);
      await _prefs.setStringList(_keyAvatarGallery, legacy);
    }
  }
  
  /// Remove an avatar from the gallery
  Future<bool> removeFromAvatarGallery(String url) async {
    final avatars = structuredAvatarGallery;
    final avatar = avatars.firstWhere((a) => a.url == url, orElse: () => SavedAvatar.empty());
    
    // Don't delete if locked
    if (avatar.isLocked) return false;
    
    avatars.removeWhere((a) => a.url == url);
    await _saveStructuredGallery(avatars);
    
    // Also update legacy list
    final legacy = avatarGallery;
    legacy.remove(url);
    await _prefs.setStringList(_keyAvatarGallery, legacy);
    
    return true;
  }
  
  /// Toggle lock status for an avatar
  Future<void> setAvatarLocked(String url, bool locked) async {
    final avatars = structuredAvatarGallery;
    final index = avatars.indexWhere((a) => a.url == url);
    
    if (index >= 0) {
      avatars[index] = avatars[index].copyWith(isLocked: locked);
      await _saveStructuredGallery(avatars);
    }
  }
  
  /// Check if avatar is locked
  bool isAvatarLocked(String url) {
    final avatars = structuredAvatarGallery;
    final avatar = avatars.firstWhere((a) => a.url == url, orElse: () => SavedAvatar.empty());
    return avatar.isLocked;
  }
  
  /// Get avatars for a specific archetype
  List<SavedAvatar> getAvatarsForArchetype(String archetypeId) {
    return structuredAvatarGallery.where((a) => a.archetypeId == archetypeId).toList();
  }
  
  /// Set avatar for a specific archetype
  Future<void> setArchetypeAvatar(String archetypeId, String url) async {
    final map = _prefs.getString(_keyArchetypeAvatars);
    Map<String, String> archetypeMap = {};
    
    if (map != null) {
      try {
        final decoded = Map<String, dynamic>.from(
          Uri.splitQueryString(map).map((k, v) => MapEntry(k, v)),
        );
        archetypeMap = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }
    
    archetypeMap[archetypeId] = url;
    
    // Store as query string format for simplicity
    final encoded = archetypeMap.entries.map((e) => '${e.key}=${e.value}').join('&');
    await _prefs.setString(_keyArchetypeAvatars, encoded);
  }
  
  /// Get avatar URL for a specific archetype
  String? getArchetypeAvatar(String archetypeId) {
    final map = _prefs.getString(_keyArchetypeAvatars);
    if (map == null) return null;
    
    try {
      final decoded = Uri.splitQueryString(map);
      return decoded[archetypeId];
    } catch (_) {
      return null;
    }
  }
  
  /// Get regeneration count for current year (resets each year)
  int get regenerationCountThisYear {
    final storedYear = _prefs.getInt(_keyAvatarRegenCountYear) ?? 0;
    final currentYear = DateTime.now().year;
    
    // Reset count if it's a new year
    if (storedYear != currentYear) {
      return 0;
    }
    return _prefs.getInt(_keyAvatarRegenCount) ?? 0;
  }
  
  /// Check if user can regenerate (max 2x per year)
  bool get canRegenerateThisYear => regenerationCountThisYear < 2;
  
  /// Increment regeneration count for this year
  Future<void> incrementRegenerationCount() async {
    final currentYear = DateTime.now().year;
    await _prefs.setInt(_keyAvatarRegenCountYear, currentYear);
    await _prefs.setInt(_keyAvatarRegenCount, regenerationCountThisYear + 1);
  }
  
  /// Check if avatar regeneration should be prompted (age changed by ±5 years)
  bool shouldPromptAvatarRegeneration() {
    final generatedAge = avatarGeneratedAge;
    if (generatedAge == null) return false;
    
    // Check 2x per year limit
    if (!canRegenerateThisYear) return false;
    
    // Calculate current age from DOB
    final dob = userDob;
    if (dob == null) return false;
    
    final now = DateTime.now();
    int currentAge = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      currentAge--;
    }
    
    // Check if age difference is >= 5 years
    final ageDiff = (currentAge - generatedAge).abs();
    if (ageDiff < 5) return false;
    
    // Check if user dismissed the prompt recently (within 30 days)
    final dismissedAt = _prefs.getString(_keyAvatarRegenerationDismissed);
    if (dismissedAt != null) {
      try {
        final dismissedDate = DateTime.parse(dismissedAt);
        final daysSinceDismissed = DateTime.now().difference(dismissedDate).inDays;
        if (daysSinceDismissed < 30) return false;
      } catch (_) {}
    }
    
    return true;
  }
  
  /// Get age direction: 1 = older, -1 = younger, 0 = same
  int getAgeDirection() {
    final generatedAge = avatarGeneratedAge;
    final currentAge = getCurrentAge();
    if (generatedAge == null || currentAge == null) return 0;
    return currentAge > generatedAge ? 1 : (currentAge < generatedAge ? -1 : 0);
  }
  
  /// Get current user age
  int? getCurrentAge() {
    final dob = userDob;
    if (dob == null) return null;
    
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
  
  /// Dismiss avatar regeneration prompt for 30 days
  Future<void> dismissAvatarRegenerationPrompt() async {
    await _prefs.setString(_keyAvatarRegenerationDismissed, DateTime.now().toIso8601String());
  }
  
  /// Clear regeneration dismissal (for testing)
  Future<void> clearRegenerationDismissal() async {
    await _prefs.remove(_keyAvatarRegenerationDismissed);
  }
}

/// Saved avatar with metadata for gallery management
class SavedAvatar {
  final String url;
  final String archetypeId;
  final bool isLocked;
  final DateTime createdAt;
  
  const SavedAvatar({
    required this.url,
    required this.archetypeId,
    required this.isLocked,
    required this.createdAt,
  });
  
  /// Create an empty/placeholder avatar
  factory SavedAvatar.empty() => SavedAvatar(
    url: '',
    archetypeId: '',
    isLocked: false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
  
  /// Create from JSON string
  factory SavedAvatar.fromJson(String json) {
    try {
      final parts = json.split('|');
      return SavedAvatar(
        url: parts[0],
        archetypeId: parts.length > 1 ? parts[1] : 'sable',
        isLocked: parts.length > 2 ? parts[2] == 'true' : false,
        createdAt: parts.length > 3 
            ? DateTime.tryParse(parts[3]) ?? DateTime.now()
            : DateTime.now(),
      );
    } catch (_) {
      return SavedAvatar.empty();
    }
  }
  
  /// Convert to JSON string
  String toJson() {
    return '$url|$archetypeId|$isLocked|${createdAt.toIso8601String()}';
  }
  
  /// Create a copy with updated fields
  SavedAvatar copyWith({
    String? url,
    String? archetypeId,
    bool? isLocked,
    DateTime? createdAt,
  }) {
    return SavedAvatar(
      url: url ?? this.url,
      archetypeId: archetypeId ?? this.archetypeId,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
