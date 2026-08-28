import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/razorpay_service.dart';
import 'package:nomowear/features/checkout/data/wardrobe_booking_session.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
import 'package:nomowear/features/profile/presentation/utils/profile_order_guard.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';
import 'package:nomowear/features/subscriptions/data/subscription_pricing.dart';
import 'package:nomowear/features/subscriptions/data/subscription_repository.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class MembershipPurchaseScreen extends StatefulWidget {
  final String planRef;
  final String planId;
  final String planTitle;
  final String priceString;
  final String period;
  final String billingPeriod;
  final List<String> features;

  const MembershipPurchaseScreen({
    super.key,
    required this.planRef,
    required this.planId,
    required this.planTitle,
    required this.priceString,
    required this.period,
    required this.billingPeriod,
    required this.features,
  });

  @override
  State<MembershipPurchaseScreen> createState() =>
      _MembershipPurchaseScreenState();
}

class _MembershipPurchaseScreenState extends State<MembershipPurchaseScreen> {
  final SubscriptionRepository _subscriptionRepository =
      SubscriptionRepository();
  final RazorpayService _razorpayService = RazorpayService();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpayService.init(
      onSuccess: _onPaymentSuccess,
      onFailure: _onPaymentFailure,
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
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
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment details incomplete. Please contact support.'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _subscriptionRepository.verifyPayment(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );
      await _subscriptionRepository.getActiveSubscription(forceRefresh: true);

      if (kDebugMode) {
        final active = SubscriptionCache.instance.activeSubscription;
        debugPrint(
          '[SUBSCRIPTION SUCCESS] activeSubscription=${active != null && active.isActive}',
        );
      }

      await WardrobeBookingSession.instance.restore();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (WardrobeBookingSession.instance.awaitingSubscriptionPurchase) {
        await WardrobeBookingSession.instance.markSubscriptionPurchased();
      }
      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.orderSuccessScreen,
        arguments: const {
          'isSubscription': true,
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to verify payment. Please try again.'),
        ),
      );
    }
  }

  void _onPaymentFailure(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);

    final message = response.message ?? 'Payment cancelled or failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _payAndSubscribe() async {
    if (_isProcessing ||
        (widget.planRef.isEmpty && widget.planId.isEmpty)) {
      return;
    }

    final canProceed = await ProfileOrderGuard.ensureCompleteProfile(context);
    if (!canProceed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final pricing = SubscriptionPricing.fromPlanPrice(widget.priceString);
      final payablePaise = pricing.amountInPaise;
      final order = await _subscriptionRepository.createOrder(
        planRef: widget.planRef.isNotEmpty ? widget.planRef : widget.planId,
        planId: widget.planId.isNotEmpty ? widget.planId : widget.planRef,
        billingPeriod: widget.billingPeriod,
        amount: payablePaise,
      );

      if (!mounted) return;

      var customer = ProfileCache.instance.customer;
      if (customer == null) {
        try {
          customer = await ProfileRepository().getProfile();
        } catch (_) {
          customer = null;
        }
      }

      _razorpayService.openCheckout(
        keyId: order.razorpayKeyId,
        orderId: order.razorpayOrderId,
        amount: pricing.razorpayAmountPaise(order.amount),
        currency: order.currency,
        name: customer?.fullName,
        email: customer?.email,
        contact: customer?.mobile,
        description: '${widget.planTitle} Membership',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start payment. Please try again.'),
        ),
      );
    }
  }

  static String _formatIntegerCurrency(num value) {
    final integerPart = value.round().toString();
    if (integerPart.length <= 3) return integerPart;
    final lastThree = integerPart.substring(integerPart.length - 3);
    final rest = integerPart.substring(0, integerPart.length - 3);
    final formattedRest = rest.replaceAllMapped(
      RegExp(r'.{1,2}(?=(.{2})+(?!.))'),
      (match) => '${match[0]},',
    );
    return '$formattedRest,$lastThree';
  }

  @override
  Widget build(BuildContext context) {
    final cleanPrice = widget.priceString
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .trim();
    final parsedPrice = num.tryParse(cleanPrice) ?? 0;
    final formattedAmount = '₹${_formatIntegerCurrency(parsedPrice)}';
    final formattedSubtotal = formattedAmount;
    final formattedGrandTotal = formattedAmount;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1012),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColours.primary),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription Plans',
          style: CustomTextStyles.openSansSemiBold.copyWith(
            fontSize: 18,
            color: AppColours.primary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFFE6C27A).withOpacity(0.15),
                  const Color(0xFFE6C27A),
                  const Color(0xFFE6C27A).withOpacity(0.15),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAN SUMMARY',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 14,
                        letterSpacing: 1.4,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16181D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColours.primary.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.planTitle} Membership',
                                      style: CustomTextStyles.montserratBold
                                          .copyWith(fontSize: 18),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      '₹${widget.priceString} / ${widget.period}',
                                      style: CustomTextStyles.openSansSemiBold
                                          .copyWith(
                                        fontSize: 20,
                                        color: AppColours.primary,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'Access to premium curated\nwardrobe',
                                      style: CustomTextStyles.openSansRegular
                                          .copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 80.w,
                                height: 80.w,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: AssetImage(
                                      ImageConstant.subscriptionBadge,
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24.h),
                          ...widget.features.map(
                            (feature) => Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: AppColours.primary,
                                    size: 16,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: CustomTextStyles.openSansRegular
                                          .copyWith(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 48.h),
                    Text(
                      'ORDER SUMMARY',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 14,
                        color: AppColours.primary,
                        letterSpacing: 2.4,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    _buildSummaryRow('Subtotal', formattedSubtotal, false),
                    SizedBox(height: 20.h),
                    Divider(color: AppColours.primary, thickness: 0.2),
                    SizedBox(height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Grand Total',
                          style: CustomTextStyles.montserratBold.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          formattedGrandTotal,
                          style: CustomTextStyles.montserratBold.copyWith(
                            fontSize: 24,
                            color: AppColours.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10.fSize,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'By placing ths order, you agree to the Nomowear ',
                          style: CustomTextStyles.openSansRegular,
                        ),
                        TextSpan(
                          text: 'Terms & conditions\n',
                          style: CustomTextStyles.openSansRegular.copyWith(
                            color: AppColours.primary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.termsConditionsScreen,
                              );
                            },
                        ),
                        TextSpan(
                          text: 'and ',
                          style: CustomTextStyles.openSansRegular,
                        ),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: CustomTextStyles.openSansRegular.copyWith(
                            color: AppColours.primary,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.privacyPolicyScreen,
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.maxFinite,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _payAndSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColours.primary,
                        disabledBackgroundColor: AppColours.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            )
                          : Text(
                              'PAY & SUBSCRIBE',
                              style: CustomTextStyles.montserratBold.copyWith(
                                fontSize: 16,
                                color: Colors.black,
                                letterSpacing: 1.6,
                              ),
                            ),
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

  Widget _buildSummaryRow(
    String label,
    String value,
    bool isBold, {
    bool isGreyPrice = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: CustomTextStyles.openSansRegular.copyWith(
            fontSize: 14,
            color: AppColours.hintcolor,
          ),
        ),
        Text(
          value,
          style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 16),
        ),
      ],
    );
  }
}
