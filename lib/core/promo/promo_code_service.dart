/// Promo Code Service for Aeliana
/// Handles code validation, redemption, and reward granting
/// Uses Firebase Firestore for server-side validation

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'promo_models.dart';

class PromoCodeService {
  static PromoCodeService? _instance;
  static PromoCodeService get instance => _instance ??= PromoCodeService._();
  
  PromoCodeService._();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Rate limiting: track attempts
  final Map<String, List<DateTime>> _attemptHistory = {};
  static const int _maxAttemptsPerHour = 5;
  
  /// Get unique device ID for one-time-use enforcement
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('promo_device_id');
    
    if (deviceId == null) {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceId = ios.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceId = android.id;
      } else {
        deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
      await prefs.setString('promo_device_id', deviceId);
    }
    
    return deviceId;
  }
  
  /// Get current user ID (from SharedPreferences or generate one)
  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    
    if (userId == null) {
      userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('user_id', userId);
    }
    
    return userId;
  }
  
  /// Check if rate limited
  bool _isRateLimited(String deviceId) {
    final now = DateTime.now();
    final attempts = _attemptHistory[deviceId] ?? [];
    
    // Remove attempts older than 1 hour
    attempts.removeWhere((time) => now.difference(time).inHours >= 1);
    _attemptHistory[deviceId] = attempts;
    
    return attempts.length >= _maxAttemptsPerHour;
  }
  
  /// Record an attempt
  void _recordAttempt(String deviceId) {
    final attempts = _attemptHistory[deviceId] ?? [];
    attempts.add(DateTime.now());
    _attemptHistory[deviceId] = attempts;
  }
  
  /// Validate and redeem a promo code
  Future<RedemptionResult> redeemCode(String codeString) async {
    final code = codeString.trim().toUpperCase();
    
    if (code.isEmpty) {
      return RedemptionResult.error('Please enter a promo code');
    }
    
    if (code.length < 6 || code.length > 16) {
      return RedemptionResult.error('Invalid code format');
    }
    
    try {
      final deviceId = await _getDeviceId();
      final userId = await _getUserId();
      
      // Check rate limiting
      if (_isRateLimited(deviceId)) {
        return RedemptionResult.error('Too many attempts. Please try again later.');
      }
      
      _recordAttempt(deviceId);
      
      // Find the code in Firestore
      final codeQuery = await _firestore
          .collection('promo_codes')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      
      if (codeQuery.docs.isEmpty) {
        debugPrint('🎟️ Promo: Code not found: $code');
        return RedemptionResult.error('Invalid promo code');
      }
      
      final promoDoc = codeQuery.docs.first;
      final promoCode = PromoCode.fromFirestore(promoDoc);
      
      // Check if code is valid
      if (!promoCode.isValid) {
        if (promoCode.expiresAt != null && DateTime.now().isAfter(promoCode.expiresAt!)) {
          return RedemptionResult.error('This code has expired');
        }
        if (!promoCode.isActive) {
          return RedemptionResult.error('This code is no longer active');
        }
        return RedemptionResult.error('This code has already been used');
      }
      
      // Check if already redeemed by this user or device
      final existingRedemption = await _firestore
          .collection('promo_redemptions')
          .where('code_id', isEqualTo: promoDoc.id)
          .where('user_id', isEqualTo: userId)
          .get();
      
      if (existingRedemption.docs.isNotEmpty) {
        return RedemptionResult.error('You have already redeemed this code');
      }
      
      // Check device-level redemption (prevent sharing)
      final deviceRedemption = await _firestore
          .collection('promo_redemptions')
          .where('code_id', isEqualTo: promoDoc.id)
          .where('device_id', isEqualTo: deviceId)
          .get();
      
      if (deviceRedemption.docs.isNotEmpty) {
        return RedemptionResult.error('This code has already been used on this device');
      }
      
      // All checks passed - redeem the code
      return await _executeRedemption(promoDoc, promoCode, userId, deviceId);
      
    } catch (e) {
      debugPrint('🎟️ Promo: Error redeeming code: $e');
      return RedemptionResult.error('An error occurred. Please try again.');
    }
  }
  
  /// Execute the redemption transaction
  Future<RedemptionResult> _executeRedemption(
    DocumentSnapshot promoDoc,
    PromoCode promoCode,
    String userId,
    String deviceId,
  ) async {
    try {
      // Use a transaction for atomicity
      await _firestore.runTransaction((transaction) async {
        // Increment use count
        transaction.update(promoDoc.reference, {
          'current_uses': FieldValue.increment(1),
        });
        
        // Create redemption record
        final redemptionRef = _firestore.collection('promo_redemptions').doc();
        transaction.set(redemptionRef, PromoRedemption(
          id: redemptionRef.id,
          codeId: promoDoc.id,
          userId: userId,
          deviceId: deviceId,
          redeemedAt: DateTime.now(),
          rewardGranted: promoCode.rewardType,
        ).toFirestore());
      });
      
      // Grant the reward locally
      await _grantReward(promoCode.rewardType);
      
      debugPrint('🎟️ Promo: Successfully redeemed ${promoCode.code} for ${promoCode.rewardType.displayName}');
      
      return RedemptionResult.success(promoCode.rewardType);
      
    } catch (e) {
      debugPrint('🎟️ Promo: Transaction failed: $e');
      return RedemptionResult.error('Failed to redeem code. Please try again.');
    }
  }
  
  /// Grant the reward to the user's local storage
  Future<void> _grantReward(RewardType reward) async {
    final prefs = await SharedPreferences.getInstance();
    
    switch (reward.category) {
      case RewardCategory.trial:
        // Set trial expiration
        final days = reward.durationDays ?? 7;
        final expiresAt = DateTime.now().add(Duration(days: days));
        await prefs.setString('trial_tier', reward.name);
        await prefs.setString('trial_expires', expiresAt.toIso8601String());
        debugPrint('🎟️ Granted trial: ${reward.name} until $expiresAt');
        break;
        
      case RewardCategory.credits:
        final amount = reward.creditAmount ?? 0;
        if (reward.name.contains('voice')) {
          final current = prefs.getInt('voice_credits') ?? 0;
          await prefs.setInt('voice_credits', current + amount);
        } else if (reward.name.contains('video')) {
          final current = prefs.getInt('video_credits') ?? 0;
          await prefs.setInt('video_credits', current + amount);
        } else if (reward == RewardType.streakFreeze3) {
          final current = prefs.getInt('streak_freezes') ?? 0;
          await prefs.setInt('streak_freezes', current + amount);
        }
        debugPrint('🎟️ Granted credits: ${reward.displayName}');
        break;
        
      case RewardCategory.unlock:
        if (reward == RewardType.lunaUnlock) {
          await prefs.setBool('luna_unlocked', true);
        } else if (reward == RewardType.customAvatar) {
          final current = prefs.getInt('custom_avatar_tokens') ?? 0;
          await prefs.setInt('custom_avatar_tokens', current + 1);
        }
        debugPrint('🎟️ Granted unlock: ${reward.displayName}');
        break;
        
      case RewardCategory.boost:
        if (reward == RewardType.doubleXp24h) {
          final expiresAt = DateTime.now().add(const Duration(hours: 24));
          await prefs.setString('double_xp_expires', expiresAt.toIso8601String());
        }
        debugPrint('🎟️ Granted boost: ${reward.displayName}');
        break;
        
      case RewardCategory.content:
        if (reward == RewardType.archetypeEarly) {
          await prefs.setBool('early_archetypes_access', true);
        } else if (reward == RewardType.themeExclusive) {
          final themes = prefs.getStringList('unlocked_themes') ?? [];
          themes.add('exclusive_${DateTime.now().millisecondsSinceEpoch}');
          await prefs.setStringList('unlocked_themes', themes);
        }
        debugPrint('🎟️ Granted content: ${reward.displayName}');
        break;
        
      case RewardCategory.access:
        if (reward == RewardType.prioritySupport30d) {
          final expiresAt = DateTime.now().add(const Duration(days: 30));
          await prefs.setString('priority_support_expires', expiresAt.toIso8601String());
        }
        debugPrint('🎟️ Granted access: ${reward.displayName}');
        break;
    }
  }
  
  /// Check if user has an active trial
  Future<bool> hasActiveTrial() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresStr = prefs.getString('trial_expires');
    if (expiresStr == null) return false;
    
    final expires = DateTime.tryParse(expiresStr);
    return expires != null && DateTime.now().isBefore(expires);
  }
  
  /// Get current trial tier
  Future<String?> getTrialTier() async {
    if (!await hasActiveTrial()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('trial_tier');
  }
  
  /// Get voice credits balance
  Future<int> getVoiceCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('voice_credits') ?? 0;
  }
  
  /// Get video credits balance
  Future<int> getVideoCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('video_credits') ?? 0;
  }
  
  /// Check if Luna is unlocked
  Future<bool> isLunaUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('luna_unlocked') ?? false;
  }
}
