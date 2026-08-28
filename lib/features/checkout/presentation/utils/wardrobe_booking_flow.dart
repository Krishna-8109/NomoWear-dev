import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/cart/presentation/utils/cart_limits.dart';
import 'package:nomowear/features/cart/presentation/utils/cart_state_log.dart';
import 'package:nomowear/features/cart/presentation/widgets/wardrobe_limit_dialog.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/checkout/data/subscription_kit_preferences.dart';
import 'package:nomowear/features/checkout/data/wardrobe_booking_session.dart';
import 'package:nomowear/features/home/presentation/bloc/home_bloc.dart';
import 'package:nomowear/features/home/presentation/screens/subscription_tab_widget.dart';
import 'package:nomowear/features/products/data/models/product.dart';
import 'package:nomowear/features/products/data/product_catalog.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';
import 'package:nomowear/features/subscriptions/data/subscription_garment_balance.dart';
import 'package:nomowear/features/subscriptions/data/subscription_repository.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';

enum _WardrobeBookingChoice {
  takeSubscription,
  withoutSubscription,
  cancel,
}

class WardrobeBookingFlow {
  WardrobeBookingFlow._();

  static Future<void> handleHomeCategoryChoose(
    BuildContext context, {
    required String wardrobeCategory,
    String? wardrobeCategoryId,
    bool isKidsCard = false,
    bool isEssentialsCard = false,
  }) async {
    await _ensureSessionsRestored();
    if (!context.mounted) return;

    if (isKidsCard || isEssentialsCard) {
      // Kids & Essentials use device GPS — no saved address required.
      // Skip profile-completeness validation and go directly to buy flow.
      await _startBuyFlow(context, wardrobeCategory: wardrobeCategory);
      return;
    }

    if (!_canOpenWardrobeCategory(
      context,
      wardrobeCategory,
      categoryId: wardrobeCategoryId,
    )) {
      final cartState = context.read<CartBloc>().state;
      final currentCategory = CartLimits.lockedWardrobeCategory(cartState) ?? 'Another Category';
      await showSingleCategoryRestrictionDialog(
        context,
        currentCategory: currentCategory,
        requestedCategory: wardrobeCategory,
      );
      return;
    }

    await _startChooseFlow(
      context,
      wardrobeCategory: wardrobeCategory,
      wardrobeCategoryId: wardrobeCategoryId,
    );
  }

  static Future<void> handleHomeProductChoose(
    BuildContext context, {
    required Product product,
    required String wardrobeCategory,
    String? wardrobeCategoryId,
    required bool isKidsCard,
  }) async {
    await _ensureSessionsRestored();
    if (!context.mounted) return;

    if (isKidsCard || ProductCatalog.isDirectPurchaseProduct(product)) {
      final isValid = await _validateAddressOrShowDialog(context);
      if (!isValid) return;
      await _startBuyFlow(context, wardrobeCategory: wardrobeCategory);
      return;
    }

    if (!product.isWardrobeKit) {
      await _startBuyFlow(context, wardrobeCategory: wardrobeCategory);
      return;
    }

    if (!_canOpenWardrobeCategory(
      context,
      wardrobeCategory,
      categoryId: wardrobeCategoryId,
    )) {
      final cartState = context.read<CartBloc>().state;
      final currentCategory = CartLimits.lockedWardrobeCategory(cartState) ?? 'Another Category';
      await showSingleCategoryRestrictionDialog(
        context,
        currentCategory: currentCategory,
        requestedCategory: wardrobeCategory,
      );
      return;
    }

    await _startChooseFlow(
      context,
      wardrobeCategory: wardrobeCategory,
      wardrobeCategoryId: wardrobeCategoryId,
    );
  }

  static Future<void> openEssentialsFlow(BuildContext context) async {
    // Essentials uses device GPS — no saved address required.
    // Skip profile-completeness validation and go directly to buy flow.
    await _startBuyFlow(context, wardrobeCategory: 'Essentials Wardrobe');
  }

