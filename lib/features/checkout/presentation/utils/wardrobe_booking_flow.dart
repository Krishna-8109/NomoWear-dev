import 'package:flutter/foundation.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/features/cart/data/cart_repository.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/cart/presentation/utils/cart_limits.dart';
import 'package:nomowear/features/cart/presentation/widgets/wardrobe_limit_dialog.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/products/data/models/product.dart';
import 'package:nomowear/features/products/data/product_catalog.dart';
import 'package:nomowear/features/subscriptions/data/subscription_garment_balance.dart';

enum _WardrobeBookingChoice {
  subscription,
  withoutSubscription,
  cancel,
}

class WardrobeBookingFlow {
  WardrobeBookingFlow._();

  /// Entry point for home-screen CHOOSE / BUY="BUY" actions.
  static Future<void> handleHomeProductChoose(
    BuildContext context, {
    required Product product,
    required String wardrobeCategory,
    required bool isKidsCard,
  }) async {
    await CheckoutSession.instance.restore();
    if (!context.mounted) return;

    // Show "One category only" on CHOOSE when cart already has another
    // wardrobe category (non-sub / one-time booking path).
    if (!_canOpenWardrobeCategory(context, wardrobeCategory)) {
      await showSingleCategoryRestrictionDialog(context);
      return;
    }

    if (isKidsCard || ProductCatalog.isDirectPurchaseProduct(product)) {
      await _startSingleItemFlow(context, wardrobeCategory: wardrobeCategory);
      return;
    }

    if (!product.isWardrobeKit) {
      await _startSingleItemFlow(context, wardrobeCategory: wardrobeCategory);
      return;
    }

    await _startWardrobeKitFlow(
      context,
      wardrobeCategory: wardrobeCategory,
    );
  }

  /// Returns false when a non-subscriber already locked a different wardrobe category.
  static bool _canOpenWardrobeCategory(
    BuildContext context,
    String wardrobeCategory,
  ) {
    // Session lock is source-of-truth even if CartBloc read fails.
    CartState cartState = const CartState();
    try {
      cartState = context.read<CartBloc>().state;
    } catch (_) {}

    final allowed = !CartLimits.wouldViolateCategorySelection(
      cartState,
      wardrobeCategory,
    );
    if (kDebugMode) {
      debugPrint(
        '[CATEGORY_LOCK] canOpen=$allowed '
        'incoming=$wardrobeCategory '
        'locked=${CartLimits.lockedWardrobeCategory(cartState)} '
        'session=${CheckoutSession.instance.wardrobeCategory} '
        'stateCat=${cartState.wardrobeCategory} '
        'useSub=${CheckoutSession.instance.useSubscriptionBooking} '
        'exempt=${CartLimits.isExemptFromSingleCategoryRule()}',
      );
    }
    return allowed;
  }

  static Future<void> _startSingleItemFlow(
    BuildContext context, {
    required String wardrobeCategory,
  }) async {
    // Kids / direct-purchase share the essentials cart lane (not kit booking).
    await _clearCartIfBookingModeChanged(
      context,
      nextMode: CheckoutBookingMode.essentials,
    );
    if (!context.mounted) return;

    // Remember category for checkout UI; hard lock happens on first add-to-cart.
    CheckoutSession.instance.setDelivery(
      useSubscriptionBooking: false,
      bookingMode: CheckoutBookingMode.essentials,
      wardrobeCategory: wardrobeCategory,
    );
    if (!context.mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.wardrobeScreen,
      arguments: wardrobeCategory,
    );
  }

  /// Home Essentials banner — isolated from subscription / one-time kit carts.
  static Future<void> openEssentialsFlow(BuildContext context) async {
    await CheckoutSession.instance.restore();
    if (!context.mounted) return;

    await _clearCartIfBookingModeChanged(
      context,
      nextMode: CheckoutBookingMode.essentials,
    );
    if (!context.mounted) return;

    CheckoutSession.instance.setDelivery(
      useSubscriptionBooking: false,
      bookingMode: CheckoutBookingMode.essentials,
      wardrobeCategory: 'Essentials Wardrobe',
    );
    if (!context.mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.wardrobeScreen,
      arguments: 'Essentials Wardrobe',
    );
  }

  static Future<void> _startWardrobeKitFlow(
    BuildContext context, {
    required String wardrobeCategory,
  }) async {
    final choice = await _showWardrobeBookingChoiceDialog(context);
    if (!context.mounted || choice == _WardrobeBookingChoice.cancel) return;

    switch (choice) {
      case _WardrobeBookingChoice.subscription:
        await _handleSubscriptionPath(context, wardrobeCategory);
      case _WardrobeBookingChoice.withoutSubscription:
        await _openWardrobeKitSetup(
          context,
          wardrobeCategory: wardrobeCategory,
          useSubscriptionBooking: false,
        );
      case _WardrobeBookingChoice.cancel:
        break;
    }
  }

  static Future<void> _handleSubscriptionPath(
    BuildContext context,
    String wardrobeCategory,
  ) async {
    // Prefetch remaining garment balance so cart validation is ready after kit NEXT.
    await SubscriptionGarmentBalance.resolveAndCache(forceRefresh: true);
    if (!context.mounted) return;

    // Always open the wardrobe kit (screenshot) screen directly — do not send
    // the user back to Home / Subscription tab first. Checkout still verifies
    // subscription eligibility before placing the order.
    await _openWardrobeKitSetup(
      context,
      wardrobeCategory: wardrobeCategory,
      useSubscriptionBooking: true,
    );
  }

