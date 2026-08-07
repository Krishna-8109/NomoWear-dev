import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/razorpay_service.dart';
import 'package:nomowear/features/cart/data/models/remote_cart.dart';
import 'package:nomowear/features/cart/data/cart_repository.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/checkout/presentation/utils/checkout_pricing.dart';
import 'package:nomowear/features/checkout/presentation/utils/subscription_booking_eligibility.dart';
import 'package:nomowear/features/orders/data/models/initiate_order_result.dart';
import 'package:nomowear/features/orders/data/order_repository.dart';
import 'package:nomowear/features/orders/data/orders_cache.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
import 'package:nomowear/features/profile/domain/user_order.dart';
import 'package:nomowear/features/profile/presentation/utils/profile_order_guard.dart';
import 'package:nomowear/features/subscriptions/data/subscription_garment_balance.dart';
import 'package:nomowear/features/subscriptions/data/subscription_repository.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class EssentialsCheckoutScreen extends StatefulWidget {
  const EssentialsCheckoutScreen({
    Key? key,
    this.initialPrefetch,
  }) : super(key: key);

  final CheckoutPrefetchPayload? initialPrefetch;

  @override
  State<EssentialsCheckoutScreen> createState() =>
      _EssentialsCheckoutScreenState();
}

class _EssentialsCheckoutScreenState extends State<EssentialsCheckoutScreen> {
  final TextEditingController _noteController = TextEditingController();
  final OrderRepository _orderRepository = OrderRepository();
  final SubscriptionRepository _subscriptionRepository =
      SubscriptionRepository();
  final CartRepository _cartRepository = CartRepository();
  final RazorpayService _razorpayService = RazorpayService();

  bool _isPlacingOrder = false;
  bool _wardrobeGarmentsExpanded = false;

  // CHANGE: Backend-only payable snapshot (initiate-order amount = Razorpay amount).
  CheckoutPayableSnapshot? _payableSnapshot;
  bool _isLoadingPayable = true;
  String? _payableError;
  String? _payableCartFingerprint;
  Future<void>? _payableLoadFuture;

  static const List<String> _allSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  static const List<int> _qtyOptions = [1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPrefetch;
    if (initial != null) {
      _payableSnapshot = initial.snapshot;
      _payableCartFingerprint = initial.cartFingerprint;
      _isLoadingPayable = false;
      _payableError = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<CartBloc>().state;
      if (state.isEmpty) {
        context.read<CartBloc>().add(LoadCartEvent());
        return;
      }
      final fp = CheckoutPricing.cartFingerprint(state);
      // Prefetch can be stale if qty changed on Place Order before opening this screen.
      if (_payableSnapshot == null || _payableCartFingerprint != fp) {
        _loadAuthoritativePayable(state);
      }
    });
    _razorpayService.init(
      onSuccess: _onPaymentSuccess,
      onFailure: _onPaymentFailure,
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    _completePaymentVerification(response);
  }

