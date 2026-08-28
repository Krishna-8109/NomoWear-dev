import 'package:flutter/foundation.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rental booking path chosen on CHOOSE (distinct from [CheckoutBookingMode]).
enum WardrobeBookingPath {
  none,
  subscription,
  withoutSubscription,
}

/// Lifecycle of a wardrobe rental booking journey.
enum WardrobeBookingSessionStatus {
  none,
  active,
  completed,
  closed,
}

/// Persists the wardrobe rental booking journey.
class WardrobeBookingSession {
  WardrobeBookingSession._();

  static final WardrobeBookingSession instance = WardrobeBookingSession._();

  WardrobeBookingSessionStatus sessionStatus = WardrobeBookingSessionStatus.none;
  bool hasSelectedBookingPath = false;
  WardrobeBookingPath selectedPath = WardrobeBookingPath.none;
  bool kitSelected = false;
  bool paymentCompleted = false;
  /// User tapped Take Subscription but has not finished plan purchase yet.
  bool awaitingSubscriptionPurchase = false;
  String? wardrobeCategory;
  String? wardrobeCategoryId;
  String? selectedKitId;
  int kitGarmentLimit = 0;

  bool _didRestore = false;

  /// True only while a wardrobe booking is in progress (kit selected, unpaid).
  bool get isBookingSessionActive =>
      sessionStatus == WardrobeBookingSessionStatus.active;

  bool get shouldContinueToProducts =>
      isBookingSessionActive && kitSelected;

  bool get isClosed =>
      sessionStatus == WardrobeBookingSessionStatus.closed;

  bool get isSubscriptionPath =>
      selectedPath == WardrobeBookingPath.subscription;

  bool get isWithoutSubscriptionPath =>
      selectedPath == WardrobeBookingPath.withoutSubscription;

  /// @deprecated Use [isBookingSessionActive]. Kept for persisted-key migration.
  bool get bookingSessionActive => isBookingSessionActive;

  Future<void> restore() async {
    if (_didRestore) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    final savedStatus = prefs.getString(_kSessionStatus);
    sessionStatus = WardrobeBookingSessionStatus.values.firstWhere(
      (e) => e.name == savedStatus,
      orElse: () => WardrobeBookingSessionStatus.none,
    );
    
    hasSelectedBookingPath = prefs.getBool(_kHasSelectedPath) ?? false;
    
    final savedPath = prefs.getString(_kSelectedPath);
    selectedPath = WardrobeBookingPath.values.firstWhere(
      (e) => e.name == savedPath,
      orElse: () => WardrobeBookingPath.none,
    );
    
    kitSelected = prefs.getBool(_kKitSelected) ?? false;
    paymentCompleted = prefs.getBool(_kPaymentCompleted) ?? false;
    awaitingSubscriptionPurchase = prefs.getBool(_kAwaitingSubPurchase) ?? false;
    
    wardrobeCategory = prefs.getString(_kWardrobeCategory);
    wardrobeCategoryId = prefs.getString(_kWardrobeCategoryId);
    selectedKitId = prefs.getString(_kSelectedKitId);
    kitGarmentLimit = prefs.getInt(_kKitGarmentLimit) ?? 0;
    
    _didRestore = true;
    _logState('restore');
  }

  Future<void> selectPath({
    required WardrobeBookingPath path,
    required String wardrobeCategory,
    String? wardrobeCategoryId,
    required bool needsSubscriptionPurchase,
  }) async {
    sessionStatus = WardrobeBookingSessionStatus.active;
    hasSelectedBookingPath = true;
    selectedPath = path;
    this.wardrobeCategory = wardrobeCategory.trim();
    this.wardrobeCategoryId = wardrobeCategoryId?.trim();
    kitSelected = false;
    paymentCompleted = false;
    awaitingSubscriptionPurchase =
        path == WardrobeBookingPath.subscription && needsSubscriptionPurchase;
    selectedKitId = null;
    kitGarmentLimit = 0;
    await _persist();
    _logState('selectPath');
  }

