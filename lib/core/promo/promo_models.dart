/// Promo Code Models for Aeliana
/// Supports one-time use codes with 15 reward types

import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of promo codes
enum PromoCodeType {
  oneTime,    // Can only be used once ever
  multiUse,   // No limit on uses
  limitedUse, // Limited number of uses
}

/// Categories of rewards
enum RewardCategory {
  trial,      // Subscription trials
  credits,    // Voice/Video credits
  unlock,     // Feature unlocks
  boost,      // Engagement boosters
  content,    // Exclusive content
  access,     // Priority access
}

/// All available reward types (15 total)
enum RewardType {
  // Trials (3)
  pro7d,
  pro30d,
  ultra7d,
  
  // Voice Credits (3)
  voice50,
  voice200,
  voice500,
  
  // Video Credits (2)
  video25,
  video100,
  
  // Unlocks (2)
  lunaUnlock,
  customAvatar,
  
  // Boosts (2)
  streakFreeze3,
  doubleXp24h,
  
  // Content (2)
  archetypeEarly,
  themeExclusive,
  
  // Access (1)
  prioritySupport30d,
}

/// Extension for reward metadata
extension RewardTypeExtension on RewardType {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case RewardType.pro7d: return 'Pro Week Pass';
      case RewardType.pro30d: return 'Pro Month Pass';
      case RewardType.ultra7d: return 'Ultra Week Pass';
      case RewardType.voice50: return 'Voice Starter (50)';
      case RewardType.voice200: return 'Voice Plus (200)';
      case RewardType.voice500: return 'Voice Pro (500)';
      case RewardType.video25: return 'Video Starter (25)';
      case RewardType.video100: return 'Video Plus (100)';
      case RewardType.lunaUnlock: return 'Luna Access';
      case RewardType.customAvatar: return 'Avatar Forge';
      case RewardType.streakFreeze3: return 'Streak Shield (3x)';
      case RewardType.doubleXp24h: return 'XP Doubler (24h)';
      case RewardType.archetypeEarly: return 'Early Archetype Access';
      case RewardType.themeExclusive: return 'Exclusive Theme';
      case RewardType.prioritySupport30d: return 'VIP Support (30d)';
    }
  }
  
  String get description {
    switch (this) {
      case RewardType.pro7d: return '7 days of Pro tier access';
      case RewardType.pro30d: return '30 days of Pro tier access';
      case RewardType.ultra7d: return '7 days of Ultra tier access';
      case RewardType.voice50: return '50 ElevenLabs voice credits';
      case RewardType.voice200: return '200 ElevenLabs voice credits';
      case RewardType.voice500: return '500 ElevenLabs voice credits';
      case RewardType.video25: return '25 video generation credits';
      case RewardType.video100: return '100 video generation credits';
      case RewardType.lunaUnlock: return 'Permanent access to Luna in Private Space';
      case RewardType.customAvatar: return 'Generate 1 custom AI avatar';
      case RewardType.streakFreeze3: return '3 streak freeze tokens';
      case RewardType.doubleXp24h: return '24 hours of double XP rewards';
      case RewardType.archetypeEarly: return 'Early access to new archetypes';
      case RewardType.themeExclusive: return 'Limited edition UI theme';
      case RewardType.prioritySupport30d: return '30 days of priority support';
    }
  }
  
  RewardCategory get category {
    switch (this) {
      case RewardType.pro7d:
      case RewardType.pro30d:
      case RewardType.ultra7d:
        return RewardCategory.trial;
      case RewardType.voice50:
      case RewardType.voice200:
      case RewardType.voice500:
      case RewardType.video25:
      case RewardType.video100:
        return RewardCategory.credits;
      case RewardType.lunaUnlock:
      case RewardType.customAvatar:
        return RewardCategory.unlock;
      case RewardType.streakFreeze3:
      case RewardType.doubleXp24h:
        return RewardCategory.boost;
      case RewardType.archetypeEarly:
      case RewardType.themeExclusive:
        return RewardCategory.content;
      case RewardType.prioritySupport30d:
        return RewardCategory.access;
    }
  }
  
  /// Duration in days for time-limited rewards (null = permanent)
  int? get durationDays {
    switch (this) {
      case RewardType.pro7d: return 7;
      case RewardType.pro30d: return 30;
      case RewardType.ultra7d: return 7;
      case RewardType.doubleXp24h: return 1;
      case RewardType.prioritySupport30d: return 30;
      default: return null;
    }
  }
  
  /// Credit amount for credit-type rewards (null = not a credit reward)
  int? get creditAmount {
    switch (this) {
      case RewardType.voice50: return 50;
      case RewardType.voice200: return 200;
      case RewardType.voice500: return 500;
      case RewardType.video25: return 25;
      case RewardType.video100: return 100;
      case RewardType.streakFreeze3: return 3;
      default: return null;
    }
  }
}

