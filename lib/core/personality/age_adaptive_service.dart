import 'package:shared_preferences/shared_preferences.dart';

/// Age-based personality calibration tiers
enum AgePersonalityTier {
  youth,      // 17-24: Casual, playful, emoji-friendly
  youngAdult, // 25-34: Balanced, supportive, fun but focused
  adult,      // 35-49: Professional warmth, efficient
  mature,     // 50+: Dignified, wise, measured
}

/// Service to adapt AI personality based on user's age
/// Younger users get casual/playful tone, older users get more focused/dignified tone
class AgeAdaptiveService {
  static AgeAdaptiveService? _instance;
  SharedPreferences? _prefs;
  
  AgeAdaptiveService._();
  
  static Future<AgeAdaptiveService> getInstance() async {
    if (_instance == null) {
      _instance = AgeAdaptiveService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }
  
  /// Calculate user's current age from DOB
  int? getUserAge() {
    // Try health profile DOB first
    final dobString = _prefs?.getString('health_profile_dob');
    if (dobString != null && dobString.isNotEmpty) {
      try {
        final dob = DateTime.parse(dobString);
        return _calculateAge(dob);
      } catch (_) {}
    }
    
    // Fallback to onboarding DOB
    final onboardingDob = _prefs?.getString('user_dob');
    if (onboardingDob != null && onboardingDob.isNotEmpty) {
      try {
        final dob = DateTime.parse(onboardingDob);
        return _calculateAge(dob);
      } catch (_) {}
    }
    
    return null; // Age unknown
  }
  
  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
  
  /// Get the personality tier for the current user
  AgePersonalityTier getTier() {
    final age = getUserAge();
    if (age == null) return AgePersonalityTier.youngAdult; // Default
    
    if (age < 25) return AgePersonalityTier.youth;
    if (age < 35) return AgePersonalityTier.youngAdult;
    if (age < 50) return AgePersonalityTier.adult;
    return AgePersonalityTier.mature;
  }
  
  /// Get system prompt personality instructions based on user age
  String getPersonalityInstructions() {
    final age = getUserAge();
    final tier = getTier();
    
    final ageContext = age != null ? 'The user is approximately $age years old.' : '';
    
    switch (tier) {
      case AgePersonalityTier.youth:
        return '''
$ageContext
PERSONALITY CALIBRATION (Youth):
- Be casual, warm, and approachable
- Light use of emoji is okay (don't overdo it)
- Can use contemporary language naturally
- Playful energy, but still supportive and helpful
- Don't be condescending or overly "young" - be authentic
- Match their energy level''';
        
      case AgePersonalityTier.youngAdult:
        return '''
$ageContext
PERSONALITY CALIBRATION (Young Adult):
- Balanced warmth with professionalism
- Supportive and encouraging
- Can be fun but also focused when needed
- Respect their ambitions and life journey
- Be a helpful friend who also gives good advice''';
        
      case AgePersonalityTier.adult:
        return '''
$ageContext
PERSONALITY CALIBRATION (Adult):
- Professional warmth and efficiency
- Respect their time and experience
- Clear, direct communication
- Thoughtful and measured responses
- Be helpful without being overly casual
- Focus on practical value''';
        
      case AgePersonalityTier.mature:
        return '''
$ageContext
PERSONALITY CALIBRATION (Mature):
- Dignified, respectful, and wise
- Measured pace - no rushing
- Deep respect for their life experience
- Thoughtful and considered responses
- Avoid trendy language or excessive emoji
- Be a trusted, reliable companion''';
    }
  }
  
  /// Get concise label for current tier (for debugging/display)
  String getTierLabel() {
    switch (getTier()) {
      case AgePersonalityTier.youth: return 'Youth (17-24)';
      case AgePersonalityTier.youngAdult: return 'Young Adult (25-34)';
      case AgePersonalityTier.adult: return 'Adult (35-49)';
      case AgePersonalityTier.mature: return 'Mature (50+)';
    }
  }
}
