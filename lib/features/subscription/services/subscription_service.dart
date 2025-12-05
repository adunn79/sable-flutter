import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionTier {
  free,
  silver,
  gold,
  platinum,
}

class SubscriptionService extends ChangeNotifier {
  static SubscriptionService? _instance;
  final SharedPreferences _prefs;

  SubscriptionService._(this._prefs);

  static Future<SubscriptionService> create() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = SubscriptionService._(prefs);
    }
    return _instance!;
  }

  // State
  SubscriptionTier get currentTier {
    final index = _prefs.getInt('subscription_tier_index') ?? 0;
    return SubscriptionTier.values[index];
  }

  int get voiceCredits => _prefs.getInt('voice_credits') ?? 10;
  int get videoCredits => _prefs.getInt('video_credits') ?? 5;
  bool get smartAdjustmentsEnabled => _prefs.getBool('smart_adjustments_enabled') ?? false;

  // Actions
  Future<void> setTier(SubscriptionTier tier) async {
    await _prefs.setInt('subscription_tier_index', tier.index);
    notifyListeners();
  }

  Future<void> addVoiceCredits(int amount) async {
    final current = voiceCredits;
    await _prefs.setInt('voice_credits', current + amount);
    notifyListeners();
  }

  Future<void> addVideoCredits(int amount) async {
    final current = videoCredits;
    await _prefs.setInt('video_credits', current + amount);
    notifyListeners();
  }

  Future<void> toggleSmartAdjustments(bool enabled) async {
    await _prefs.setBool('smart_adjustments_enabled', enabled);
    notifyListeners();
  }

  // Tier Details
  String getTierName(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free: return 'Free';
      case SubscriptionTier.silver: return 'Silver';
      case SubscriptionTier.gold: return 'Gold';
      case SubscriptionTier.platinum: return 'Platinum';
    }
  }

  double getTierPrice(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free: return 0.00;
      case SubscriptionTier.silver: return 9.99;
      case SubscriptionTier.gold: return 19.99;
      case SubscriptionTier.platinum: return 49.99;
    }
  }

  List<String> getTierFeatures(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return ['Basic Chat', 'Standard Voice', 'Limited Memory'];
      case SubscriptionTier.silver:
        return ['Priority Chat', 'Pro Voices', 'Extended Memory', '100 Voice Credits/mo'];
      case SubscriptionTier.gold:
        return ['Instant Chat', 'All Voices', 'Full Memory', '500 Voice Credits/mo', '50 Video Credits/mo'];
      case SubscriptionTier.platinum:
        return ['Concierge Support', 'Exclusive Voices', 'Unlimited Memory', '2000 Voice Credits/mo', '200 Video Credits/mo', 'Smart Adjustments Included'];
    }
  }
}