/// Promo code model
class PromoCode {
  final String id;
  final String code;
  final PromoCodeType type;
  final int maxUses;
  final int currentUses;
  final RewardType rewardType;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String createdBy;
  final String? campaign;
  final bool isActive;
  
  PromoCode({
    required this.id,
    required this.code,
    required this.type,
    this.maxUses = 1,
    this.currentUses = 0,
    required this.rewardType,
    this.expiresAt,
    required this.createdAt,
    required this.createdBy,
    this.campaign,
    this.isActive = true,
  });
  
  bool get isValid {
    if (!isActive) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    if (type == PromoCodeType.oneTime && currentUses >= 1) return false;
    if (type == PromoCodeType.limitedUse && currentUses >= maxUses) return false;
    return true;
  }
  
  factory PromoCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromoCode(
      id: doc.id,
      code: data['code'] ?? '',
      type: PromoCodeType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => PromoCodeType.oneTime,
      ),
      maxUses: data['max_uses'] ?? 1,
      currentUses: data['current_uses'] ?? 0,
      rewardType: RewardType.values.firstWhere(
        (e) => e.name == data['reward_type'],
        orElse: () => RewardType.voice50,
      ),
      expiresAt: data['expires_at'] != null 
          ? (data['expires_at'] as Timestamp).toDate() 
          : null,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['created_by'] ?? 'system',
      campaign: data['campaign'],
      isActive: data['is_active'] ?? true,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'type': type.name,
      'max_uses': maxUses,
      'current_uses': currentUses,
      'reward_type': rewardType.name,
      'expires_at': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'created_by': createdBy,
      'campaign': campaign,
      'is_active': isActive,
    };
  }
}

/// Redemption record model
class PromoRedemption {
  final String id;
  final String codeId;
  final String userId;
  final String deviceId;
  final DateTime redeemedAt;
  final RewardType rewardGranted;
  
  PromoRedemption({
    required this.id,
    required this.codeId,
    required this.userId,
    required this.deviceId,
    required this.redeemedAt,
    required this.rewardGranted,
  });
  
  factory PromoRedemption.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromoRedemption(
      id: doc.id,
      codeId: data['code_id'] ?? '',
      userId: data['user_id'] ?? '',
      deviceId: data['device_id'] ?? '',
      redeemedAt: (data['redeemed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rewardGranted: RewardType.values.firstWhere(
        (e) => e.name == data['reward_granted'],
        orElse: () => RewardType.voice50,
      ),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'code_id': codeId,
      'user_id': userId,
      'device_id': deviceId,
      'redeemed_at': Timestamp.fromDate(redeemedAt),
      'reward_granted': rewardGranted.name,
    };
  }
}

/// Result of a redemption attempt
class RedemptionResult {
  final bool success;
  final String message;
  final RewardType? rewardGranted;
  
  RedemptionResult({
    required this.success,
    required this.message,
    this.rewardGranted,
  });
  
  factory RedemptionResult.success(RewardType reward) {
    return RedemptionResult(
      success: true,
      message: 'Successfully redeemed! You received: ${reward.displayName}',
      rewardGranted: reward,
    );
  }
  
  factory RedemptionResult.error(String message) {
    return RedemptionResult(
      success: false,
      message: message,
    );
  }
}
