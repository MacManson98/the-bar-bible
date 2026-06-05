import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Manages RevenueCat purchases and premium entitlement checks.
class PurchaseService extends ChangeNotifier {
  static const String _iosApiKey = 'appl_IRvvIbtoajxOjwxJhkdiUrnDSxg';
  static const String _entitlementId = 'The Bar Bible Pro';

  bool _isPremium = false;
  bool _isLoading = false;
  CustomerInfo? _customerInfo;
  Offering? _currentOffering;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  Offering? get currentOffering => _currentOffering;

  // Convenience getters for each package
  Package? get weeklyPackage => _currentOffering?.weekly;
  Package? get monthlyPackage => _currentOffering?.monthly;
  Package? get annualPackage => _currentOffering?.annual;

  /// Initialise RevenueCat — call once at app startup.
  Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);
    final config = PurchasesConfiguration(_iosApiKey);
    await Purchases.configure(config);

    Purchases.addCustomerInfoUpdateListener((info) {
      _customerInfo = info;
      _isPremium = _checkEntitlement(info);
      notifyListeners();
    });

    await refreshStatus();
    await _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      _currentOffering = offerings.current;
      notifyListeners();
    } catch (e) {
      debugPrint('[PurchaseService] Failed to load offerings: $e');
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

  /// Purchase a specific package.
  Future<bool> purchasePackage(Package package) async {
    _isLoading = true;
    notifyListeners();

    try {
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

  /// Purchase premium — uses selected plan index (0=weekly, 1=monthly, 2=annual).
  Future<bool> purchasePremium({int planIndex = 1}) async {
    Package? package;
    switch (planIndex) {
      case 0:
        package = weeklyPackage;
        break;
      case 1:
        package = monthlyPackage;
        break;
      case 2:
        package = annualPackage;
        break;
    }

    if (package == null) {
      debugPrint('[PurchaseService] No package found for plan index $planIndex');
      return false;
    }

    return purchasePackage(package);
  }

  /// Log in to RevenueCat with the Firebase UID so entitlements are linked.
  Future<void> loginUser(String uid) async {
    try {
      await Purchases.logIn(uid);
      await refreshStatus();
    } catch (e) {
      debugPrint('[PurchaseService] logIn error: $e');
    }
  }

  /// Log out of RevenueCat (on sign-out).
  Future<void> logoutUser() async {
    try {
      await Purchases.logOut();
      _isPremium = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[PurchaseService] logOut error: $e');
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
