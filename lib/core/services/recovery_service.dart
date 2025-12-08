import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service for managing account recovery options (email/phone)
/// Used for PIN reset functionality across Journal, Vital Balance, and Private Space
class RecoveryService {
  static const String _keyRecoveryEmail = 'recovery_email';
  static const String _keyRecoveryEmailVerified = 'recovery_email_verified';
  static const String _keyRecoveryPhone = 'recovery_phone';
  static const String _keyRecoveryPhoneVerified = 'recovery_phone_verified';
  
  final SharedPreferences _prefs;
  
  RecoveryService(this._prefs);
  
  /// Create instance asynchronously
  static Future<RecoveryService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return RecoveryService(prefs);
  }
  
  // ============================================
  // EMAIL RECOVERY
  // ============================================
  
  /// Get recovery email
  String? get recoveryEmail => _prefs.getString(_keyRecoveryEmail);
  
  /// Check if recovery email is verified
  bool get isEmailVerified => _prefs.getBool(_keyRecoveryEmailVerified) ?? false;
  
  /// Save recovery email
  Future<void> setRecoveryEmail(String email) async {
    await _prefs.setString(_keyRecoveryEmail, email.toLowerCase().trim());
    await _prefs.setBool(_keyRecoveryEmailVerified, false); // Reset verification on change
    debugPrint('📧 Recovery email set: $email');
  }
  
  /// Mark email as verified
  Future<void> verifyEmail() async {
    if (recoveryEmail != null) {
      await _prefs.setBool(_keyRecoveryEmailVerified, true);
      debugPrint('✅ Recovery email verified');
    }
  }
  
  /// Clear recovery email
  Future<void> clearEmail() async {
    await _prefs.remove(_keyRecoveryEmail);
    await _prefs.remove(_keyRecoveryEmailVerified);
  }
  
  // ============================================
  // PHONE RECOVERY
  // ============================================
  
  /// Get recovery phone
  String? get recoveryPhone => _prefs.getString(_keyRecoveryPhone);
  
  /// Check if recovery phone is verified
  bool get isPhoneVerified => _prefs.getBool(_keyRecoveryPhoneVerified) ?? false;
  
  /// Save recovery phone
  Future<void> setRecoveryPhone(String phone) async {
    // Clean phone number - remove spaces, dashes, parentheses
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    await _prefs.setString(_keyRecoveryPhone, cleanPhone);
    await _prefs.setBool(_keyRecoveryPhoneVerified, false); // Reset verification on change
    debugPrint('📱 Recovery phone set: $cleanPhone');
  }
  
  /// Mark phone as verified
  Future<void> verifyPhone() async {
    if (recoveryPhone != null) {
      await _prefs.setBool(_keyRecoveryPhoneVerified, true);
      debugPrint('✅ Recovery phone verified');
    }
  }
  
  /// Clear recovery phone
  Future<void> clearPhone() async {
    await _prefs.remove(_keyRecoveryPhone);
    await _prefs.remove(_keyRecoveryPhoneVerified);
  }
  
  // ============================================
  // RECOVERY VERIFICATION
  // ============================================
  
  /// Check if user has any verified recovery method
  bool get hasVerifiedRecoveryMethod => isEmailVerified || isPhoneVerified;
  
  /// Check if user has any recovery method set (verified or not)
  bool get hasAnyRecoveryMethod => recoveryEmail != null || recoveryPhone != null;
  
  /// Verify identity for PIN reset
  /// Returns true if the provided email OR phone matches the stored verified value
  bool verifyIdentity({String? email, String? phone}) {
    // Check email match
    if (email != null && isEmailVerified && recoveryEmail != null) {
      if (email.toLowerCase().trim() == recoveryEmail!.toLowerCase()) {
        debugPrint('✅ Identity verified via email');
        return true;
      }
    }
    
    // Check phone match
    if (phone != null && isPhoneVerified && recoveryPhone != null) {
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
      if (cleanPhone == recoveryPhone) {
        debugPrint('✅ Identity verified via phone');
        return true;
      }
    }
    
    debugPrint('❌ Identity verification failed');
    return false;
  }
  
  /// Clear all recovery data
  Future<void> clearAllRecoveryData() async {
    await clearEmail();
    await clearPhone();
    debugPrint('🗑️ All recovery data cleared');
  }
}
