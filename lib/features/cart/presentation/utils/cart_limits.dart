import 'package:flutter/foundation.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/products/data/product_catalog.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';

bool isEssentialCategory(String? category) {
  return category == 'Essential Wear' ||
      category == 'Essentials Wardrobe' ||
      category == 'Kids Wardrobe';
}

class CartLimits {
  CartLimits._();

  /// Shown when a non-subscribed user tries to mix wardrobe categories.
  static const String singleCategoryRestrictionMessage =
      'You can purchase products from only one wardrobe category at a time. '
      'Please complete or clear your current cart before selecting another category.';

  static const Map<int, int> maxGarmentsByKitDays = {
    1: 4,
    3: 8,
    5: 8,
    7: 10,
  };

  static int maxGarmentsForKit(int kitDays) =>
      maxGarmentsByKitDays[kitDays] ?? 4;

  static int wardrobeGarmentCount(CartState state) =>
      state.wardrobeItems.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Kit max, optionally capped by subscription remaining garments.
  /// Non-subscription / essentials flows keep the kit (or default) max only.
  static int effectiveMaxWardrobeGarments(CartState state) {
    final kitMax = state.maxWardrobeGarments;
    if (!CheckoutSession.instance.useSubscriptionBooking) return kitMax;

    final active = SubscriptionCache.instance.activeSubscription;
    final remaining = SubscriptionCache.instance.remainingGarmentsBalance;

    // New / unused subscription → never cap below the kit max from old usage.
    if (active != null &&
        active.maxGarments > 0 &&
        ((active.bookingsUsed != null && active.bookingsUsed! <= 0) ||
            (active.remainingBookings != null &&
                active.noOfBookings > 0 &&
                active.remainingBookings! >= active.noOfBookings))) {
      return kitMax;
    }

    if (remaining == null) return kitMax;
    if (remaining <= 0) return 0;
    return kitMax < remaining ? kitMax : remaining;
  }

  static int countAfterAdding(CartState state, CartItem item) {
    if (item.isEssential) return wardrobeGarmentCount(state);

    final existing = state.lineForProduct(
      item.productId,
      variantId: item.variantId,
    );
    if (existing != null) {
      return wardrobeGarmentCount(state) + 1;
    }
    return wardrobeGarmentCount(state) + item.quantity;
  }

  static bool wouldExceedWardrobeLimit(CartState state, CartItem item) {
    if (item.isEssential) return false;
    return countAfterAdding(state, item) > effectiveMaxWardrobeGarments(state);
  }

  /// Strict ACTIVE check for subscription booking only.
  static bool hasActiveSubscriptionCached() {
    final active = SubscriptionCache.instance.activeSubscription;
    if (active == null) return false;
    return active.planStatus.trim().toUpperCase() == 'ACTIVE';
  }

  /// Multi-category is allowed ONLY when booking with an ACTIVE subscription.
  /// "Continue without Subscription" always stays single-category, even if the
  /// user also has a subscription on file.
  static bool isExemptFromSingleCategoryRule() {
    return hasActiveSubscriptionCached() &&
        CheckoutSession.instance.useSubscriptionBooking;
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

  /// Non-sub / one-time booking: only one wardrobe category at a time.
  /// ACTIVE subscription + subscription booking path: unrestricted.
  static bool wouldViolateSingleCategoryRule(
    CartState state, {
    required String? incomingCategory,
    required bool isEssential,
  }) {
    if (isExemptFromSingleCategoryRule()) {
      _debug(
        'single-category ALLOW (exempt) incoming=$incomingCategory '
        'useSub=${CheckoutSession.instance.useSubscriptionBooking} '
        'hasActive=${hasActiveSubscriptionCached()}',
      );
      return false;
    }

    // Essentials / kids are not part of the wardrobe-category lock.
    if (isEssential || isEssentialCategory(incomingCategory)) return false;

    final locked = lockedWardrobeCategory(state);
    if (locked == null) {
      final hasContext = hasWardrobeLockContext(state);
      _debug(
        'single-category locked=null hasContext=$hasContext '
        'incoming=$incomingCategory items=${state.items.length}',
      );
      if (!hasContext) return false;

      final incoming = incomingCategory?.trim() ?? '';
      if (incoming.isEmpty) return false;

      // Same segment as an existing cart line → not a cross-segment attempt
      // (garment-limit dialog should apply instead).
      for (final item in state.items) {
        if (isEssentialCategory(item.category)) continue;
        if (categoriesMatch(incoming, item.category ?? '')) return false;
      }
      return true;
    }

    final incoming = incomingCategory?.trim() ?? '';
    if (incoming.isEmpty) return false;

    final violates = !categoriesMatch(incoming, locked);
    _debug(
      'single-category locked=$locked incoming=$incoming violates=$violates '
      'session=${CheckoutSession.instance.wardrobeCategory} '
      'stateCat=${state.wardrobeCategory} '
      'useSub=${CheckoutSession.instance.useSubscriptionBooking}',
    );
    return violates;
  }

  /// Home / booking entry guard: block opening a different wardrobe category.
  static bool wouldViolateCategorySelection(
    CartState state,
    String wardrobeCategory,
  ) {
    return wouldViolateSingleCategoryRule(
      state,
      incomingCategory: wardrobeCategory,
      isEssential: isEssentialCategory(wardrobeCategory),
    );
  }

  static void _debug(String message) {
    if (kDebugMode) {
      debugPrint('[CATEGORY_LOCK] $message');
    }
  }
}
