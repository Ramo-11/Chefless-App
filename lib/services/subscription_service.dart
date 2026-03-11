import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../utils/constants.dart';

/// Manages RevenueCat subscription state and purchase flows.
///
/// Exposes an [isPremiumStream] that emits whenever the user's entitlement
/// status changes, plus methods for purchasing and restoring.
class SubscriptionService {
  SubscriptionService();

  final StreamController<bool> _premiumController =
      StreamController<bool>.broadcast();

  /// Whether a deletion is in progress. When true, RevenueCat listener
  /// updates are ignored to prevent stale state from overwriting deletion.
  bool isDeleting = false;

  bool _initialized = false;

  /// Stream that emits `true` when the user has an active premium entitlement.
  Stream<bool> get isPremiumStream => _premiumController.stream;

  /// Initializes the RevenueCat SDK and starts listening to customer info
  /// changes.
  Future<void> init({required String userId}) async {
    if (_initialized) return;

    final configuration = PurchasesConfiguration(RevenueCatConstants.apiKey)
      ..appUserID = userId;
    await Purchases.configure(configuration);

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      if (isDeleting) return;
      final isPremium = _checkEntitlements(customerInfo);
      _premiumController.add(isPremium);
    });

    _initialized = true;

    // Emit initial premium status.
    final customerInfo = await Purchases.getCustomerInfo();
    _premiumController.add(_checkEntitlements(customerInfo));
  }

  /// Fetches available subscription offerings from RevenueCat.
  Future<Offerings> getOfferings() async {
    return Purchases.getOfferings();
  }

  /// Initiates a purchase for the given [package].
  ///
  /// Returns `true` if the purchase was successful, `false` if it was
  /// cancelled by the user. Throws for other errors.
  Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final isPremium = _checkEntitlements(customerInfo);
      _premiumController.add(isPremium);
      return isPremium;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  /// Restores previous purchases. Returns `true` if the user has premium
  /// after restoration.
  Future<bool> restorePurchases() async {
    final customerInfo = await Purchases.restorePurchases();
    final isPremium = _checkEntitlements(customerInfo);
    _premiumController.add(isPremium);
    return isPremium;
  }

  /// Checks the current premium status without triggering a purchase.
  Future<bool> checkPremiumStatus() async {
    final customerInfo = await Purchases.getCustomerInfo();
    return _checkEntitlements(customerInfo);
  }

  bool _checkEntitlements(CustomerInfo customerInfo) {
    return customerInfo.entitlements.active
        .containsKey(RevenueCatConstants.premiumEntitlementId);
  }

  /// Releases resources. Call when no longer needed.
  void dispose() {
    _premiumController.close();
  }
}
