import 'package:flutter/foundation.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/cart/presentation/utils/cart_limits.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/checkout/data/wardrobe_booking_session.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';

/// Temporary runtime diagnostics for mixed-cart / subscription flows.
void logCartState(String tag, CartState state, {String? extra}) {
  if (!kDebugMode) return;
  final session = CheckoutSession.instance;
  final subRemaining = SubscriptionCache.instance.remainingGarmentsBalance;
  debugPrint(
    '[CART:$tag] total=${state.items.length} '
    'subscription=${state.subscriptionGarmentCount} '
    'paidRental=${state.paidRentalGarmentCount} '
    'purchase=${state.essentialItems.fold<int>(0, (s, i) => s + i.quantity)} '
    'useSub=${session.useSubscriptionBooking} '
    'continueWithout=${session.continueWithoutMembership} '
    'bookingMode=${session.bookingMode.name} '
    'subRemaining=$subRemaining'
    '${extra != null ? ' $extra' : ''}',
  );
}

/// Derived from live cart lines only — never a separate increment/decrement.
void logSubscriptionCartCount(CartState state) {
  if (!kDebugMode) return;
  final subItems = state.subscriptionGarmentItems;
  debugPrint(
    '[SUB_CART_COUNT]\n'
    'totalCartItems=${state.items.length}\n'
    'subscriptionCartItems=${subItems.length}\n'
    'subscriptionQuantities=${subItems.map((e) => e.quantity).toList()}\n'
    'currentBookingSelectedGarments=${state.currentBookingSelectedGarments}\n'
    'currentKitLimit=${state.currentKitLimit}\n'
    'currentBookingRemaining=${state.currentBookingRemaining}',
  );
}

void logGarmentLimitCheck(CartState state) {
  if (!kDebugMode) return;
  debugPrint(
    '[GARMENT_LIMIT_CHECK]\n'
    'currentBookingSelected=${CartLimits.currentBookingSelectedGarments(state)}\n'
    'currentKitGarmentLimit=${CartLimits.currentKitGarmentLimit(state)}\n'
    'currentKitRemaining=${CartLimits.currentKitRemainingGarments(state)}',
  );
}

void logBookingLimitCheck() {
  if (!kDebugMode) return;
  debugPrint(
    '[BOOKING_LIMIT_CHECK]\n'
    'subscriptionTotalBookings=${CartLimits.subscriptionTotalBookings()}\n'
    'subscriptionUsedBookings=${CartLimits.subscriptionUsedBookings()}\n'
    'subscriptionRemainingBookings=${CartLimits.subscriptionRemainingBookings()}',
  );
}

void logLimitDialog(String reason) {
  if (!kDebugMode) return;
  debugPrint('[LIMIT_DIALOG]\nreason=$reason');
}

void logAddToCartLimitDebug(CartState state) {
  if (!kDebugMode) return;
  final active = SubscriptionCache.instance.activeSubscription;
  debugPrint(
    '[ADD_TO_CART_LIMIT_DEBUG]\n'
    'subscriptionId=${active?.id}\n'
    'subscriptionStatus=${active?.planStatus}\n'
    'totalBookings=${active?.noOfBookings}\n'
    'usedBookings=${active?.bookingsUsed}\n'
    'remainingBookings=${active?.remainingBookings}\n'
    'totalGarments=${active?.maxGarments}\n'
    'usedGarments=${active?.usedGarments}\n'
    'remainingGarments=${active?.remainingGarments}\n'
    'currentKit=${state.wardrobeKitTitle}\n'
    'currentKitLimit=${CartLimits.currentKitGarmentLimit(state)}\n'
    'currentCartSubscriptionGarments=${state.subscriptionGarmentCount}\n'
    'currentCartWardrobeGarments=${CartLimits.currentBookingSelectedGarments(state)}\n'
    'bookingLimitExhausted=${active?.isBookingLimitExhausted}\n'
    'continueWithout=${CheckoutSession.instance.continueWithoutMembership}\n'
    'subscriptionPath=${WardrobeBookingSession.instance.isSubscriptionPath}\n'
    'shouldContinueToProducts=${WardrobeBookingSession.instance.shouldContinueToProducts}',
  );
}

void logMixedCart(CartState state) {
  if (!kDebugMode) return;
  debugPrint(
    '[MIXED_CART]\n'
    'subscriptionItems=${state.subscriptionGarmentCount}\n'
    'nonSubscriptionItems=${state.paidRentalGarmentCount}\n'
    'purchaseItems=${state.essentialItems.fold<int>(0, (s, i) => s + i.quantity)}',
  );
  for (final item in state.items) {
    debugPrint(
      '[MIXED_CART_ITEM]\n'
      'productId=${item.productId}\n'
      'isSubscriptionGarment=${item.isSubscriptionGarment}\n'
      'isEssential=${item.isEssential}\n'
      'categoryId=${item.category}',
    );
  }
}

void logAddToCartLimitResult(String reason) {
  if (!kDebugMode) return;
  debugPrint('[ADD_TO_CART_LIMIT_RESULT]\nreason=$reason');
}

void logSubCartLimit(CartState state, CartItem incoming) {
  if (!kDebugMode) return;
  final count = CartLimits.currentSubscriptionCartGarmentCount(state);
  final limit = CartLimits.currentSubscriptionBookingLimit(state);
  final backendRemaining =
      SubscriptionCache.instance.remainingGarmentsBalance ??
          SubscriptionCache.instance.activeSubscription?.remainingGarments;
  final paymentCompleted = WardrobeBookingSession.instance.paymentCompleted;
  final wouldExceed =
      CartLimits.wouldExceedUnpaidSubscriptionCartLimit(state, incoming);
  debugPrint(
    '[SUB_CART_LIMIT]\n'
    'subscriptionCartGarmentCount=$count\n'
    'subscriptionBookingLimit=$limit\n'
    'backendRemainingGarments=$backendRemaining\n'
    'paymentCompleted=$paymentCompleted\n'
    'canAdd=${!wouldExceed}',
  );
}

void logSubCartLimitResult(String reason, String dialog) {
  if (!kDebugMode) return;
  debugPrint(
    '[SUB_CART_LIMIT]\n'
    'reason=$reason\n'
    'dialog=$dialog',
  );
}
