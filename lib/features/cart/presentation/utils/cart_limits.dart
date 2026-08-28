import 'package:flutter/foundation.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/checkout/data/subscription_kit_preferences.dart';
import 'package:nomowear/features/checkout/data/wardrobe_booking_session.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/products/data/product_catalog.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';

bool isEssentialCategory(String? category) {
  if (category == null) return false;
  final lower = category.trim().toLowerCase();
  return lower == 'essential wear' ||
      lower == 'essentials wardrobe' ||
      lower == 'essentials wear' ||
      lower == 'essentials' ||
      lower == 'kids wardrobe' ||
      lower == 'kids wear' ||
      lower == 'kids' ||
      lower.contains('essential') ||
      lower.contains('kid');
}

bool isKidsCategory(String? category) {
  final value = category?.trim().toLowerCase() ?? '';
  return value.contains('kid');
}

bool isEssentialsListingCategory(String? category) {
  final c = category?.trim().toLowerCase() ?? '';
  return c == 'essential wear' ||
      c == 'essentials wardrobe' ||
      c == 'essentials wear' ||
      c.contains('essential');
}

class CartLimits {
  CartLimits._();
  static int? _lastLoggedKitLimit;
  static bool _lastLoggedMissingLimit = false;

  static void _logKitLimitSource(int limit) {
    if (!kDebugMode) return;
    if (limit > 0) {
      if (_lastLoggedKitLimit == limit && !_lastLoggedMissingLimit) return;
      _lastLoggedKitLimit = limit;
      _lastLoggedMissingLimit = false;
      debugPrint('[KIT_LIMIT]');
      debugPrint('source=backend');
      debugPrint('maxGarments=$limit');
      return;
    }
    if (_lastLoggedMissingLimit) return;
    _lastLoggedKitLimit = null;
    _lastLoggedMissingLimit = true;
    debugPrint('[KIT_LIMIT]');
    debugPrint('source=unknown');
    debugPrint('backend_limit_missing=true');
  }


  /// Shown when the user tries to mix wardrobe categories.
  static const String singleCategoryRestrictionMessage =
      'Please clear cart products and select another category.';

  /// Standard max garments based on kit duration days.
  static int maxGarmentsForKit(int kitDays) {
    if (kitDays == 1) return 4;
    if (kitDays == 3) return 7;
    if (kitDays == 7) return 10;
    if (kitDays > 0) return 4;
    return 0;
  }

  static int wardrobeGarmentCount(CartState state) =>
      state.wardrobeItems.fold<int>(0, (sum, item) => sum + item.quantity);

  static int subscriptionGarmentCount(CartState state) =>
      state.subscriptionGarmentCount;

  /// Kit max applies to all wardrobe rental garments (subscription + paid).
  static int kitMaxWardrobeGarments(CartState state) {
    if (state.wardrobeKitMaxGarments > 0) {
      return state.wardrobeKitMaxGarments;
    }
    final sessionLimit = WardrobeBookingSession.instance.kitGarmentLimit;
    if (sessionLimit > 0) return sessionLimit;

    final prefLimit = SubscriptionKitPreferences.instance.wardrobeKitMaxGarments;
    if (prefLimit > 0) return prefLimit;

    final days = state.wardrobeKitDays > 0
        ? state.wardrobeKitDays
        : SubscriptionKitPreferences.instance.wardrobeKitDays;
    if (days > 0) {
      final fromDays = maxGarmentsForKit(days);
      if (fromDays > 0) return fromDays;
    }

    if (state.wardrobeItems.isNotEmpty ||
        WardrobeBookingSession.instance.kitSelected ||
        SubscriptionKitPreferences.instance.isKitConfigured) {
      return 4;
    }
    return 0;
  }

  static int currentKitGarmentLimit(CartState state) =>
      () {
        final limit = kitMaxWardrobeGarments(state);
        _logKitLimitSource(limit);
        return limit;
      }();