  /// Called after subscription plan purchase succeeds — continues to Wardrobe Kit.
  static Future<void> continueToWardrobeKitAfterSubscription(
    BuildContext context,
  ) async {
    await _ensureSessionsRestored();
    if (!context.mounted) return;

    final session = WardrobeBookingSession.instance;
    final category = session.wardrobeCategory?.trim();
    if (category == null || category.isEmpty) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.homeScreen,
        (route) => false,
      );
      return;
    }

    await session.markSubscriptionPurchased();
    if (!context.mounted) return;

    await _openWardrobeKitSetup(
      context,
      wardrobeCategory: category,
      wardrobeCategoryId: session.wardrobeCategoryId,
      useSubscriptionBooking: true,
    );
  }

  static Future<bool> _validateAddressOrShowDialog(BuildContext context) async {
    final customer = ProfileCache.instance.customer;
    final address = customer?.primaryAddress?.fullAddress?.trim();
    if (address != null && address.isNotEmpty) {
      return true;
    }

    if (!context.mounted) return false;
    
    bool goToAddress = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Profile Incomplete',
          style: CustomTextStyles.montserratBold.copyWith(
            fontSize: 18,
            color: AppColours.primary,
          ),
        ),
        content: Text(
          'Please fill profile and continue.',
          style: CustomTextStyles.openSansRegular.copyWith(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: CustomTextStyles.openSansSemiBold.copyWith(
                color: Colors.white54,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              goToAddress = true;
              Navigator.pop(ctx);
            },
            child: Text(
              'Edit Profile',
              style: CustomTextStyles.openSansSemiBold.copyWith(
                color: AppColours.primary,
              ),
            ),
          ),
        ],
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    if (goToAddress && context.mounted) {
      Navigator.pushNamed(context, AppRoutes.editProfileScreen);
    }

    return false;
  }

  static Future<void> _ensureSessionsRestored() async {
    await CheckoutSession.instance.restore();
    await WardrobeBookingSession.instance.restore();
  }

  static bool _canOpenWardrobeCategory(
    BuildContext context,
    String wardrobeCategory, {
    String? categoryId,
  }) {
    CartState cartState = const CartState();
    try {
      cartState = context.read<CartBloc>().state;
    } catch (_) {}

    return !CartLimits.wouldViolateCategorySelection(
      cartState,
      wardrobeCategory,
      categoryId: categoryId,
    );
  }

  // ─── BUY (purchase / essentials) — additive, never clears rental cart ───

  static Future<void> _startBuyFlow(
    BuildContext context, {
    required String wardrobeCategory,
  }) async {
    if (!context.mounted) return;

    final cartState = context.read<CartBloc>().state;
    logCartState('BUY entry', cartState);

    if (cartState.wardrobeItems.isEmpty) {
      await _clearCartIfBookingModeChanged(
        context,
        nextMode: CheckoutBookingMode.essentials,
      );
    }
    if (!context.mounted) return;

    if (cartState.wardrobeItems.isNotEmpty) {
      CheckoutSession.instance.setDelivery(
        useSubscriptionBooking: WardrobeBookingSession.instance.isSubscriptionPath,
        bookingMode: CheckoutBookingMode.subscription,
        wardrobeCategory: wardrobeCategory,
      );
    } else {
      CheckoutSession.instance.setDelivery(
        useSubscriptionBooking: false,
        bookingMode: CheckoutBookingMode.essentials,
        wardrobeCategory: wardrobeCategory,
      );
    }
    if (!context.mounted) return;

    Navigator.pushNamed(
      context,
      AppRoutes.wardrobeScreen,
      arguments: wardrobeCategory,
    );
  }

  // ─── CHOOSE (rental) ───

  static Future<void> _startChooseFlow(
    BuildContext context, {
    required String wardrobeCategory,
    String? wardrobeCategoryId,
  }) async {
    if (!context.mounted) return;

    final session = WardrobeBookingSession.instance;
    CartState cartState = const CartState();
    try {
      cartState = context.read<CartBloc>().state;
    } catch (_) {}
    session.logChooseDecision(cartState);

    try {
      await SubscriptionRepository().getActiveSubscription(forceRefresh: true);
    } catch (_) {}
    if (!context.mounted) return;

    if (cartState.status == CartStatus.loaded && cartState.wardrobeItems.isEmpty) {
      final isNonSubPath = session.isWithoutSubscriptionPath ||
          CheckoutSession.instance.continueWithoutMembership;

      if (!isNonSubPath) {
        // Normal case: empty cart on subscription path — clear stale state.
        if (kDebugMode) {
          debugPrint('[CHOOSE] Cart empty (sub path) — clearing stale booking selection');
        }
        CheckoutSession.instance.clearBookingModeSelection();
        await session.startNewBooking();
      } else if (!session.kitSelected) {
        // ─── CASE A ───────────────────────────────────────────────────────────
        // User just tapped "Continue Without Membership" and came back to Home
        // without selecting a kit yet.  Cart is empty but the non-sub mode is
        // still intentional — keep it so _startChooseFlow skips the path dialog
        // and goes straight to the Kit screen.
        if (kDebugMode) {
          debugPrint(
            '[CHOOSE] Cart empty, continueWithoutMembership=true, kitSelected=false '
            '— preserving non-sub mode for Kit screen',
          );
        }
        // No-op: continueWithoutMembership + withoutSubscription path remain set.
      } else {
        // ─── CASE B ───────────────────────────────────────────────────────────
        // User completed a full non-sub flow (selected kit + garments) and then
        // cleared ALL cart items.  This is a deliberate full reset.
        // Treat the next category selection as a brand-new flow and evaluate the
        // user's current subscription / booking entitlement from scratch.
        if (kDebugMode) {
          final hasSub = SubscriptionCache.instance.activeSubscription != null;
          debugPrint(
            '[CART_CLEAR] cartItems=0\n'
            '  hasActiveSubscription=$hasSub\n'
            '  currentSelectionMode=reset_for_new_flow\n'
            '  Reason: kitSelected=true + wardrobeItems.isEmpty → full session reset',
          );
        }
        await WardrobeBookingSession.instance.startNewBooking();
        CheckoutSession.instance.setDelivery(
          continueWithoutMembership: false,
          bookingMode: CheckoutBookingMode.unset,
          useSubscriptionBooking: false,
        );
        CheckoutSession.instance.clearWardrobeCategoryLock();
      }
    }

    logBookingLimitCheck();
    final continuingPaidRental =
        CheckoutSession.instance.continueWithoutMembership;
    if (kDebugMode) {
      debugPrint(
        '[SUBSCRIPTION_FLOW] CHOOSE_ENTRY '
        'continueWithoutMembership=$continuingPaidRental '
        'useSubscriptionBooking=${CheckoutSession.instance.useSubscriptionBooking} '
        'bookingMode=${CheckoutSession.instance.bookingMode.name} '
        'sessionPath=${session.selectedPath.name} '
        'backendSubscriptionStatus=${SubscriptionCache.instance.activeSubscription?.planStatus ?? "null"}',
      );
    }

    if (!continuingPaidRental &&
        CartLimits.isSubscriptionBookingLimitExhausted()) {
      logAddToCartLimitResult('BOOKING_LIMIT_REACHED');
      await showUnlockFullAccessDialog(
        context,
        onContinueWithoutMembership: () async {
          if (!context.mounted) return;
          CheckoutSession.instance.clearWardrobeCategoryLock();
          await WardrobeBookingSession.instance.beginPaidRentalContinuation();
          if (!context.mounted) return;
          await _openWardrobeKitSetup(
            context,
            wardrobeCategory: wardrobeCategory,
            wardrobeCategoryId: wardrobeCategoryId,
            useSubscriptionBooking: false,
            preserveContinueWithoutMembership: true,
          );
        },
      );
      return;
    }

    if (continuingPaidRental) {
      if (kDebugMode) {
        debugPrint('[CHOOSE] continueWithoutMembership → Wardrobe Kit');
      }
      await _openWardrobeKitSetup(
        context,
        wardrobeCategory: wardrobeCategory,
        wardrobeCategoryId: wardrobeCategoryId,
        useSubscriptionBooking: false,
        preserveContinueWithoutMembership: true,
      );
      return;
    }

    if (session.shouldContinueToProducts) {
      if (kDebugMode) {
        debugPrint('[CHOOSE] → Products');
      }
      await _continueActiveBooking(
        context,
        wardrobeCategory: wardrobeCategory,
        wardrobeCategoryId: wardrobeCategoryId,
      );
      return;
    }

    if (session.isClosed) {
      await session.startNewBooking();
      if (!context.mounted) return;
    }

    final hasActiveSubscription = await _hasActiveSubscription();
    if (!context.mounted) return;

    final subGarmentBalance = SubscriptionGarmentBalance.cachedRemaining;
    if (kDebugMode) {
      debugPrint(
        '[WARDROBE_FLOW] Starting new category flow\n'
        '  hasActiveSubscription=$hasActiveSubscription\n'
        '  remainingGarments=$subGarmentBalance\n'
        '  selectionMode=freshly_determined (evaluating subscription now)',
      );
    }

    final choice = await _showPathSelectionDialog(
      context,
      hasActiveSubscription: hasActiveSubscription,
    );
    if (!context.mounted || choice == _WardrobeBookingChoice.cancel) return;

    switch (choice) {
      case _WardrobeBookingChoice.takeSubscription:
        if (hasActiveSubscription) {
          await _onWithSubscription(
            context,
            wardrobeCategory,
            wardrobeCategoryId,
          );
        } else {
          await _onTakeSubscription(
            context,
            wardrobeCategory,
            wardrobeCategoryId,
          );
        }
      case _WardrobeBookingChoice.withoutSubscription:
        await _onContinueWithoutSubscription(
          context,
          wardrobeCategory,
          wardrobeCategoryId,
        );
      case _WardrobeBookingChoice.cancel:
        break;
    }
  }

  static Future<void> _onTakeSubscription(
    BuildContext context,
    String wardrobeCategory,
    String? wardrobeCategoryId,
  ) async {
    await WardrobeBookingSession.instance.selectPath(
      path: WardrobeBookingPath.subscription,
      wardrobeCategory: wardrobeCategory,
      wardrobeCategoryId: wardrobeCategoryId,
      needsSubscriptionPurchase: true,
    );
    if (!context.mounted) return;
    _openSubscriptionPlans(context);
  }

  static Future<void> _onWithSubscription(
    BuildContext context,
    String wardrobeCategory,
    String? wardrobeCategoryId,
  ) async {
    try {
      await SubscriptionRepository().getActiveSubscription(forceRefresh: true);
    } catch (_) {}
    if (!context.mounted) return;

    logBookingLimitCheck();
    if (CartLimits.isSubscriptionBookingLimitExhausted()) {
      logLimitDialog('SUBSCRIPTION_BOOKING_LIMIT');
      await showUnlockFullAccessDialog(
        context,
        onContinueWithoutMembership: () async {
          if (!context.mounted) return;
          CheckoutSession.instance.clearWardrobeCategoryLock();
          await WardrobeBookingSession.instance.beginPaidRentalContinuation();
          if (!context.mounted) return;
          await _openWardrobeKitSetup(
            context,
            wardrobeCategory: wardrobeCategory,
            wardrobeCategoryId: wardrobeCategoryId,
            useSubscriptionBooking: false,
            preserveContinueWithoutMembership: true,
          );
        },
      );
      return;
    }

    await WardrobeBookingSession.instance.selectPath(
      path: WardrobeBookingPath.subscription,
      wardrobeCategory: wardrobeCategory,
      wardrobeCategoryId: wardrobeCategoryId,
      needsSubscriptionPurchase: false,
    );
    if (!context.mounted) return;

    await _openWardrobeKitSetup(
      context,
      wardrobeCategory: wardrobeCategory,
      wardrobeCategoryId: wardrobeCategoryId,
      useSubscriptionBooking: true,
    );
  }

  static Future<void> _onContinueWithoutSubscription(
    BuildContext context,
    String wardrobeCategory,
    String? wardrobeCategoryId,
  ) async {
    await WardrobeBookingSession.instance.selectPath(
      path: WardrobeBookingPath.withoutSubscription,
      wardrobeCategory: wardrobeCategory,
      wardrobeCategoryId: wardrobeCategoryId,
      needsSubscriptionPurchase: false,
    );
    CheckoutSession.instance.lockNonSubWardrobeCategory(
      wardrobeCategory,
      categoryId: wardrobeCategoryId,
    );
    if (!context.mounted) return;

    await _openWardrobeKitSetup(
      context,
      wardrobeCategory: wardrobeCategory,
      wardrobeCategoryId: wardrobeCategoryId,
      useSubscriptionBooking: false,
    );
  }

  static Future<void> _continueActiveBooking(
    BuildContext context, {
    required String wardrobeCategory,
    String? wardrobeCategoryId,
  }) async {
    final session = WardrobeBookingSession.instance;
    if (session.isWithoutSubscriptionPath) {
      CheckoutSession.instance.lockNonSubWardrobeCategory(
        wardrobeCategory,
        categoryId: wardrobeCategoryId ??
            CheckoutSession.instance.activeNonSubscriptionCategoryId,
      );
    } else {
      CheckoutSession.instance.setDelivery(
        useSubscriptionBooking: true,
        bookingMode: CheckoutBookingMode.subscription,
        wardrobeCategory: wardrobeCategory,
      );
    }

    await _restoreKitToSessionAndCart(context);
    if (!context.mounted) return;

    if (kDebugMode) {
      final cart = context.read<CartBloc>().state;
      debugPrint(
        '[PRODUCT_LIMIT] kitLimit=${cart.currentKitLimit} '
        'currentBookingSelectedGarments=${cart.currentBookingSelectedGarments} '
        'currentBookingRemaining=${cart.currentBookingRemaining} '
        'subRemaining=${CartLimits.subscriptionRemainingEntitlement()}',
      );
      logSubscriptionCartCount(cart);
    }

    Navigator.pushNamed(
      context,
      AppRoutes.wardrobeScreen,
      arguments: wardrobeCategory,
    );
  }

  static Future<void> _restoreKitToSessionAndCart(BuildContext context) async {
    final cart = context.read<CartBloc>().state;
    if (cart.wardrobeKitId?.trim().isNotEmpty ?? false) return;

    await SubscriptionKitPreferences.instance.restore();
    final prefs = SubscriptionKitPreferences.instance;
    if (!prefs.isKitConfigured || prefs.wardrobeKitId == null) return;
    if (!context.mounted) return;

    CheckoutSession.instance.setDelivery(
      addressId: prefs.addressId,
      addressTitle: prefs.addressTitle,
      addressLines: prefs.addressLines,
      deliveryDate: prefs.deliveryDateEpochMs != null
          ? DateTime.fromMillisecondsSinceEpoch(prefs.deliveryDateEpochMs!)
          : null,
      deliveryTime: prefs.deliveryTime,
      gender: prefs.gender,
      kitType: prefs.kitType,
      wardrobeCategory: prefs.wardrobeCategory,
    );

    context.read<CartBloc>().add(
          SetWardrobeKitEvent(
            kitId: prefs.wardrobeKitId!,
            wardrobeKitProductId: prefs.wardrobeKitProductId,
            kitDays: prefs.wardrobeKitDays,
            kitName: prefs.wardrobeKitName,
            maxGarments: prefs.wardrobeKitMaxGarments,
            kitPrice: prefs.wardrobeKitPrice ?? '',
            wardrobeCategory: prefs.wardrobeCategory,
            wardrobeCategoryId:
                CheckoutSession.instance.activeNonSubscriptionCategoryId,
          ),
        );
  }

  static Future<void> _openWardrobeKitSetup(
    BuildContext context, {
    required String wardrobeCategory,
    required bool useSubscriptionBooking,
    String? wardrobeCategoryId,
    bool preserveContinueWithoutMembership = false,
  }) async {
    if (!context.mounted) return;

    final nextMode = useSubscriptionBooking
        ? CheckoutBookingMode.subscription
        : CheckoutBookingMode.oneTimeWardrobe;

    if (!preserveContinueWithoutMembership) {
      await _clearCartIfBookingModeChanged(context, nextMode: nextMode);
      if (!context.mounted) return;
    }

    final keepContinueWithout =
        preserveContinueWithoutMembership ||
            CheckoutSession.instance.continueWithoutMembership;

    if (keepContinueWithout) {
      await WardrobeBookingSession.instance.setContinuationCategory(
        wardrobeCategory: wardrobeCategory,
        wardrobeCategoryId: wardrobeCategoryId,
      );
      if (!context.mounted) return;
    }

    CheckoutSession.instance.setDelivery(
      useSubscriptionBooking: useSubscriptionBooking,
      continueWithoutMembership: keepContinueWithout,
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

  static Future<bool> _hasActiveSubscription() async {
    try {
      final active = await SubscriptionRepository().getActiveSubscription(
        forceRefresh: true,
      );
      return active != null && active.isActive;
    } catch (_) {
      return false;
    }
  }

  static void _openSubscriptionPlans(BuildContext context) {
    try {
      context.read<HomeBloc>().add(
            ChangeBottomNavEvent(SubscriptionTabWidget.subscriptionTabIndex),
          );
    } catch (_) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.homeScreen,
        (route) => false,
        arguments: SubscriptionTabWidget.subscriptionTabIndex,
      );
    }
  }

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

    if (_shouldPreserveCartOnModeChange(snapshot, nextMode)) {
      if (kDebugMode) {
        debugPrint(
          '[BOOKING_FLOW] preserve cart — nextMode=$nextMode '
          'items=${snapshot.items.length}',
        );
      }
      return;
    }

    final previousMode = _resolvePreviousBookingMode(snapshot);

    if (previousMode == nextMode) return;
    if (previousMode == CheckoutBookingMode.unset && snapshot.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
        '[BOOKING_FLOW] clearing cart only — '
        'from $previousMode to $nextMode items=${snapshot.items.length}',
      );
    }

    cartBloc?.add(ClearCartEvent());
  }

  static bool _shouldPreserveCartOnModeChange(
    CartState snapshot,
    CheckoutBookingMode nextMode,
  ) {
    if (snapshot.isEmpty) return false;
    if (nextMode == CheckoutBookingMode.essentials) {
      return snapshot.wardrobeItems.isNotEmpty;
    }
    if (nextMode == CheckoutBookingMode.subscription ||
        nextMode == CheckoutBookingMode.oneTimeWardrobe) {
      return snapshot.essentialItems.isNotEmpty ||
          snapshot.paidRentalGarmentItems.isNotEmpty ||
          snapshot.subscriptionGarmentItems.isNotEmpty;
    }
    return false;
  }

  static CheckoutBookingMode _resolvePreviousBookingMode(CartState snapshot) {
    final stored = CheckoutSession.instance.bookingMode;
    if (stored != CheckoutBookingMode.unset) return stored;

    if (WardrobeBookingSession.instance.isSubscriptionPath) {
      return CheckoutBookingMode.subscription;
    }
    if (WardrobeBookingSession.instance.isWithoutSubscriptionPath) {
      return CheckoutBookingMode.oneTimeWardrobe;
    }

    final hasEssentials = snapshot.essentialItems.isNotEmpty;
    final hasWardrobe = snapshot.wardrobeItems.isNotEmpty;
    if (hasEssentials && !hasWardrobe) return CheckoutBookingMode.essentials;
    if (hasWardrobe) return CheckoutBookingMode.oneTimeWardrobe;

    return CheckoutBookingMode.unset;
  }

  static Future<_WardrobeBookingChoice> _showPathSelectionDialog(
    BuildContext context, {
    required bool hasActiveSubscription,
  }) async {
    final firstLabel =
        hasActiveSubscription ? 'Membership Booking' : 'Choose Subscription';
    if (kDebugMode) {
      debugPrint(
        '[CHOOSE] hasActiveSubscription=$hasActiveSubscription '
        '→ Show "$firstLabel"',
      );
    }

    final result = await showDialog<_WardrobeBookingChoice>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: _BookingDialogShell(
            title: 'How would you like to book?',
            message: hasActiveSubscription
                ? 'Book with your active subscription, or continue as a paid rental.'
                : 'Take a subscription for included garments, or continue with a one-time paid rental.',
            actions: [
              _BookingDialogAction(
                label: firstLabel,
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _WardrobeBookingChoice.takeSubscription,
                ),
              ),
              _BookingDialogAction(
                label: 'Continue Without Subscription',
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
        border: Border.all(color: const Color(0xFFE6C279), width: 1),
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
              colors: [Color(0xFFE6C27A), Color(0xFFD9B35F)],
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
