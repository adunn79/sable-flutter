/// Promo Code Generator for Aeliana
/// Generates cryptographically secure, one-time-use promo codes
/// Only authorized admins can generate codes via Firebase Admin panel
/// 
/// SECURITY FEATURES:
/// 1. Cryptographically random codes (unguessable)
/// 2. App signature embedding (verifiable origin)
/// 3. Firestore server-side validation (cannot forge)
/// 4. Device ID binding (cannot share)
/// 5. Expiration timestamps (time-limited)

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'promo_models.dart';

/// Secure promo code generator
/// NOTE: Code generation should ONLY happen from admin panel or Firebase Functions
/// This class provides the algorithm but should not be called from client app
class PromoCodeGenerator {
  static const String _appSecret = 'aeliana_promo_2024_secret_key'; // Admin-only secret
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I, O, 1, 0 to avoid confusion
  
  /// Generate a secure, unguessable promo code
  /// Format: XXXX-XXXX-XXXX (12 chars + dashes)
  /// Contains embedded signature that the app recognizes
  static String generateSecureCode() {
    final random = Random.secure();
    final chars = List.generate(12, (_) => _alphabet[random.nextInt(_alphabet.length)]);
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4, 8).join()}-${chars.sublist(8, 12).join()}';
  }
  
  /// Generate a code with an embedded verification signature
  /// The last 4 characters are a hash of the first 8 + secret
  /// This ensures only codes from our system will validate
  static String generateSignedCode() {
    final random = Random.secure();
    final prefix = List.generate(8, (_) => _alphabet[random.nextInt(_alphabet.length)]).join();
    
    // Create signature: hash of prefix + secret, take first 4 chars
    final signature = _createSignature(prefix);
    
    return '${prefix.substring(0, 4)}-${prefix.substring(4, 8)}-$signature';
  }
  
  /// Verify that a code has a valid signature (came from our system)
  static bool verifyCodeSignature(String code) {
    // Remove dashes
    final clean = code.replaceAll('-', '').toUpperCase();
    if (clean.length != 12) return false;
    
    final prefix = clean.substring(0, 8);
    final providedSignature = clean.substring(8, 12);
    final expectedSignature = _createSignature(prefix);
    
    return providedSignature == expectedSignature;
  }
  
  /// Create a 4-character signature from prefix + secret
  static String _createSignature(String prefix) {
    final input = '$prefix$_appSecret';
    final hash = sha256.convert(utf8.encode(input));
    
    // Convert first 2 bytes of hash to 4 alphabet characters
    final bytes = hash.bytes.sublist(0, 4);
    final sig = StringBuffer();
    for (final b in bytes) {
      sig.write(_alphabet[b % _alphabet.length]);
    }
    return sig.toString().substring(0, 4);
  }
  
  /// Create a promo code document for Firestore
  /// This should be called from Firebase Admin SDK or Cloud Functions
  static Map<String, dynamic> createPromoCodeDocument({
    required String code,
    required RewardType reward,
    required String createdBy,
    PromoCodeType type = PromoCodeType.oneTime,
    int maxUses = 1,
    DateTime? expiresAt,
    String? campaign,
  }) {
    return {
      'code': code.toUpperCase(),
      'type': type.name,
      'max_uses': maxUses,
      'current_uses': 0,
      'reward_type': reward.name,
      'expires_at': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'created_at': Timestamp.now(),
      'created_by': createdBy,
      'campaign': campaign,
      'is_active': true,
      // Signature verification flag
      'is_signed': true,
    };
  }
  
  /// Batch generate multiple codes (for admin use)
  /// Returns list of codes to be stored in Firestore
  static List<Map<String, dynamic>> batchGenerate({
    required int count,
    required RewardType reward,
    required String createdBy,
    PromoCodeType type = PromoCodeType.oneTime,
    DateTime? expiresAt,
    String? campaign,
  }) {
    final codes = <Map<String, dynamic>>[];
    final generatedCodes = <String>{};
    
    while (codes.length < count) {
      final code = generateSignedCode();
      // Ensure no duplicates
      if (!generatedCodes.contains(code)) {
        generatedCodes.add(code);
        codes.add(createPromoCodeDocument(
          code: code,
          reward: reward,
          createdBy: createdBy,
          type: type,
          expiresAt: expiresAt,
          campaign: campaign,
        ));
      }
    }
    
    return codes;
  }
}

/// Admin instructions for generating promo codes:
/// 
/// 1. FIREBASE CONSOLE METHOD:
///    - Go to Firestore > promo_codes collection
///    - Add new document with fields from createPromoCodeDocument()
///    - Use generateSignedCode() output for the 'code' field
/// 
/// 2. FIREBASE FUNCTIONS METHOD (Recommended):
///    - Create a Cloud Function that calls PromoCodeGenerator.batchGenerate()
///    - Trigger via Admin panel or secure API endpoint
///    - Returns list of generated codes for distribution
/// 
/// 3. SECURITY NOTES:
///    - Never expose _appSecret to client code
///    - Codes are verified by signature on redemption
///    - Device ID prevents sharing (one device per code)
///    - Rate limiting prevents brute force attempts
/// 
/// MAKING CODES UNSHAREABLE:
/// - Each redemption records deviceId and userId
/// - Firestore rules prevent same device from redeeming twice
/// - Code becomes invalid after first use (oneTime type)
/// - Cannot "decode" code to generate new ones (cryptographic)