  static int currentSubscriptionCartGarmentCount(CartState state) =>
      state.subscriptionGarmentCount;

  /// Kit / current unpaid subscription booking garment cap.
  /// Enforces MIN(kitMax, subscriptionRemainingEntitlement).
  static int currentSubscriptionBookingLimit(CartState state) {
    final kitLimit = currentKitGarmentLimit(state);
    final subRemaining = subscriptionRemainingEntitlement();
    if (subRemaining != null && subRemaining < kitLimit) {
      return subRemaining;
    }
    return kitLimit;
  }

  static bool isCurrentUnpaidSubscriptionCartFull(CartState state) {
    if (WardrobeBookingSession.instance.paymentCompleted) return false;
    final limit = currentSubscriptionBookingLimit(state);
    if (limit <= 0) return false;
    return currentSubscriptionCartGarmentCount(state) >=
        limit;
  }

  /// Next subscription add would exceed the unpaid cart/kit garment cap.
  /// Ignores backend remainingGarments.
  static bool wouldExceedUnpaidSubscriptionCartLimit(
    CartState state,
    CartItem item,
  ) {
    if (item.isEssential) return false;
    if (WardrobeBookingSession.instance.paymentCompleted) return false;
    if (CheckoutSession.instance.continueWithoutMembership) return false;
    if (WardrobeBookingSession.instance.isWithoutSubscriptionPath) return false;
    if (!item.isSubscriptionGarment && !shouldAddAsSubscriptionGarment(item)) {
      return false;
    }
    final limit = currentSubscriptionBookingLimit(state);
    if (limit <= 0) return false;
    final next = subscriptionCountAfterAdding(state, item);
    return next > limit;
  }

  static int currentBookingSelectedGarments(CartState state) =>
      wardrobeGarmentCount(state);

  static int currentKitRemainingGarments(CartState state) {
    final remaining =
        currentKitGarmentLimit(state) - currentBookingSelectedGarments(state);
    return remaining < 0 ? 0 : remaining;
  }

  /// Remaining subscription garment balance (NOT booking count).
  static int? subscriptionRemainingEntitlement() =>
      SubscriptionCache.instance.remainingGarmentsBalance;

  static int subscriptionTotalBookings() =>
      SubscriptionCache.instance.activeSubscription?.noOfBookings ?? 0;

  static int subscriptionUsedBookings() =>
      SubscriptionCache.instance.activeSubscription?.usedBookingsCount ?? 0;

  static int subscriptionRemainingBookings() =>
      SubscriptionCache.instance.activeSubscription?.remainingBookingsCount ?? 0;

  /// True only when the API explicitly says remaining bookings are exhausted.
  /// Null remaining/used fields are NOT treated as zero.
  static bool isSubscriptionBookingLimitExhausted() {
    final active = SubscriptionCache.instance.activeSubscription;
    if (active == null || !active.isActive) return false;
    return active.isBookingLimitExhausted == true;
  }

  /// Paid-rental / non-subscription kit cap only.
  /// Subscription cart-full is UNLOCK FULL ACCESS, not this dialog.
  static bool wouldExceedKitGarmentLimit(CartState state, CartItem item) {
    if (item.isEssential) return false;
    if (item.isSubscriptionGarment || shouldAddAsSubscriptionGarment(item)) {
      return false;
    }
    // After Continue Without Membership, paid extras must not be blocked by
    // the same 15 subscription garments already in the unpaid cart.
    if (subscriptionGarmentCount(state) > 0) return false;
    final limit = currentKitGarmentLimit(state);
    if (limit <= 0) return false;
    return countAfterAdding(state, item) > limit;
  }

  /// Period booking-count exhausted (completed bookings), not unpaid cart.
  static bool wouldExceedSubscriptionBookingLimit(CartItem item) {
    if (item.isEssential) return false;
    if (CheckoutSession.instance.continueWithoutMembership) return false;
    if (WardrobeBookingSession.instance.isWithoutSubscriptionPath) return false;
    return isSubscriptionBookingLimitExhausted();
  }