  static Future<void> _openWardrobeKitSetup(
    BuildContext context, {
    required String wardrobeCategory,
    required bool useSubscriptionBooking,
  }) async {
    await CheckoutSession.instance.restore();
    if (!context.mounted) return;

    final nextMode = useSubscriptionBooking
        ? CheckoutBookingMode.subscription
        : CheckoutBookingMode.oneTimeWardrobe;

    // Switching Subscription ↔ Non-Subscription ↔ Essentials drops the other
    // flow's cart. Same-flow re-entry keeps the cart.
    await _clearCartIfBookingModeChanged(context, nextMode: nextMode);
    if (!context.mounted) return;

    CheckoutSession.instance.setDelivery(
      useSubscriptionBooking: useSubscriptionBooking,
      bookingMode: nextMode,
      wardrobeCategory: wardrobeCategory,
    );
    if (!context.mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.screenshotScreen,
      arguments: wardrobeCategory,
    );
  }

  /// Clears local + remote cart when the user switches booking mode.
  static Future<void> _clearCartIfBookingModeChanged(
    BuildContext context, {
    required CheckoutBookingMode nextMode,
  }) async {
    CartBloc? cartBloc;
    CartState snapshot = const CartState();
    try {
      cartBloc = context.read<CartBloc>();
      snapshot = cartBloc.state;
    } catch (_) {}

    final previousMode = _resolvePreviousBookingMode(snapshot);

    if (previousMode == nextMode) {
      if (kDebugMode) {
        debugPrint(
          '[BOOKING_FLOW] same mode ($nextMode) — keep cart',
        );
      }
      return;
    }

    // First entry into a mode with an empty cart — just adopt the mode.
    if (previousMode == CheckoutBookingMode.unset && snapshot.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[BOOKING_FLOW] unset → $nextMode with empty cart — keep',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[BOOKING_FLOW] mode switch '
        'from $previousMode to $nextMode '
        'items=${snapshot.items.length} — clear cart',
      );
    }

    // Reset kit / category / subscription booking flags for the new flow.
    CheckoutSession.instance.clear();

    cartBloc?.add(ClearLocalCartEvent());

    // Always clear remote too — local cart may be empty after app restart
    // while the server still holds the other flow's items.
    try {
      await CartRepository().clearRemoteCart(
        snapshot.items.isNotEmpty ? snapshot : const CartState(),
      );
    } catch (_) {
      // Local cart is already cleared; remote can retry on next sync.
    }
  }

  /// Prefers persisted [CheckoutBookingMode]; falls back to cart contents for
  /// older sessions that only had `useSubscriptionBooking`.
  static CheckoutBookingMode _resolvePreviousBookingMode(CartState snapshot) {
    final stored = CheckoutSession.instance.bookingMode;
    if (stored != CheckoutBookingMode.unset) return stored;

    if (CheckoutSession.instance.useSubscriptionBooking) {
      return CheckoutBookingMode.subscription;
    }

    final hasEssentials = snapshot.essentialItems.isNotEmpty;
    final hasWardrobe = snapshot.wardrobeItems.isNotEmpty;
    if (hasEssentials && !hasWardrobe) {
      return CheckoutBookingMode.essentials;
    }
    if (hasWardrobe) {
      return CheckoutBookingMode.oneTimeWardrobe;
    }

    final category =
        (CheckoutSession.instance.wardrobeCategory ?? '').toLowerCase();
    if (category.contains('essential') || category.contains('kids')) {
      return CheckoutBookingMode.essentials;
    }

    return CheckoutBookingMode.unset;
  }

  static Future<_WardrobeBookingChoice> _showWardrobeBookingChoiceDialog(
    BuildContext context,
  ) async {
    final result = await showDialog<_WardrobeBookingChoice>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: _BookingDialogShell(
            title: 'How would you like to book?',
            message:
                'Use your active subscription or continue with a one-time paid booking.',
            actions: [
              _BookingDialogAction(
                label: 'Continue with Subscription',
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _WardrobeBookingChoice.subscription,
                ),
              ),
              _BookingDialogAction(
                label: 'Continue without Subscription',
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _WardrobeBookingChoice.withoutSubscription,
                ),
              ),
              _BookingDialogAction(
                label: 'Cancel',
                isSecondary: true,
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _WardrobeBookingChoice.cancel,
                ),
              ),
            ],
          ),
        );
      },
    );

    return result ?? _WardrobeBookingChoice.cancel;
  }
}

class _BookingDialogShell extends StatelessWidget {
  const _BookingDialogShell({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<_BookingDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: const Color(0xFF050816),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE6C279).withOpacity(0.35),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE6C279),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 20,
              color: AppColours.primary,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 24.h),
          ...actions.map(
            (action) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: action,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingDialogAction extends StatelessWidget {
  const _BookingDialogAction({
    required this.label,
    required this.onPressed,
    this.isSecondary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    if (isSecondary) {
      return TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: CustomTextStyles.openSansSemiBold.copyWith(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.maxFinite,
      height: 44.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE6C27A),
                Color(0xFFD9B35F),
              ],
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 13.fSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