  Future<void> markKitSelected({
    String? kitId,
    int? kitGarmentLimit,
  }) async {
    kitSelected = true;
    awaitingSubscriptionPurchase = false;
    if (kitId != null && kitId.trim().isNotEmpty) {
      selectedKitId = kitId.trim();
    }
    if (kitGarmentLimit != null && kitGarmentLimit > 0) {
      this.kitGarmentLimit = kitGarmentLimit;
    }
    if (sessionStatus == WardrobeBookingSessionStatus.none) {
      sessionStatus = WardrobeBookingSessionStatus.active;
    }
    await _persist();
    _logState('markKitSelected');
  }

  /// Continue Without Membership after an unpaid subscription cart.
  /// Does not clear cart items. Next CHOOSE skips the path popup and opens Kit.
  Future<void> beginPaidRentalContinuation() async {
    selectedPath = WardrobeBookingPath.withoutSubscription;
    hasSelectedBookingPath = true;
    sessionStatus = WardrobeBookingSessionStatus.active;
    kitSelected = false;
    paymentCompleted = false;
    awaitingSubscriptionPurchase = false;
    selectedKitId = null;
    kitGarmentLimit = 0;
    wardrobeCategory = null;
    wardrobeCategoryId = null;
    await _persist();
    _logState('beginPaidRentalContinuation');
  }

  /// Continue Without Membership from Limit Reached popup.
  /// Does not clear cart items AND does not clear the selected category.
  Future<void> continuePaidRentalWithoutClearingCategory() async {
    selectedPath = WardrobeBookingPath.withoutSubscription;
    hasSelectedBookingPath = true;
    sessionStatus = WardrobeBookingSessionStatus.active;
    kitSelected = false;
    paymentCompleted = false;
    awaitingSubscriptionPurchase = false;
    selectedKitId = null;
    kitGarmentLimit = 0;
    // DO NOT clear wardrobeCategory or wardrobeCategoryId
    await _persist();
    _logState('continuePaidRentalWithoutClearingCategory');
  }

  /// Records the CHOOSE category for a paid-rental continuation without
  /// resetting the cart or the continue-without path.
  Future<void> setContinuationCategory({
    required String wardrobeCategory,
    String? wardrobeCategoryId,
  }) async {
    this.wardrobeCategory = wardrobeCategory.trim();
    final id = wardrobeCategoryId?.trim();
    this.wardrobeCategoryId =
        (id != null && id.isNotEmpty) ? id : this.wardrobeCategoryId;
    await _persist();
    _logState('setContinuationCategory');
  }

  Future<void> markSubscriptionPurchased() async {
    awaitingSubscriptionPurchase = false;
    if (sessionStatus == WardrobeBookingSessionStatus.none) {
      sessionStatus = WardrobeBookingSessionStatus.active;
    }
    await _persist();
    _logState('markSubscriptionPurchased');
  }

  Future<void> markPaymentCompleted() async {
    paymentCompleted = true;
    sessionStatus = WardrobeBookingSessionStatus.completed;
    await _persist();
    _logState('markPaymentCompleted');
  }

  Future<void> closeCurrentBooking() async {
    sessionStatus = WardrobeBookingSessionStatus.closed;
    await _persist();
    _logState('closeCurrentBooking');
  }

  /// Called when the unpaid non-subscription cart is fully cleared.
  /// Next CHOOSE shows Take Subscription / Continue Without Subscription.
  Future<void> onUnpaidNonSubscriptionCartCleared() async {
    CheckoutSession.instance.clearWardrobeCategoryLock();
    // Keep Continue Without Membership when subscription garments remain —
    // that path is only reset when the paid-rental booking is fully abandoned.
    if (!isWithoutSubscriptionPath && !isClosed) return;
    await startNewBooking();
    CheckoutSession.instance.setDelivery(continueWithoutMembership: false);
  }

  Future<void> startNewBooking() async {
    sessionStatus = WardrobeBookingSessionStatus.none;
    hasSelectedBookingPath = false;
    selectedPath = WardrobeBookingPath.none;
    kitSelected = false;
    paymentCompleted = false;
    awaitingSubscriptionPurchase = false;
    wardrobeCategory = null;
    wardrobeCategoryId = null;
    selectedKitId = null;
    kitGarmentLimit = 0;
    await _persist();
    _logState('startNewBooking');
  }

