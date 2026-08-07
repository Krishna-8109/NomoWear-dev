import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/orders/data/models/initiate_order_result.dart';
import 'package:nomowear/features/orders/data/order_repository.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
import 'package:nomowear/features/subscriptions/data/models/active_subscription.dart';
import 'package:nomowear/features/subscriptions/data/models/subscription_order.dart';
import 'package:nomowear/features/subscriptions/data/models/subscription_upgrade.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';

class SubscriptionRepository {
  SubscriptionRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
    ProfileRepository? profileRepository,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage(),
        _profileRepository = profileRepository ?? ProfileRepository();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;
  final ProfileRepository _profileRepository;

  /// Returns all subscriptions (current + history) for the logged-in customer.
  Future<List<ActiveSubscription>> getMySubscriptions() async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.get(
      ApiConstants.subscriptionsMePath,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load subscriptions',
      );
    }

    return _parseSubscriptionList(json['data']);
  }

  List<ActiveSubscription> _parseSubscriptionList(dynamic data) {
    if (data is! List) return [];

    final subscriptions = data
        .whereType<Map>()
        .map((item) => ActiveSubscription.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((s) => s.id.isNotEmpty)
        .toList();

    subscriptions.sort(ActiveSubscription.compareByRecency);

    final current = ActiveSubscription.pickCurrent(subscriptions);
    if (current != null) {
      SubscriptionCache.instance.setActiveSubscription(current);
    }

    return subscriptions;
  }

  /// Returns the customer's active subscription, or null if none.
  Future<ActiveSubscription?> getActiveSubscription({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = SubscriptionCache.instance.activeSubscription;
      if (cached != null) return cached;
    }

    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    try {
      final json = await _apiClient.get(
        ApiConstants.subscriptionsActivePath,
        authToken: authToken,
      );

      final subscription = _parseActiveSubscriptionResponse(json);
      SubscriptionCache.instance.setActiveSubscription(subscription);
      return subscription;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        SubscriptionCache.instance.clear();
        return null;
      }
      rethrow;
    }
  }

  ActiveSubscription? _parseActiveSubscriptionResponse(
    Map<String, dynamic> json,
  ) {
    final data = _extractSubscriptionMap(json);
    if (data == null) return null;

    final subscription = ActiveSubscription.fromJson(data);
    if (!subscription.shouldDisplay) return null;
    return subscription;
  }

  Map<String, dynamic>? _extractSubscriptionMap(Map<String, dynamic> json) {
    final data = json['data'];

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['subscription'] is Map) {
        return Map<String, dynamic>.from(map['subscription'] as Map);
      }
      if (map['activeSubscription'] is Map) {
        return Map<String, dynamic>.from(map['activeSubscription'] as Map);
      }
      if (_looksLikeSubscription(map)) return map;
    }

    if (data is List && data.isNotEmpty && data.first is Map) {
      final first = Map<String, dynamic>.from(data.first as Map);
      if (_looksLikeSubscription(first)) return first;
    }

    if (_looksLikeSubscription(json)) {
      return Map<String, dynamic>.from(json);
    }

    return null;
  }

  bool _looksLikeSubscription(Map<String, dynamic> json) {
    return json.containsKey('planName') ||
        json.containsKey('plan_name') ||
        json.containsKey('planRef') ||
        json.containsKey('plan_ref') ||
        json.containsKey('planStatus') ||
        json.containsKey('plan_status') ||
        json.containsKey('id');
  }

  Future<SubscriptionOrder> createOrder({
    required String planRef,
    required String billingPeriod,
    String? planId,
  }) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final resolvedPlanId = (planId ?? planRef).trim();
    if (resolvedPlanId.isEmpty) {
      throw const ApiException('Plan reference is missing. Please reselect a plan.');
    }

    final json = await _apiClient.post(
      ApiConstants.subscriptionsCreateOrderPath,
      {
        'planRef': resolvedPlanId,
        'planId': resolvedPlanId,
        'billingPeriod': billingPeriod,
      },
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to create subscription order',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid subscription order response');
    }

    final order = SubscriptionOrder.fromJson(data);
    if (order.razorpayOrderId.isEmpty || order.razorpayKeyId.isEmpty) {
      throw const ApiException('Payment details missing from server response');
    }

    return order;
  }

  Future<SubscriptionUpgradePreview> previewUpgrade({
    required String planRef,
    required String billingPeriod,
  }) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final resolvedPlanRef = planRef.trim();
    if (resolvedPlanRef.isEmpty) {
      throw const ApiException('Plan reference is missing. Please reselect a plan.');
    }

    final json = await _apiClient.get(
      ApiConstants.subscriptionsUpgradePreviewPath,
      authToken: authToken,
      queryParameters: {
        'planRef': resolvedPlanRef,
        'billingPeriod': _normalizeBillingPeriod(billingPeriod),
      },
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load upgrade preview',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid upgrade preview response');
    }

    return SubscriptionUpgradePreview.fromJson(data);
  }

  Future<SubscriptionUpgradeOrder> createUpgradeOrder({
    required String planRef,
    required String billingPeriod,
    int? selectedGarmentsCount,
    List<String>? garmentIds,
  }) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final resolvedPlanRef = planRef.trim();
    if (resolvedPlanRef.isEmpty) {
      throw const ApiException('Plan reference is missing. Please reselect a plan.');
    }

    final body = <String, dynamic>{
      'planRef': resolvedPlanRef,
      'billingPeriod': _normalizeBillingPeriod(billingPeriod),
    };

    if (selectedGarmentsCount != null) {
      body['selectedGarmentsCount'] = selectedGarmentsCount;
    }
    if (garmentIds != null && garmentIds.isNotEmpty) {
      body['garmentIds'] = garmentIds;
    }

    final json = await _apiClient.post(
      ApiConstants.subscriptionsUpgradeCreateOrderPath,
      body,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to create upgrade order',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid upgrade order response');
    }

    final order = SubscriptionUpgradeOrder.fromJson(data);
    if (order.razorpayOrderId.isEmpty || order.razorpayKeyId.isEmpty) {
      throw const ApiException('Payment details missing from server response');
    }
    return order;
  }

  Future<ActiveSubscription> verifyUpgradePayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String paymentOrderId,
  }) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.post(
      ApiConstants.subscriptionsUpgradeVerifyPaymentPath,
      {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
        'paymentOrderId': paymentOrderId,
      },
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Upgrade payment verification failed',
      );
    }

    final subscription = _parseActiveSubscriptionResponse(json);
    if (subscription != null) {
      SubscriptionCache.instance.setActiveSubscription(subscription);
      return subscription;
    }

    final active = await getActiveSubscription(forceRefresh: true);
    if (active == null) {
      throw const ApiException(
        'Payment verified but subscription is not active yet. Please try again.',
      );
    }
    return active;
  }

  String _normalizeBillingPeriod(String billingPeriod) {
    final normalized = billingPeriod.trim().toLowerCase();
    if (normalized == 'yearly' || normalized == 'year') return 'yearly';
    return 'monthly';
  }

  /// Confirms a wardrobe kit booking for an active subscriber (no payment).
  Future<InitiateOrderResult> createWardrobeBookingOrder({
    String? addressId,
    String? deliveryDate,
    String? deliveryTime,
  }) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final active = await _resolveActiveSubscription();
    final resolvedPlanRef = active.planRef.trim();
    if (resolvedPlanRef.isEmpty) {
      throw const ApiException(
        'Active subscription plan not found. Please try again.',
      );
    }

    final resolvedAddressId = await _resolveAddressId(addressId);
    var resolvedDeliveryDate =
        deliveryDate ?? CheckoutSession.instance.apiDeliveryDate;
    var resolvedDeliveryTime =
        deliveryTime ?? CheckoutSession.instance.deliveryTime?.trim();

    if (resolvedDeliveryDate == null || resolvedDeliveryDate.isEmpty) {
      resolvedDeliveryDate = _defaultDeliveryDate();
    }
    if (resolvedDeliveryTime == null || resolvedDeliveryTime.isEmpty) {
      resolvedDeliveryTime = OrderRepository.defaultDeliveryTime;
    }

    final resolvedBillingPeriod =
        active.billingPeriod.trim().toUpperCase().isNotEmpty
            ? active.billingPeriod.trim().toUpperCase()
            : 'MONTHLY';

    final json = await _apiClient.post(
      ApiConstants.subscriptionsCreateOrderPath,
      {
        'planRef': resolvedPlanRef,
        'planId': resolvedPlanRef,
        'billingPeriod': resolvedBillingPeriod,
        'addressId': resolvedAddressId,
        'checkout_type': 'kit',
        'deliveryDate': resolvedDeliveryDate,
        'deliveryTime': resolvedDeliveryTime,
      },
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to confirm wardrobe booking',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid wardrobe booking response');
    }

    final result = InitiateOrderResult.fromJson(data);
    if (result.orderId.isEmpty) {
      throw const ApiException('Invalid wardrobe booking response');
    }
    return result;
  }

  Future<ActiveSubscription> _resolveActiveSubscription() async {
    final active = await getActiveSubscription(forceRefresh: true);
    if (active == null || !active.isActive) {
      throw const ApiException(
        'No active subscription found. Please subscribe before booking.',
      );
    }
    return active;
  }

  Future<String> _resolveAddressId(String? preferredId) async {
    final trimmed = preferredId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;

    final sessionId = CheckoutSession.instance.addressId?.trim();
    if (sessionId != null && sessionId.isNotEmpty) return sessionId;

    var customer = ProfileCache.instance.customer;
    customer ??= await _profileRepository.getProfile();

    for (final address in customer.addresses) {
      final id = address.id?.trim();
      if (id != null && id.isNotEmpty) return id;
    }

    throw const ApiException(
      'Please add a delivery address in your profile before placing an order.',
    );
  }

  String _defaultDeliveryDate() {
    final date = DateTime.now().add(const Duration(days: 1));
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Verifies Razorpay payment and activates the subscription on the backend.
  Future<ActiveSubscription> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.post(
      ApiConstants.subscriptionsVerifyPaymentPath,
      {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      },
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Payment verification failed',
      );
    }

    final subscription = _parseActiveSubscriptionResponse(json);
    if (subscription != null) {
      SubscriptionCache.instance.setActiveSubscription(subscription);
      return subscription;
    }

    final active = await getActiveSubscription(forceRefresh: true);
    if (active == null) {
      throw const ApiException(
        'Payment verified but subscription is not active yet. Please try again.',
      );
    }
    return active;
  }
}
