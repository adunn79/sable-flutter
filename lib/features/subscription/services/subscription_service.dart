import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'iap_service.dart';

enum SubscriptionTier {
  free,
  silver,
  gold,
  platinum,
}

class SubscriptionService extends ChangeNotifier {
  static SubscriptionService? _instance;
  final SharedPreferences _prefs;
  final IAPService _iapService;

  SubscriptionService._(this._prefs, this._iapService) {
    // Listen to IAP changes
    _iapService.addListener(_syncFromIAP);
  }

  static Future<SubscriptionService> create() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      final iapService = IAPService();
      
      // Initialize IAP service
      await iapService.initialize();
      
      _instance = SubscriptionService._(prefs, iapService);
      
      // Initial sync
      await _instance!._syncFromIAP();
    }
    return _instance!;
  }

  // State
  SubscriptionTier get currentTier {
    // Try to get tier from IAP first
    final iapTier = _getTierFromIAP();
    if (iapTier != null) {
      return iapTier;
    }
    
    // Fallback to SharedPreferences (dev mode or IAP unavailable)
    final index = _prefs.getInt('subscription_tier_index') ?? 0;
    return SubscriptionTier.values[index];
  }

  int get voiceCredits => _prefs.getInt('voice_credits') ?? 10;
  int get videoCredits => _prefs.getInt('video_credits') ?? 5;
  bool get smartAdjustmentsEnabled => _prefs.getBool('smart_adjustments_enabled') ?? false;
  bool get isIAPAvailable => _iapService.isAvailable;

  // Actions
  Future<void> setTier(SubscriptionTier tier) async {
    // Only allow manual tier setting if IAP is not available (dev mode)
    if (!_iapService.isAvailable) {
      await _prefs.setInt('subscription_tier_index', tier.index);
      notifyListeners();
    } else {
      debugPrint('⚠️ Cannot set tier manually when IAP is available. Use purchaseSubscription().');
    }
  }

  /// Purchase a subscription via IAP
  Future<bool> purchaseSubscription(SubscriptionTier tier) async {
    if (!_iapService.isAvailable) {
      debugPrint('⚠️ IAP not available, using mock purchase');
      await setTier(tier); // Fallback to mock
      return true;
    }

    final productId = _getProductIdForTier(tier);
    if (productId == null) {
      debugPrint('❌ No product ID for tier $tier');
      return false;
    }

    return await _iapService.purchaseSubscription(productId);
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_iapService.isAvailable) {
      debugPrint('⚠️ IAP not available, nothing to restore');
      return;
    }

    await _iapService.restorePurchases();
    await _syncFromIAP();
  }

  /// Sync tier from IAP entitlements
  Future<void> _syncFromIAP() async {
    if (!_iapService.isAvailable) return;

    final activeProductId = _iapService.getActiveSubscription();
    if (activeProductId == null) {
      // No active subscription, set to free
      await _prefs.setInt('subscription_tier_index', SubscriptionTier.free.index);
    } else {
      final tier = _getTierFromProductId(activeProductId);
      if (tier != null) {
        await _prefs.setInt('subscription_tier_index', tier.index);
        debugPrint('✅ Synced tier from IAP: $tier');
      }
    }

    notifyListeners();
  }

  /// Get tier from IAP active subscription
  SubscriptionTier? _getTierFromIAP() {
    if (!_iapService.isAvailable) return null;

    final activeProductId = _iapService.getActiveSubscription();
    if (activeProductId == null) return null;

    return _getTierFromProductId(activeProductId);
  }

  /// Map product ID to tier
  SubscriptionTier? _getTierFromProductId(String productId) {
    switch (productId) {
      case IAPService.silverProductId:
        return SubscriptionTier.silver;
      case IAPService.goldProductId:
        return SubscriptionTier.gold;
      case IAPService.platinumProductId:
        return SubscriptionTier.platinum;
      default:
        return null;
    }
  }

  /// Map tier to product ID
  String? _getProductIdForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.silver:
        return IAPService.silverProductId;
      case SubscriptionTier.gold:
        return IAPService.goldProductId;
      case SubscriptionTier.platinum:
        return IAPService.platinumProductId;
      case SubscriptionTier.free:
        return null;
    }
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

  /// Get tier price from IAP product details (if available)
  String getTierPrice(SubscriptionTier tier) {
    if (_iapService.isAvailable) {
      final productId = _getProductIdForTier(tier);
      if (productId != null) {
        final product = _iapService.getProduct(productId);
        if (product != null) {
          return product.price; // Formatted price from App Store
        }
      }
    }
    
    // Fallback to hardcoded prices
    switch (tier) {
      case SubscriptionTier.free: return '\$0.00';
      case SubscriptionTier.silver: return '\$9.99';
      case SubscriptionTier.gold: return '\$19.99';
      case SubscriptionTier.platinum: return '\$49.99';
    }
  }

  List<String> getTierFeatures(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return ['Basic Chat', 'Standard Voice', 'Limited Memory'];
      case SubscriptionTier.silver:
        return ['Priority Chat', 'Pro Voices', 'Extended Memory', '100 Voice Credits/mo', 'Private Space Access'];
      case SubscriptionTier.gold:
        return ['Instant Chat', 'All Voices', 'Full Memory', '500 Voice Credits/mo', '50 Video Credits/mo', 'Private Space Access'];
      case SubscriptionTier.platinum:
        return ['Concierge Support', 'Exclusive Voices', 'Unlimited Memory', '2000 Voice Credits/mo', '200 Video Credits/mo', 'Smart Adjustments Included', 'Private Space Access'];
    }
  }

  /// Check if user has access to Private Space (Silver+ tier)
  bool get hasPrivateSpaceAccess => currentTier != SubscriptionTier.free;

  @override
  void dispose() {
    _iapService.removeListener(_syncFromIAP);
    super.dispose();
  }
}