  Future<void> _completePaymentVerification(
    PaymentSuccessResponse response,
  ) async {
    final orderId = response.orderId?.trim() ?? '';
    final paymentId = response.paymentId?.trim() ?? '';
    final signature = response.signature?.trim() ?? '';

    if (orderId.isEmpty || paymentId.isEmpty || signature.isEmpty) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment details incomplete. Please contact support.'),
        ),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final verified = await _orderRepository.verifyPayment(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );
      if (!mounted) return;
      _finishOrderSuccess(
        verified.orderId,
        orderNumber: verified.orderNumber,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to verify payment. Please try again.'),
        ),
      );
    }
  }

  void _onPaymentFailure(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isPlacingOrder = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message ?? 'Payment cancelled or failed'),
      ),
    );
  }

  void _finishOrderSuccess(
    String orderId, {
    String? orderNumber,
  }) async {
    var displayNumber = orderNumber?.trim() ?? '';
    if (displayNumber.isEmpty) {
      try {
        final detail = await _orderRepository.getOrderDetail(orderId);
        if (detail.orderNumber.trim().isNotEmpty) {
          displayNumber = detail.orderNumber.trim();
        }
      } catch (_) {
        // Fall back to internal id when lookup fails.
      }
    }
    if (displayNumber.isEmpty) displayNumber = orderId;

    if (!mounted) return;
    OrdersCache.instance.clear();
    userOrdersList.clear();
    CheckoutSession.instance.clear();
    // Refresh remaining garments after a completed subscription booking so the
    // next booking uses the updated balance (API or order-history fallback).
    // ignore: unawaited_futures
    SubscriptionGarmentBalance.resolveAndCache(forceRefresh: true);
    context.read<CartBloc>().add(ClearCartEvent());
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.orderSuccessScreen,
      arguments: {
        'orderId': orderId,
        'orderNumber': displayNumber,
      },
    );
  }

  bool _isSubscriptionWardrobeBooking(CartState state) {
    if (state.wardrobeItems.isEmpty || state.essentialItems.isNotEmpty) {
      return false;
    }
    return CheckoutSession.instance.useSubscriptionBooking;
  }

  bool get _isInteractionLocked =>
      _isPlacingOrder ||
      (_isLoadingPayable && _payableSnapshot == null) ||
      (_payableLoadFuture != null && _payableSnapshot == null);

  Future<void> _loadAuthoritativePayable(CartState state) async {
    if (_isSubscriptionWardrobeBooking(state)) {
      if (!mounted) return;
      setState(() {
        _isLoadingPayable = false;
        _payableSnapshot = null;
        _payableError = null;
      });
      return;
    }

    var fingerprint = CheckoutPricing.cartFingerprint(state);
    if (_payableSnapshot != null &&
        _payableCartFingerprint == fingerprint &&
        !_isLoadingPayable &&
        _payableLoadFuture == null) {
      return;
    }

    // Show updated totals immediately from local qty × price while server reloads.
    if (mounted) {
      setState(() {
        _applyOptimisticPayableSummary(state, fingerprint);
        _isLoadingPayable = true;
        _payableError = null;
      });
    }

    if (_payableLoadFuture != null) {
      await _payableLoadFuture;
      if (!mounted) return;
      final latest = context.read<CartBloc>().state;
      final latestFp = CheckoutPricing.cartFingerprint(latest);
      if (_payableSnapshot != null &&
          _payableCartFingerprint == latestFp &&
          !_isLoadingPayable) {
        return;
      }
      state = latest;
      fingerprint = latestFp;
      if (mounted) {
        setState(() {
          _applyOptimisticPayableSummary(state, fingerprint);
          _isLoadingPayable = true;
          _payableError = null;
        });
      }
    }

    _payableLoadFuture = _fetchAuthoritativePayable(state, fingerprint);
    try {
      await _payableLoadFuture;
    } finally {
      _payableLoadFuture = null;
    }
  }

  void _applyOptimisticPayableSummary(CartState state, String fingerprint) {
    final summary = CheckoutPricing.fromLocalCartLines(state);
    final previous = _payableSnapshot;
    if (previous != null) {
      _payableSnapshot = CheckoutPayableSnapshot(
        remoteCart: previous.remoteCart,
        initiate: previous.initiate,
        summary: summary,
        gatewayAmountPaise: summary.total * 100,
        displayTotalRupees: summary.total,
      );
    } else {
      // Keep summary visible while the first authoritative load is in flight.
      _payableSnapshot = CheckoutPayableSnapshot(
        remoteCart: const RemoteCart(id: '', items: []),
        initiate: const InitiateOrderResult(
          orderId: '',
          status: '',
          amount: 0,
        ),
        summary: summary,
        gatewayAmountPaise: summary.total * 100,
        displayTotalRupees: summary.total,
      );
    }
    _payableCartFingerprint = fingerprint;
  }

  /// Syncs cart with backend, initiates order once, stores payable for UI + Razorpay.
  Future<void> _fetchAuthoritativePayable(
    CartState state,
    String fingerprint,
  ) async {
    try {
      // Flush local qty/size mutations before reading server cart totals.
      // Otherwise getCart() can return stale lines and Order Summary freezes.
      final syncedCart = state.items.isEmpty
          ? const RemoteCart(id: '', items: [])
          : await _cartRepository.syncCartState(state);
      final remoteCart =
          syncedCart.isEmpty ? await _cartRepository.getCart() : syncedCart;
      final initiate = await _initiateCheckoutOrder(state);
      if (!mounted) return;

      // Cart may have changed again while this request was in flight.
      final latest = context.read<CartBloc>().state;
      final latestFp = CheckoutPricing.cartFingerprint(latest);
      if (latestFp != fingerprint) {
        setState(() {
          _applyOptimisticPayableSummary(latest, latestFp);
          _isLoadingPayable = true;
        });
        await _fetchAuthoritativePayable(latest, latestFp);
        return;
      }

      if (!initiate.canOpenRazorpay) {
        setState(() {
          _isLoadingPayable = false;
          _payableError = initiate.requiresPayment
              ? 'Payment details missing from server. Please try again.'
              : 'Unable to load payable amount. Please try again.';
        });
        return;
      }

      final snapshot = CheckoutPricing.payableSnapshot(
        remoteCart: remoteCart.isEmpty
            ? const RemoteCart(id: '', items: [])
            : remoteCart,
        initiate: initiate,
        cartState: state,
      );

      setState(() {
        _payableSnapshot = snapshot;
        _payableCartFingerprint = fingerprint;
        _isLoadingPayable = false;
        _payableError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPayable = false;
        _payableError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingPayable = false;
        _payableError = 'Unable to load order total. Please try again.';
      });
    }
  }

  Future<InitiateOrderResult> _initiateCheckoutOrder(CartState state) async {
    final hasWardrobe = state.wardrobeItems.isNotEmpty;
    final hasEssentials = state.essentialItems.isNotEmpty;
    final checkoutType = hasWardrobe ? 'kit' : 'essentials';

    return _orderRepository.initiateOrder(
      checkoutType: checkoutType,
      nonSubscription: true,
      productClass: hasEssentials ? 'single_item' : 'wardrobe_kit',
      wardrobeKitId: hasWardrobe
          ? (state.wardrobeKitProductId ?? state.wardrobeKitId)
          : null,
    );
  }

  bool _canProceedToPaymentFor(CartState state) {
    final fp = CheckoutPricing.cartFingerprint(state);
    return !_isLoadingPayable &&
        _payableLoadFuture == null &&
        _payableError == null &&
        _payableSnapshot != null &&
        _payableCartFingerprint == fp &&
        _payableSnapshot!.initiate.canOpenRazorpay;
  }

  /// Order Summary for the current cart. When qty/size changed, show live local
  /// totals immediately even before the initiate-order snapshot catches up.
  OrderSummary? _displaySummary(CartState state) {
    if (_isSubscriptionWardrobeBooking(state)) return null;

    final fp = CheckoutPricing.cartFingerprint(state);
    final snapshot = _payableSnapshot;
    if (snapshot != null && _payableCartFingerprint == fp) {
      return snapshot.summary;
    }
    return CheckoutPricing.fromLocalCartLines(state);
  }

  Future<void> _placeOrder(CartState state) async {
    if (_isPlacingOrder) return;

    final canPlaceOrder = await ProfileOrderGuard.ensureCompleteProfile(context);
    if (!canPlaceOrder || !mounted) return;

    // Ensure payable matches latest qty before opening Razorpay.
    final fp = CheckoutPricing.cartFingerprint(state);
    if (!_isSubscriptionWardrobeBooking(state) &&
        (_payableSnapshot == null ||
            _payableCartFingerprint != fp ||
            _isLoadingPayable ||
            _payableLoadFuture != null)) {
      await _loadAuthoritativePayable(state);
      if (!mounted) return;
      state = context.read<CartBloc>().state;
      if (!_canProceedToPaymentFor(state)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _payableError ??
                  'Unable to refresh payment amount. Please try again.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isPlacingOrder = true);

    final useSubscriptionWardrobeBooking =
        _isSubscriptionWardrobeBooking(state);

    try {
      if (useSubscriptionWardrobeBooking) {
        final eligibility = await SubscriptionBookingEligibility.check(
          repository: _subscriptionRepository,
          forceRefresh: true,
        );
        if (!mounted) return;

        if (!eligibility.canBookWithSubscription) {
          setState(() => _isPlacingOrder = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(eligibility.unavailableMessage)),
          );
          return;
        }

        final wardrobeKitId =
            state.wardrobeKitProductId ?? state.wardrobeKitId;
        final bookingResult = await _orderRepository.initiateOrder(
          checkoutType: 'kit',
          nonSubscription: false,
          productClass: 'wardrobe_kit',
          wardrobeKitId: wardrobeKitId,
        );

        if (!mounted) return;

        if (bookingResult.orderId.isNotEmpty &&
            (bookingResult.isConfirmed || !bookingResult.requiresPayment)) {
          _finishOrderSuccess(
            bookingResult.orderId,
            orderNumber: bookingResult.orderNumber,
          );
          return;
        }

        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bookingResult.requiresPayment
                  ? 'Subscription booking could not be confirmed. Please try again.'
                  : 'Unable to confirm wardrobe booking. Please try again.',
            ),
          ),
        );
        return;
      }

      // CHANGE: Reuse preloaded initiate-order snapshot (same amount as UI summary).
      final fingerprint = CheckoutPricing.cartFingerprint(state);
      if (_payableSnapshot == null ||
          _payableCartFingerprint != fingerprint ||
          !_payableSnapshot!.initiate.canOpenRazorpay) {
        await _loadAuthoritativePayable(state);
      }

      final snapshot = _payableSnapshot;
      if (snapshot == null || !snapshot.initiate.canOpenRazorpay) {
        if (!mounted) return;
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _payableError ??
                  'Unable to start payment. Please try again.',
            ),
          ),
        );
        return;
      }

      final result = snapshot.initiate;

      var customer = ProfileCache.instance.customer;
      if (customer == null) {
        try {
          customer = await ProfileRepository().getProfile();
        } catch (_) {
          customer = null;
        }
      }

      setState(() => _isPlacingOrder = false);

      // Gateway amount is identical to Payment Summary grand total source.
      _razorpayService.openCheckout(
        keyId: result.razorpayKeyId!,
        orderId: result.razorpayOrderId!,
        amount: snapshot.gatewayAmountPaise,
        currency: result.currency,
        name: customer?.fullName,
        email: customer?.email,
        contact: customer?.mobile,
        description: state.wardrobeItems.isNotEmpty
            ? 'Nomowear wardrobe kit order'
            : 'Nomowear essentials order',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to place order. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartBloc, CartState>(
      listenWhen: (previous, current) {
        if (previous.items.isNotEmpty && current.isEmpty) return true;
        if (previous.items.isEmpty && current.items.isNotEmpty) return true;
        return CheckoutPricing.cartFingerprint(previous) !=
            CheckoutPricing.cartFingerprint(current);
      },
      listener: (context, state) {
        if (_isPlacingOrder) return;
        if (state.isEmpty && Navigator.canPop(context)) {
          Navigator.pop(context);
          return;
        }
        // Reload backend payable when cart contents change (size/qty/items).
        if (!state.isEmpty) {
          _loadAuthoritativePayable(state);
        }
      },
      builder: (context, state) {
        if (state.isEmpty && !_isPlacingOrder) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F1012),
            body: const SizedBox.shrink(),
          );
        }

        final subscriptionBooking = _isSubscriptionWardrobeBooking(state);
        final summary = _displaySummary(state);

        return Scaffold(
          backgroundColor: const Color(0xFF0F1012),
          body: Stack(
            children: [
              AbsorbPointer(
                absorbing: _isInteractionLocked,
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildAppBar(),
                      Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFE6C27A).withOpacity(0.15),
                              Color(0xFFE6C27A),
                              Color(0xFFE6C27A).withOpacity(0.15),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 30,),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              _buildSelectedGarments(state),
                              SizedBox(height: 20.h),
                              _buildDeliveryDetails(),
                              SizedBox(height: 20.h),
                              _buildAddNote(),
                              SizedBox(height: 20.h),
                              _buildOrderSummary(
                                subtotal: summary?.subtotal ?? 0,
                                gst: summary?.gst ?? 0,
                                deliveryFee: summary?.deliveryFee ?? 0,
                                total: summary?.total ?? 0,
                                wardrobeKitAmount: summary?.wardrobeKitAmount ?? 0,
                                subscriptionBooking: subscriptionBooking,
                                kitTitle: state.wardrobeKitTitle,
                                hasWardrobeKit: state.wardrobeItems.isNotEmpty,
                                isLoadingPayable:
                                    !subscriptionBooking &&
                                        (_isLoadingPayable ||
                                            (_payableSnapshot == null &&
                                                _payableError == null)),
                                payableError: _payableError,
                              ),
                              SizedBox(height: 16.h),
                              _buildTermsText(context),
                              SizedBox(height: 38.h),

                              Divider(height: 1,color: AppColours.primary,thickness: 0.2,),

                            ],
                          ),
                        ),
                      ),
                      _buildProceedButton(state.items.isNotEmpty, state, subscriptionBooking),
                    ],
                  ),
                ),
              ),
              if (_isInteractionLocked) ...[
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x55000000)),
                ),
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFFE6C27A),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColours.primary.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, color: AppColours.primary, size: 20),
          ),
          Expanded(
            child: Text(
              'Cart',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColours.primary,
                fontSize: 16.fSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 20.w),

        ],
      ),
    );
  }

  Widget _buildSelectedGarments(CartState state) {
    final wardrobeItems = state.groupedWardrobeItems;
    final essentialItems = state.groupedEssentialItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wardrobeItems.isNotEmpty) ...[
          _buildWardrobeKitSection(state, wardrobeItems),
          SizedBox(height: 20.h),
        ],
        if (essentialItems.isNotEmpty) ...[
          if (wardrobeItems.isNotEmpty)
            Divider(
              height: 1,
              color: AppColours.primary,
              thickness: 0.2,
            ),
          if (wardrobeItems.isNotEmpty) SizedBox(height: 20.h),
          _buildSectionHeader(
            'SELECTED ESSENTIALS',
            '${essentialItems.length} Item${essentialItems.length == 1 ? '' : 's'}',
          ),
          SizedBox(height: 10.h),
          ...essentialItems.map((item) => _buildSelectedItemCard(item, showPrice: true)),
        ],
        if (essentialItems.isNotEmpty) ...[
          SizedBox(height: 20.h),
          Divider(
            height: 1,
            color: AppColours.primary,
            thickness: 0.2,
          ),
        ],
      ],
    );
  }

  Widget _buildWardrobeKitSection(
    CartState state,
    List<CartItem> wardrobeItems,
  ) {
    final garmentCount =
        wardrobeItems.fold<int>(0, (sum, item) => sum + item.quantity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SELECTED WARDROBE', '1 Item'),
        SizedBox(height: 16.h),
        _buildWardrobeKitSummaryCard(
          state: state,
          items: wardrobeItems,
          garmentCount: garmentCount,
        ),
        if (_wardrobeGarmentsExpanded) ...[
          SizedBox(height: 24.h),
          _buildSectionHeader(
            'SELECTED GARMENTS',
            '${wardrobeItems.length} Item${wardrobeItems.length == 1 ? '' : 's'}',
          ),
          SizedBox(height: 10.h),
          ...wardrobeItems.map(
            (item) => _buildSelectedItemCard(
              item,
              showPrice: !CheckoutSession.instance.useSubscriptionBooking,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWardrobeKitSummaryCard({
    required CartState state,
    required List<CartItem> items,
    required int garmentCount,
  }) {
    return GestureDetector(
      onTap: () =>
          setState(() => _wardrobeGarmentsExpanded = !_wardrobeGarmentsExpanded),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWardrobeCollage(items),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.wardrobeKitTitle,
                  style: CustomTextStyles.montserratSemiBold.copyWith(
                    color: AppColours.primary,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'No of Garments: $garmentCount',
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 12,
                    color: AppColours.secondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: AnimatedRotation(
              turns: _wardrobeGarmentsExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: AppColours.primary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobeCollage(List<CartItem> items) {
    final images = items
        .map((e) => ProductImage.resolveUrl(e.imageUrl))
        .take(4)
        .toList();
    while (images.length < 4) {
      images.add(
        images.isNotEmpty ? images.last : ImageConstant.comfortWearImg1,
      );
    }

    Widget cell(String url, {BorderRadius? radius}) {
      return ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: ProductImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 88.w,
        height: 88.w,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: cell(
                      images[0],
                      radius: const BorderRadius.only(topLeft: Radius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: cell(
                      images[1],
                      radius: const BorderRadius.only(topRight: Radius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: cell(
                      images[2],
                      radius:
                          const BorderRadius.only(bottomLeft: Radius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: cell(
                      images[3],
                      radius:
                          const BorderRadius.only(bottomRight: Radius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionHeader(String title, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: CustomTextStyles.montserratBold.copyWith(
            fontSize: 12,
            color: AppColours.primary,
            letterSpacing: 1,
          ),
        ),
        Text(
          count,
          style: TextStyle(color: Colors.white54, fontSize: 11.fSize),
        ),
      ],
    );
  }

  Widget _buildSelectedItemCard(CartItem item, {required bool showPrice}) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ProductImage(
              imageUrl: item.imageUrl,
              width: 44.w,
              height: 52.h,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 14,color: AppColours.primary),
                ),
                if (showPrice) ...[
                  SizedBox(height: 2.h),
                  Text(
                    CheckoutPricing.formatMoney(
                      CheckoutPricing.parseItemPrice(
                            item.price,
                            isEssential: item.isEssential,
                          ) *
                          item.quantity,
                    ),
                    style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 12,color: AppColours.primary),
                  ),
                ],
                SizedBox(height: 4.h),
                Row(
                  children: [
                    _buildDropdownChip(
                      value: item.selectedSize,
                      items: {
                        ...?(_allSizes),
                        item.selectedSize,
                      }.toList(),
                      prefix: 'Size: ',
                      onChanged: (val) {
                        if (val != null) {
                          context
                              .read<CartBloc>()
                              .add(UpdateCartItemSizeEvent(item.id, val));
                        }
                      },
                    ),
                    SizedBox(width: 10.w),
                    _buildDropdownChip<int>(
                      value: item.quantity,
                      items: {
                        ..._qtyOptions,
                        item.quantity,
                      }.toList()
                        ..sort(),
                      prefix: 'Qty: ',
                      onChanged: (val) {
                        if (val != null) {
                          context
                              .read<CartBloc>()
                              .add(UpdateCartItemQuantityEvent(item.id, val));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.read<CartBloc>().add(RemoveFromCartEvent(item.id)),
            child: Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: SvgPicture.asset(IconConstant.delete1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip<T>({
    required T value,
    required List<T> items,
    required String prefix,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 28.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColours.secondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColours.primary.withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          dropdownColor: AppColours.secondary,
          icon: Icon(Icons.arrow_drop_down, color: Colors.black, size: 18),
          style: TextStyle(color: Colors.white, fontSize: 11.fSize),
          onChanged: onChanged,
          items: items
              .map((s) => DropdownMenuItem<T>(
                    value: s,
                    child: Text(
                      '$prefix$s',
                      style: CustomTextStyles.montserratSemiBold
                          .copyWith(color: Colors.black, fontSize: 10),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    final session = CheckoutSession.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DELIVERY DETAILS',
          style: CustomTextStyles.montserratBold.copyWith(fontSize: 12,color: AppColours.primary,letterSpacing: 2.4),
        ),
        SizedBox(height: 10.h),
        _infoRow(
          icon: Icons.location_on_outlined,
          label: 'DELIVERY ADDRESS',
          value: session.addressDisplay,
        ),
        SizedBox(height: 10.h),
        _infoRow(
          icon: Icons.calendar_today_outlined,
          label: 'DELIVERY DATE',
          value: session.deliveryDateDisplay,
        ),
      ],
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColours.primary.withOpacity(0.9), size: 20),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 12,color: Color(0xffF5E6C899).withOpacity(0.4),letterSpacing: 1.2),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style:CustomTextStyles.openSansRegular.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddNote() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADD NOTE',
          style: CustomTextStyles.montserratBold.copyWith(fontSize: 12,color: AppColours.primary),

        ),
        SizedBox(height: 8.h),
        DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(8),
          dashPattern: const [6, 3], // 🔥 dot size & spacing
          color: Color(0xFFE6C27A).withOpacity(0.6),
          strokeWidth: 1.2,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: TextField(
              controller: _noteController,
              maxLines: 6,
              style: TextStyle(color: Colors.white70, fontSize: 13.fSize),
              decoration: InputDecoration(
                hintText: 'Please leave the order at the doorstep',
                hintStyle: CustomTextStyles.openSansRegular.copyWith(fontSize: 12,color: Color(0xFFF5E6C8).withOpacity(0.6)),
                border: InputBorder.none, // ❗ IMPORTANT
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildOrderSummary({
    required int subtotal,
    required int gst,
    required int deliveryFee,
    required int total,
    required int wardrobeKitAmount,
    required bool subscriptionBooking,
    required String kitTitle,
    required bool hasWardrobeKit,
    required bool isLoadingPayable,
    String? payableError,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORDER SUMMARY',
          style: CustomTextStyles.montserratBold.copyWith(
            fontSize: 12,
            color: AppColours.primary,
            letterSpacing: 2.0,
          ),
        ),
        SizedBox(height: 24.h),
        if (subscriptionBooking) ...[
          _summaryRow(kitTitle, 'Included in membership'),
          SizedBox(height: 16.h),
          _summaryRow('Delivery Fee', 'Free'),
          SizedBox(height: 16.h),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          SizedBox(height: 24.h),
          _summaryRow('Amount due today', '₹0', highlight: true),
        ] else if (isLoadingPayable) ...[
          // CHANGE: No interim local amounts — show loading until backend total is ready.
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColours.primary,
                ),
              ),
            ),
          ),
        ] else if (payableError != null) ...[
          _addressAlert(payableError),
        ] else ...[
          if (hasWardrobeKit && wardrobeKitAmount > 0) ...[
            _summaryRow(
              kitTitle.isNotEmpty ? kitTitle : 'Wardrobe Kit',
              CheckoutPricing.formatMoney(wardrobeKitAmount),
            ),
            SizedBox(height: 16.h),
          ],
          _summaryRow('Subtotal', CheckoutPricing.formatMoney(subtotal)),
          SizedBox(height: 16.h),
          _summaryRow('GST (18%)', CheckoutPricing.formatMoney(gst)),
          SizedBox(height: 16.h),
          _summaryRow(
            'Delivery Fee',
            deliveryFee > 0 ? CheckoutPricing.formatMoney(deliveryFee) : 'Free',
          ),
          SizedBox(height: 16.h),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          SizedBox(height: 24.h),
          _summaryRow(
            'Grand Total',
            CheckoutPricing.formatMoney(total),
            highlight: true,
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(String title, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: highlight
              ? CustomTextStyles.montserratBold.copyWith(
                  fontSize: 18.fSize,
                    color: AppColours.primary
                )
              : CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 14.fSize,
                  color: AppColours.secondary.withOpacity(0.85),
                ),
        ),
        Text(
          value,
          style: highlight
              ? CustomTextStyles.montserratBold.copyWith(
                  fontSize: 24.fSize,
                  color: AppColours.primary,
                )
              : CustomTextStyles.openSansSemiBold.copyWith(
                  fontSize: 14.fSize,
                  color: AppColours.secondary,
                ),
        ),
      ],
    );
  }

  Widget _addressAlert(String message) {
    return Container(
      width: double.maxFinite,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        border: Border.all(color: const Color(0xFFE6C279).withOpacity(0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: CustomTextStyles.openSansSemiBold.copyWith(
            fontSize: 12,
            color: AppColours.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsText(BuildContext context) {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12),
          children: [
            const TextSpan(
              text: 'By placing this order, you agree to the Nomowear ',
            ),

            // 🔥 Terms & Conditions
            TextSpan(
              text: 'Terms & conditions',
              style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12,color: AppColours.primary),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.pushNamed(context, AppRoutes.termsConditionsScreen);
                },
            ),

            const TextSpan(text: ' and '),

            // 🔥 Privacy Policy
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: AppColours.primary,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.pushNamed(context, AppRoutes.privacyPolicyScreen);
                },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProceedButton(
    bool canProceed,
    CartState state,
    bool subscriptionBooking,
  ) {
    final paymentReady =
        subscriptionBooking ||
            (_canProceedToPaymentFor(state) && canProceed);

    return Container(
      width: double.maxFinite,
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      height: 56.h,
      child: ElevatedButton(
        onPressed: paymentReady && !_isPlacingOrder
            ? () => _placeOrder(state)
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColours.primary,
          disabledBackgroundColor: Colors.white24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: _isPlacingOrder
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                subscriptionBooking ? 'CONFIRM BOOKING' : 'PROCEED TO PAYMENT',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13.fSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}
