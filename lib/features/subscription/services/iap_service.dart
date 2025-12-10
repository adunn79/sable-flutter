import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// StoreKit In-App Purchase Service
/// Handles subscription purchases, restoration, and entitlement management
class IAPService extends ChangeNotifier {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  bool _isInitialized = false;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];

  // Product IDs (must match App Store Connect)
  static const String silverProductId = 'ai.aeliana.subscription.silver.monthly';
  static const String goldProductId = 'ai.aeliana.subscription.gold.monthly';
  static const String platinumProductId = 'ai.aeliana.subscription.platinum.monthly';

  static const Set<String> _productIds = {
    silverProductId,
    goldProductId,
    platinumProductId,
  };

  // Getters
  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;
  List<ProductDetails> get products => _products;
  List<PurchaseDetails> get purchases => _purchases;

  /// Initialize IAP service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check if IAP is available on this platform
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('⚠️ IAP not available on this platform');
      _isInitialized = true;
      return;
    }

    // iOS-specific: Enable pending transactions
    if (Platform.isIOS) {
      final iosPlatformAddition = _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(IAPPaymentQueueDelegate());
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => debugPrint('Purchase stream closed'),
      onError: (error) => debugPrint('Purchase stream error: $error'),
    );

    // Fetch products
    await _fetchProducts();

    // Restore previous purchases
    await restorePurchases();

    _isInitialized = true;
    debugPrint('✅ IAP Service initialized');
  }

  /// Fetch product details from App Store
  Future<void> _fetchProducts() async {
    if (!_isAvailable) return;

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        debugPrint('❌ Error fetching products: ${response.error}');
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint('⚠️ No products found. Ensure product IDs are configured in App Store Connect.');
        return;
      }

      _products = response.productDetails;
      debugPrint('✅ Fetched ${_products.length} products');
      for (var product in _products) {
        debugPrint('  - ${product.id}: ${product.title} (${product.price})');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Exception fetching products: $e');
    }
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(String productId) async {
    if (!_isAvailable) {
      debugPrint('❌ IAP not available');
      return false;
    }

    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product $productId not found'),
    );

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      final bool success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('Purchase initiated: $success');
      return success;
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    try {
      await _iap.restorePurchases();
      debugPrint('✅ Restore purchases completed');
    } catch (e) {
      debugPrint('❌ Restore error: $e');
    }
  }

  /// Handle purchase updates from the stream
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('📦 Purchase update: ${purchaseDetails.productID} - ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
        debugPrint('⏳ Purchase pending...');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Verify and deliver purchase
        _verifyAndDeliverPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('❌ Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        debugPrint('❌ Purchase canceled');
      }

      // Mark purchase as complete (required by StoreKit)
      if (purchaseDetails.pendingCompletePurchase) {
        _iap.completePurchase(purchaseDetails);
      }
    }

    _purchases = purchaseDetailsList;
    notifyListeners();
  }

  /// Verify and deliver purchase
  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: Add server-side receipt validation here for production
    // For now, we trust the App Store receipt

    debugPrint('✅ Purchase verified: ${purchaseDetails.productID}');
    
    // The SubscriptionService will sync with this
    notifyListeners();
  }

  /// Get active subscription product ID (if any)
  String? getActiveSubscription() {
    final activePurchase = _purchases.firstWhere(
      (p) => p.status == PurchaseStatus.purchased && _productIds.contains(p.productID),
      orElse: () => PurchaseDetails(
        productID: '',
        status: PurchaseStatus.canceled,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: '',
        ),
        transactionDate: null,
      ),
    );

    return activePurchase.productID.isNotEmpty ? activePurchase.productID : null;
  }

  /// Get product details by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// iOS Payment Queue Delegate for handling transactions
class IAPPaymentQueueDelegate extends SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
