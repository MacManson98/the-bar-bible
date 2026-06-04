import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Manages RevenueCat purchases and premium entitlement checks.
class PurchaseService extends ChangeNotifier {
  static const String _iosApiKey = 'appl_IRvvIbtoajxOjwxJhkdiUrnDSxg';
  static const String _entitlementId = 'The Bar Bible Pro';
  static const String _offeringId = 'Premium Unlock';

  bool _isPremium = false;
  bool _isLoading = false;
  CustomerInfo? _customerInfo;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  /// Initialise Firebase Auth + RevenueCat — call once at app startup.
  Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);

    final config = PurchasesConfiguration(_iosApiKey);
    await Purchases.configure(config);

    // Sign in anonymously so purchases are tied to a Firebase UID
    await _ensureSignedIn();

    Purchases.addCustomerInfoUpdateListener((info) {
      _customerInfo = info;
      _isPremium = _checkEntitlement(info);
      notifyListeners();
    });

    await refreshStatus();
  }

  /// Ensure user is signed in (anonymously if needed).
  Future<void> _ensureSignedIn() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        await Purchases.logIn(uid);
      }
    } catch (e) {
      debugPrint('[PurchaseService] Auth error: $e');
    }
  }

  /// Refresh purchase status from RevenueCat.
  Future<void> refreshStatus() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _isPremium = _checkEntitlement(_customerInfo!);
      notifyListeners();
    } catch (e) {
      debugPrint('[PurchaseService] Failed to refresh status: $e');
    }
  }

  /// Purchase premium unlock.
  Future<bool> purchasePremium() async {
    _isLoading = true;
    notifyListeners();

    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(_offeringId) ?? offerings.current;

      if (offering == null) {
        debugPrint('[PurchaseService] No offering found');
        return false;
      }

      final package = offering.lifetime;
      if (package == null) {
        debugPrint('[PurchaseService] No lifetime package found');
        return false;
      }

      final info = await Purchases.purchasePackage(package);
      _customerInfo = info;
      _isPremium = _checkEntitlement(info);
      notifyListeners();
      return _isPremium;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[PurchaseService] Purchase cancelled');
      } else {
        debugPrint('[PurchaseService] Purchase error: $e');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore previous purchases.
  Future<bool> restorePurchases() async {
    _isLoading = true;
    notifyListeners();

    try {
      final info = await Purchases.restorePurchases();
      _customerInfo = info;
      _isPremium = _checkEntitlement(info);
      notifyListeners();
      return _isPremium;
    } catch (e) {
      debugPrint('[PurchaseService] Restore error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _checkEntitlement(CustomerInfo info) {
    return info.entitlements.active.containsKey(_entitlementId);
  }
}