  /// True when the next wardrobe add should be tagged as a subscription garment.
  static bool shouldAddAsSubscriptionGarment(CartItem item) {
    if (item.isKids || item.itemType == 'kids') return false;
    if (item.isEssential || item.itemType == 'essentials') return false;
    if (CheckoutSession.instance.continueWithoutMembership) return false;
    final session = WardrobeBookingSession.instance;
    if (session.isWithoutSubscriptionPath) return false;
    return session.isSubscriptionPath ||
        CheckoutSession.instance.useSubscriptionBooking;
  }

  /// Cart `item_type` strictly from backend product data.
  /// Does NOT infer item_type from flow flags, booking mode, or local state.
  static String cartItemTypeForListing({String? itemType}) {
    final explicit = itemType?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return '';
  }

  static int countAfterAdding(CartState state, CartItem item) {
    if (item.isEssential) return wardrobeGarmentCount(state);

    final existing = state.lineForProduct(
      item.productId,
      variantId: item.variantId,
      itemType: item.itemType.isNotEmpty ? item.itemType : null,
    );
    if (existing != null) {
      return wardrobeGarmentCount(state) + 1;
    }
    return wardrobeGarmentCount(state) + item.quantity;
  }

  static int subscriptionCountAfterAdding(CartState state, CartItem item) {
    if (!shouldAddAsSubscriptionGarment(item)) {
      return subscriptionGarmentCount(state);
    }
    final existing = state.lineForProduct(
      item.productId,
      variantId: item.variantId,
      itemType: 'subscription',
    );
    if (existing != null && existing.isSubscriptionGarment) {
      return subscriptionGarmentCount(state) + 1;
    }
    if (existing != null) return subscriptionGarmentCount(state);
    return subscriptionGarmentCount(state) + item.quantity;
  }

  /// Back-compat name — booking count, not remaining garments.
  static bool wouldExceedSubscriptionEntitlement(
    CartState state,
    CartItem item,
  ) {
    return wouldExceedSubscriptionBookingLimit(item);
  }

  /// Back-compat alias — kit garment cap only (not subscription entitlement).
  static bool wouldExceedWardrobeLimit(CartState state, CartItem item) {
    return wouldExceedKitGarmentLimit(state, item);
  }

  /// Qty / kit cap for the current unpaid booking (kit garments only).
  /// Does not use backend remainingGarments.
  static int effectiveMaxWardrobeGarments(CartState state) {
    return currentKitGarmentLimit(state);
  }

  /// Max qty for subscription-tagged garments in the current unpaid cart.
  static int effectiveMaxSubscriptionGarments(CartState state) {
    return currentSubscriptionBookingLimit(state);
  }

  /// Strict ACTIVE check for subscription booking only.
  static bool hasActiveSubscriptionCached() {
    final active = SubscriptionCache.instance.activeSubscription;
    if (active == null) return false;
    return active.isActive;
  }

  /// Subscribed users on the subscription path may open any CHOOSE category.
  /// Continue Without Membership is a paid-rental continuation and is NOT exempt.
  static bool isExemptFromSingleCategoryRule() {
    if (CheckoutSession.instance.continueWithoutMembership) return false;
    if (WardrobeBookingSession.instance.isWithoutSubscriptionPath) return false;
    return hasActiveSubscriptionCached();
  }

  /// Unpaid paid-rental garments currently in the cart (not subscription lines).
  static bool hasActiveNonSubscriptionCart(CartState state) {
    return state.paidRentalGarmentItems.isNotEmpty;
  }

  /// Category lock for paid rental only — subscription lines must not lock.
  static String? lockedPaidRentalCategory(CartState state) {
    for (final item in state.paidRentalGarmentItems) {
      final fromItem = mapToHomeWardrobeKey(item.category);
      if (fromItem != null) return fromItem;
      final product = ProductCache.instance.findById(item.productId);
      final fromProduct = mapToHomeWardrobeKey(product?.categoryName);
      if (fromProduct != null) return fromProduct;
    }
    // Do not use CheckoutSession.wardrobeCategory here — after Continue Without
    // Membership that field can reflect the next CHOOSE category before any
    // paid items exist, and must not lock from subscription-era category.
    return null;
  }