  Future<void> resetForNewBooking() async {
    sessionStatus = WardrobeBookingSessionStatus.none;
    hasSelectedBookingPath = false;
    selectedPath = WardrobeBookingPath.none;
    kitSelected = false;
    paymentCompleted = false;
    awaitingSubscriptionPurchase = false;
    wardrobeCategory = null;
    wardrobeCategoryId = null;
    selectedKitId = null;
    kitGarmentLimit = 0;
    await _clearPersisted();
    _logState('resetForNewBooking');
  }

  void logChooseDecision(CartState cart) {
    _logState('CHOOSE', cart: cart);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionStatus, sessionStatus.name);
    await prefs.setBool(_kHasSelectedPath, hasSelectedBookingPath);
    await prefs.setString(_kSelectedPath, selectedPath.name);
    await prefs.setBool(_kKitSelected, kitSelected);
    await prefs.setBool(_kPaymentCompleted, paymentCompleted);
    await prefs.setBool(_kAwaitingSubPurchase, awaitingSubscriptionPurchase);
    
    if (wardrobeCategory != null && wardrobeCategory!.isNotEmpty) {
      await prefs.setString(_kWardrobeCategory, wardrobeCategory!);
    } else {
      await prefs.remove(_kWardrobeCategory);
    }
    
    if (wardrobeCategoryId != null && wardrobeCategoryId!.isNotEmpty) {
      await prefs.setString(_kWardrobeCategoryId, wardrobeCategoryId!);
    } else {
      await prefs.remove(_kWardrobeCategoryId);
    }
    
    if (selectedKitId != null && selectedKitId!.isNotEmpty) {
      await prefs.setString(_kSelectedKitId, selectedKitId!);
    } else {
      await prefs.remove(_kSelectedKitId);
    }
    
    if (kitGarmentLimit > 0) {
      await prefs.setInt(_kKitGarmentLimit, kitGarmentLimit);
    } else {
      await prefs.remove(_kKitGarmentLimit);
    }
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionStatus);
    await prefs.remove(_kSessionActive);
    await prefs.remove(_kHasSelectedPath);
    await prefs.remove(_kSelectedPath);
    await prefs.remove(_kKitSelected);
    await prefs.remove(_kPaymentCompleted);
    await prefs.remove(_kAwaitingSubPurchase);
    await prefs.remove(_kWardrobeCategory);
    await prefs.remove(_kWardrobeCategoryId);
    await prefs.remove(_kSelectedKitId);
    await prefs.remove(_kKitGarmentLimit);
  }

  void _logState(String tag, {CartState? cart}) {
    if (!kDebugMode) return;
    final purchaseCount = cart?.essentialItems.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        ) ??
        0;
    debugPrint(
      '[CHOOSE:$tag] sessionStatus=${sessionStatus.name} '
      'isBookingSessionActive=$isBookingSessionActive '
      'hasSelectedBookingPath=$hasSelectedBookingPath '
      'selectedPath=${selectedPath.name} '
      'kitSelected=$kitSelected '
      'selectedKitId=$selectedKitId '
      'kitGarmentLimit=$kitGarmentLimit '
      'paymentCompleted=$paymentCompleted '
      'categoryId=$wardrobeCategoryId '
      'activeNonSubCategoryId=${CheckoutSession.instance.activeNonSubscriptionCategoryId} '
      'cartSubscriptionItems=${cart?.subscriptionGarmentCount ?? 'n/a'} '
      'cartNonSubscriptionItems=${cart?.paidRentalGarmentCount ?? 'n/a'} '
      'cartPurchaseItems=$purchaseCount '
      'category=$wardrobeCategory',
    );
  }
}

const _kSessionStatus = 'wb_session_status';
const _kSessionActive = 'wb_session_active';
const _kHasSelectedPath = 'wb_has_selected_path';
const _kSelectedPath = 'wb_selected_path';
const _kKitSelected = 'wb_kit_selected';
const _kPaymentCompleted = 'wb_payment_completed';
const _kAwaitingSubPurchase = 'wb_awaiting_sub_purchase';
const _kWardrobeCategory = 'wb_wardrobe_category';
const _kWardrobeCategoryId = 'wb_wardrobe_category_id';
const _kSelectedKitId = 'wb_selected_kit_id';
const _kKitGarmentLimit = 'wb_kit_garment_limit';
