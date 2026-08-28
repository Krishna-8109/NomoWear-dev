import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomowear/features/banners/data/banner_cache.dart';

import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/checkout/data/subscription_kit_preferences.dart';
import 'package:nomowear/features/checkout/data/wardrobe_booking_session.dart';
import 'package:nomowear/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:nomowear/features/orders/data/orders_cache.dart';
import 'package:nomowear/features/orders/data/pending_return_store.dart';
import 'package:nomowear/features/plans/data/plan_cache.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/domain/saved_address.dart';
import 'package:nomowear/features/profile/domain/user_order.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central wipe for auth tokens and all user-scoped local state.
///
/// Use this on:
/// - Logout
/// - Account deletion
/// - App version / build change (new APK over existing install)
/// - Invalid session (e.g. 401 at splash)
///
/// Intentionally keeps [persistedVersionKey] so version gating still works
/// after a wipe. No language/theme/onboarding prefs exist in this app yet.
class SessionCleanup {
  SessionCleanup._();

  /// SharedPreferences key for last-seen app version+build (must survive wipe).
  static const String persistedVersionKey = 'app_installed_version';

  // Auth keys mirrored from AuthStorage — kept here so wipe is complete even
  // if AuthStorage.clear() is not the entry point.
  static const String _customerIdKey = 'auth_customer_id';
  static const String _userTokenKey = 'auth_user_token';
  static const String _authTokenKey = 'auth_token';
  static const String _mobileKey = 'auth_mobile';
  static const String _profileCompleteKey = 'profile_complete';

  /// Clears auth prefs, in-memory caches/singletons, and Flutter image cache.
  /// Does **not** reset app-scoped Blocs (needs [BuildContext] — see [resetAppBlocs]).
  static Future<void> clearUserSession() async {
    // 1) In-memory API / profile caches (singletons survive logout otherwise).
    ProfileCache.instance.clear();
    ProductCache.instance.clear();
    BannerCache.instance.clear();
    PlanCache.instance.clear();
    SubscriptionCache.instance.clear();
    OrdersCache.instance.clear();

    // 2) Checkout draft and booking session for previous user.
    CheckoutSession.instance.clear();
    await WardrobeBookingSession.instance.resetForNewBooking();
    await SubscriptionKitPreferences.instance.clear();

    // 3) Global lists used by My Orders / My Addresses screens.
    userOrdersList.clear();
    userSavedAddresses.clear();
    await PendingReturnStore.instance.clearAll();

    // 4) Persisted auth / profile-complete flags. Keep [persistedVersionKey].
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customerIdKey);
    await prefs.remove(_userTokenKey);
    await prefs.remove(_authTokenKey);
    await prefs.remove(_mobileKey);
    await prefs.remove(_profileCompleteKey);
    await prefs.remove('auth_profile_data');

    // 5) Decoded network images that may still show previous user's products.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Resets root [CartBloc] / [FavoritesBloc] so UI never shows previous user data.
  /// Local-only — does not call cart/wishlist APIs (token may already be gone).
  static void resetAppBlocs(BuildContext context) {
    try {
      context.read<CartBloc>().add(ClearLocalCartEvent());
    } catch (_) {
      // Provider may be unavailable in some tests / early teardown.
    }
    try {
      context.read<FavoritesBloc>().add(ClearFavoritesEvent());
    } catch (_) {
      // Same as above.
    }
  }

  /// Full local wipe + Bloc reset. Prefer this from Profile logout/delete UI.
  static Future<void> clearUserSessionAndBlocs(BuildContext context) async {
    await clearUserSession();
    if (context.mounted) {
      resetAppBlocs(context);
    }
  }
}