  static String? activeNonSubscriptionCategoryId(CartState state) {
    final fromSession =
        CheckoutSession.instance.activeNonSubscriptionCategoryId?.trim();
    if (fromSession != null && fromSession.isNotEmpty) return fromSession;
    return null;
  }

  static String normalizeCategory(String? category) {
    return (category ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool categoriesMatch(String a, String b) {
    final left = normalizeCategory(a);
    final right = normalizeCategory(b);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;
    // Treat "Comfort" and "Comfort Wardrobe" as the same lock key.
    final leftCore = left.replaceAll('wardrobe', '').trim();
    final rightCore = right.replaceAll('wardrobe', '').trim();
    return leftCore.isNotEmpty && leftCore == rightCore;
  }

  static String? mapToHomeWardrobeKey(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || isEssentialCategory(value)) return null;
    for (final key in ProductCatalog.homeWardrobeKeys) {
      if (categoriesMatch(value, key)) return key;
    }
    return value;
  }

  /// True when the cart actually has wardrobe garment(s).
  /// Kit preference / session alone must not block after the cart is cleared.
  static bool hasWardrobeCommitment(CartState state) {
    if (state.wardrobeItems.isNotEmpty) return true;
    for (final item in state.items) {
      if (isEssentialCategory(item.category)) continue;
      final product = ProductCache.instance.findById(item.productId);
      if (product == null) {
        if ((item.category ?? '').trim().isNotEmpty &&
            !isEssentialCategory(item.category)) {
          return true;
        }
        continue;
      }
      if (ProductCatalog.isDirectPurchaseProduct(product)) continue;
      if (product.isWardrobeKit) continue;
      return true;
    }
    return false;
  }

  /// Locked wardrobe category for non-sub / one-time booking users.
  ///
  /// Only returns a lock when [hasWardrobeCommitment] is true (kit NEXT and/or
  /// garments in cart). Clearing the cart therefore unlocks other categories.
  static String? lockedWardrobeCategory(CartState state) {
    if (!hasWardrobeCommitment(state)) return null;

    final fromState = mapToHomeWardrobeKey(state.wardrobeCategory);
    if (fromState != null) return fromState;

    final fromSession =
        mapToHomeWardrobeKey(CheckoutSession.instance.wardrobeCategory);
    if (fromSession != null) return fromSession;

    for (final item in state.wardrobeItems) {
      final fromItem = mapToHomeWardrobeKey(item.category);
      if (fromItem != null) return fromItem;

      final product = ProductCache.instance.findById(item.productId);
      final fromProduct = mapToHomeWardrobeKey(product?.categoryName);
      if (fromProduct != null) return fromProduct;
    }

    // Fallback when isEssential flags are wrong after remote sync.
    for (final item in state.items) {
      if (isEssentialCategory(item.category)) continue;
      final product = ProductCache.instance.findById(item.productId);
      if (product == null) {
        final fromItem = mapToHomeWardrobeKey(item.category);
        if (fromItem != null) return fromItem;
        continue;
      }
      if (ProductCatalog.isDirectPurchaseProduct(product)) continue;
      if (product.isWardrobeKit) {
        final fromKit = mapToHomeWardrobeKey(
          product.categoryName ?? product.productName,
        );
        if (fromKit != null) return fromKit;
        continue;
      }
      final fromProduct = mapToHomeWardrobeKey(
        item.category ?? product.categoryName,
      );
      if (fromProduct != null) return fromProduct;
    }

    return null;
  }

  static bool hasWardrobeLockContext(CartState state) {
    return hasWardrobeCommitment(state);
  }

  /// Non-sub / paid-rental: only one wardrobe category at a time.
  /// Subscription lines do not participate in this lock.
  static bool wouldViolateSingleCategoryRule(
    CartState state, {
    required String? incomingCategory,
    required bool isEssential,
    bool isSubscriptionGarment = false,
  }) {
    if (isSubscriptionGarment) return false;
    if (isEssential || isEssentialCategory(incomingCategory)) return false;

    if (isExemptFromSingleCategoryRule() &&
        !CheckoutSession.instance.continueWithoutMembership &&
        !hasActiveNonSubscriptionCart(state)) {
      _debug(
        'single-category ALLOW (exempt) incoming=$incomingCategory',
      );
      return false;
    }

    if (!hasActiveNonSubscriptionCart(state)) {
      return false;
    }

    final locked = lockedPaidRentalCategory(state);
    final incoming = incomingCategory?.trim() ?? '';
    if (incoming.isEmpty) return false;
    if (locked == null || locked.isEmpty) return false;

    final violates = !categoriesMatch(incoming, locked);
    _debug(
      'single-category paid-lock=$locked incoming=$incoming violates=$violates',
    );
    return violates;
  }

  /// Home / booking entry guard: block opening a different wardrobe category.
  ///
  /// Module 1: only unpaid non-subscription carts lock a single category ID.
  static bool wouldViolateCategorySelection(
    CartState state,
    String wardrobeCategory, {
    String? categoryId,
  }) {
    if (isEssentialCategory(wardrobeCategory)) return false;

    // 1. Strict explicit session lock for WITHOUT_MEMBERSHIP
    final isWithoutMembership = CheckoutSession.instance.continueWithoutMembership ||
        WardrobeBookingSession.instance.isWithoutSubscriptionPath;

    if (isWithoutMembership) {
      if (!hasActiveNonSubscriptionCart(state)) {
        _debug('home-category ALLOW (without-membership, no paid items) incomingId=$categoryId');
        return false;
      }

      final lockedId = activeNonSubscriptionCategoryId(state);
      final incomingId = categoryId?.trim() ?? '';
      
      if (lockedId != null && lockedId.isNotEmpty && incomingId.isNotEmpty) {
        if (lockedId != incomingId) {
          _debug('home-category BLOCK (without-membership) lockedId=$lockedId incomingId=$incomingId');
          return true;
        }
      }

      // Also enforce by string category if ID is missing or different
      final lockedCat = CheckoutSession.instance.wardrobeCategory;
      if (lockedCat != null && lockedCat.trim().isNotEmpty) {
         if (!categoriesMatch(wardrobeCategory, lockedCat)) {
           _debug('home-category BLOCK (without-membership string) lockedCat=$lockedCat incoming=$wardrobeCategory');
           return true;
         }
      }
    }

    if (isExemptFromSingleCategoryRule() && !hasActiveNonSubscriptionCart(state)) {
      _debug(
        'home-category ALLOW (subscribed, no paid cart) incomingId=$categoryId '
        'incoming=$wardrobeCategory',
      );
      return false;
    }

    if (!hasActiveNonSubscriptionCart(state)) {
      _debug(
        'home-category ALLOW (no unpaid paid-rental cart) incomingId=$categoryId',
      );
      return false;
    }

    final lockedId = activeNonSubscriptionCategoryId(state);
    final incomingId = categoryId?.trim() ?? '';
    if (lockedId != null && lockedId.isNotEmpty && incomingId.isNotEmpty) {
      final violates = lockedId != incomingId;
      _debug(
        'home-category lockedId=$lockedId incomingId=$incomingId '
        'violates=$violates',
      );
      return violates;
    }

    return wouldViolateSingleCategoryRule(
      state,
      incomingCategory: wardrobeCategory,
      isEssential: false,
    );
  }

  static void _debug(String message) {
    if (kDebugMode) {
      debugPrint('[CATEGORY_LOCK] $message');
    }
  }
}
