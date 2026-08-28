import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/razorpay_service.dart';
import 'package:nomowear/features/home/presentation/screens/subscription_tab_widget.dart';
import 'package:nomowear/features/plans/data/plan_price_formatter.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
import 'package:nomowear/features/profile/presentation/utils/profile_order_guard.dart';
import 'package:nomowear/features/subscriptions/data/models/subscription_upgrade.dart';
import 'package:nomowear/features/subscriptions/data/subscription_repository.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class MembershipUpgradeScreen extends StatefulWidget {
  const MembershipUpgradeScreen({
    super.key,
    required this.planRef,
    required this.planTitle,
    required this.billingPeriod,
    required this.period,
  });

  final String planRef;
  final String planTitle;
  final String billingPeriod;
  final String period;

  @override
  State<MembershipUpgradeScreen> createState() => _MembershipUpgradeScreenState();
}

class _MembershipUpgradeScreenState extends State<MembershipUpgradeScreen> {
  final SubscriptionRepository _subscriptionRepository =
      SubscriptionRepository();
  final RazorpayService _razorpayService = RazorpayService();

  SubscriptionUpgradePreview? _preview;
  String? _paymentOrderId;
  bool _isLoadingPreview = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _razorpayService.init(
      onSuccess: _onPaymentSuccess,
      onFailure: _onPaymentFailure,
    );
    _loadPreview();
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoadingPreview = true;
      _errorMessage = null;
    });

    try {
      final preview = await _subscriptionRepository.previewUpgrade(
        planRef: widget.planRef,
        billingPeriod: widget.billingPeriod,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _isLoadingPreview = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoadingPreview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load upgrade preview. Please try again.';
        _isLoadingPreview = false;
      });
    }
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
    final paymentOrderId = _paymentOrderId?.trim() ?? '';

    if (orderId.isEmpty ||
        paymentId.isEmpty ||
        signature.isEmpty ||
        paymentOrderId.isEmpty) {
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
      await _subscriptionRepository.verifyUpgradePayment(
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        paymentOrderId: paymentOrderId,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Upgrade screen is a root route (outside HomeScreen's BlocProvider), so
      // return to home on the subscription tab to load the updated plan.
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.homeScreen,
        (route) => false,
        arguments: SubscriptionTabWidget.subscriptionTabIndex,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message ?? 'Payment cancelled or failed'),
      ),
    );
  }

  Future<void> _payAndUpgrade() async {
    if (_isProcessing || widget.planRef.isEmpty) return;

    final canProceed = await ProfileOrderGuard.ensureCompleteProfile(context);
    if (!canProceed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final order = await _subscriptionRepository.createUpgradeOrder(
        planRef: widget.planRef,
        billingPeriod: widget.billingPeriod,
      );

      _paymentOrderId = order.paymentOrderId;
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
        amount: order.amountInPaise,
        currency: order.currency,
        name: order.customerName ?? customer?.fullName,
        email: order.customerEmail ?? customer?.email,
        contact: order.customerContact ?? customer?.mobile,
        description: '${widget.planTitle} Upgrade',
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

  @override
  Widget build(BuildContext context) {
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
          'Upgrade Plan',
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
        child: _isLoadingPreview
            ? Center(
                child: CircularProgressIndicator(color: AppColours.primary),
              )
            : _errorMessage != null
                ? _buildError()
                : _buildContent(_preview!),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: CustomTextStyles.openSansRegular.copyWith(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadPreview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColours.primary,
              ),
              child: Text(
                'Retry',
                style: CustomTextStyles.openSansSemiBold.copyWith(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatNum(num amount) {
    if (amount % 1 == 0) {
      return PlanPriceFormatter.format(amount.toInt());
    } else {
      final integerPart = amount.toInt();
      final decimalPart = (amount - integerPart)
          .toStringAsFixed(2)
          .substring(2)
          .replaceAll(RegExp(r'0+$'), '');
      return '${PlanPriceFormatter.format(integerPart)}.$decimalPart';
    }
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
  }

  String _remainingText(SubscriptionUpgradeProration proration) {
    if (proration.prorationType == 'days') {
      return '${proration.remainingDays} of ${proration.totalDays} days remaining';
    }
    return '${proration.remainingBookings} of ${proration.totalBookings} bookings remaining';
  }

  String _buildCalculationExplanation(SubscriptionUpgradePreview preview) {
    final newAmt = _formatNum(preview.newPlan.planAmount);
    final creditAmt = _formatNum(preview.proration.creditAmount);
    final upgradeAmt = _formatNum(preview.proration.upgradeAmount);

    return 'Plan price difference (₹$newAmt − ₹$creditAmt) = ₹$upgradeAmt. Your unused subscription credit is applied toward the upgrade.';
  }

  String _buildInfoNote(SubscriptionUpgradePreview preview) {
    final currentPlan = preview.currentSubscription.planName;
    final newPlan = preview.newPlan.planName;
    final creditAmt = _formatNum(preview.proration.creditAmount);

    return 'Your current $currentPlan subscription credit (₹$creditAmt) is deducted directly. Your new $newPlan plan starts immediately.';
  }

  Widget _buildContent(SubscriptionUpgradePreview preview) {
    final proration = preview.proration;
    final currentSub = preview.currentSubscription;
    final newPlan = preview.newPlan;
    final periodText =
        newPlan.billingPeriod.toLowerCase() == 'yearly' ? 'year' : 'month';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Top Plan Header
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: AppColours.primary,
                      size: 18,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'PLAN UPGRADE',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 13.fSize,
                        color: AppColours.primary,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  newPlan.planName,
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 22.fSize,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${_capitalize(newPlan.billingPeriod)} Billing',
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 13.fSize,
                    color: Colors.white60,
                  ),
                ),
                SizedBox(height: 20.h),

                /// Unified Upgrade Summary Card
                Container(
                  width: double.maxFinite,
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16181D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColours.primary.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Current Plan Row
                      _buildComparisonRow(
                        label: 'Current Plan (${currentSub.planName})',
                        amount: '₹ ${_formatNum(currentSub.planAmount)}',
                        isAmountBold: true,
                      ),
                      SizedBox(height: 12.h),

                      /// Upgrade Plan Row
                      _buildComparisonRow(
                        label: 'Upgrade Plan (${newPlan.planName})',
                        amount: '₹ ${_formatNum(newPlan.planAmount)} / $periodText',
                        isAmountBold: true,
                      ),
                      SizedBox(height: 14.h),

                      /// Unused Credit Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Unused Plan Credit (${_remainingText(proration)})',
                              style: CustomTextStyles.openSansRegular.copyWith(
                                fontSize: 12.fSize,
                                color: const Color(0xFF2EC4B6),
                                height: 1.3,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            '- ₹ ${_formatNum(proration.creditAmount)}',
                            style: CustomTextStyles.montserratBold.copyWith(
                              fontSize: 13.fSize,
                              color: const Color(0xFF2EC4B6),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Divider(
                        color: AppColours.primary.withOpacity(0.25),
                        thickness: 0.8,
                      ),
                      SizedBox(height: 16.h),

                      /// Additional Amount Payable Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Additional Amount Payable',
                                  style: CustomTextStyles.montserratBold.copyWith(
                                    fontSize: 14.fSize,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  _buildCalculationExplanation(preview),
                                  style: CustomTextStyles.openSansRegular.copyWith(
                                    fontSize: 11.fSize,
                                    color: Colors.white54,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            '₹ ${_formatNum(proration.upgradeAmount)}',
                            style: CustomTextStyles.montserratBold.copyWith(
                              fontSize: 22.fSize,
                              color: AppColours.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                /// User-Friendly Information Note Box
                Container(
                  width: double.maxFinite,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16181D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColours.primary.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3.w,
                        height: 38.h,
                        decoration: BoxDecoration(
                          color: AppColours.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _buildInfoNote(preview),
                          style: CustomTextStyles.openSansRegular.copyWith(
                            fontSize: 12.fSize,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),

        /// Bottom PAY & UPGRADE Action
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
          child: SizedBox(
            width: double.maxFinite,
            height: 52.h,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _payAndUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColours.primary,
                disabledBackgroundColor: AppColours.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
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
                      'PAY ₹${_formatNum(proration.upgradeAmount)} & UPGRADE',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 15.fSize,
                        color: Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String amount,
    bool isAmountBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 13.fSize,
              color: Colors.white70,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          amount,
          style: isAmountBold
              ? CustomTextStyles.montserratBold.copyWith(
                  fontSize: 13.fSize,
                  color: Colors.white,
                )
              : CustomTextStyles.openSansSemiBold.copyWith(
                  fontSize: 13.fSize,
                  color: Colors.white,
                ),
        ),
      ],
    );
  }
}
