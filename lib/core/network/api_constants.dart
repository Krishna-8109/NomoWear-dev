class ApiConstants {
  static const String baseUrl = 'https://nomowear-backend.onrender.com';
  // static const String baseUrl = 'http://192.168.0.15:5000';
  static const String loginPath = 'mobile/v1/login';
  static const String resendOtpPath = 'mobile/v1/resend-otp';
  static const String verifyOtpPath = 'mobile/v1/verify-otp';
  static const String registerPath = 'mobile/v1/register';
  static const String profilePath = 'mobile/v1/profile';
  static const String productsPath = 'mobile/v1/products';
  static const String wardrobeKitsPath = 'mobile/v1/wardrobe-kits';
  static const String bannersPath = 'mobile/v1/banners';
  static const String planCategoriesPath = 'mobile/v1/plans/categories/';
  static const String plansPath = 'mobile/v1/plans';
  static const String subscriptionsCreateOrderPath =
      'mobile/v1/subscriptions/create-order';
  static const String subscriptionsActivePath =
      'mobile/v1/subscriptions/me/active';
  static const String subscriptionsMePath = 'mobile/v1/subscriptions/me';
  static const String subscriptionsVerifyPaymentPath =
      'mobile/v1/subscriptions/verify-payment';
  static const String subscriptionsUpgradePreviewPath =
      'mobile/v1/subscriptions/upgrade/preview';
  static const String subscriptionsUpgradeCreateOrderPath =
      'mobile/v1/subscriptions/upgrade/create-order';
  static const String subscriptionsUpgradeVerifyPaymentPath =
      'mobile/v1/subscriptions/upgrade/verify-payment';
  static const String ordersPath = 'mobile/v1/orders';
  static const String ordersInitiatePath = 'mobile/v1/orders/initiate';
  static const String ordersVerifyPaymentPath =
      'mobile/v1/orders/verify-payment';

  /// POST mobile/v1/orders/{orderId}/return
  static String orderReturnPath(String orderId) =>
      '$ordersPath/${orderId.trim()}/return';
  static const String cartPath = 'mobile/v1/cart';
  static const String filtersPath = 'mobile/v1/filters/getFilters';
  static const String productsRatingPath = 'mobile/v1/products/rating';
  static const String productsMyRatingsPath = 'mobile/v1/products/my-ratings';
  static const String wishlistPath = 'wishlist';
  static const String customerAddressesPath = 'mobile/v1/customer-addresses';
  static const String customerAddressesByCustomerPath =
      'mobile/v1/customer-addresses/customer';

  /// Master location lists for Profile Address (State → City/Village).
  ///
  /// CHANGE: Placeholders for dedicated backend endpoints. Keep null until the
  /// backend ships these routes, then set paths and switch
  /// [LocationCubit] to [ApiLocationRepository].
  ///
  /// Suggested contracts (confirm with backend):
  /// - GET statesPath?country=India → list of state names
  /// - GET citiesPath?state={stateName} → list of city/village names
  static const String? statesPath = null;
  static const String? citiesPath = null;
}
