import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/razorpay_service.dart';
import 'package:nomowear/features/home/presentation/screens/subscription_tab_widget.dart';
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

  Widget _buildContent(SubscriptionUpgradePreview preview) {
    final proration = preview.proration;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPGRADE SUMMARY',
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 14,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 16.h),
                _planCard(
                  title: 'Current plan',
                  planName: preview.currentSubscription.planName,
                  amount: preview.currentSubscription.amountLabel,
                ),
                SizedBox(height: 12.h),
                _planCard(
                  title: 'New plan',
                  planName: preview.newPlan.planName,
                  amount: preview.newPlan.amountLabel,
                  highlight: true,
                ),
                SizedBox(height: 32.h),
                Text(
                  'PRORATION',
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 14,
                    color: AppColours.primary,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 16.h),
                _summaryRow('Unused credit', '- ${proration.creditLabel}'),
                SizedBox(height: 12.h),
                if (proration.prorationType == 'days')
                  _summaryRow(
                    'Remaining days',
                    '${proration.remainingDays} of ${proration.totalDays}',
                  )
                else
                  _summaryRow(
                    'Remaining bookings',
                    '${proration.remainingBookings} of ${proration.totalBookings}',
                  ),
                SizedBox(height: 20.h),
                Divider(color: AppColours.primary, thickness: 0.2),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount due today',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      proration.upgradeLabel,
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
                      'PAY & UPGRADE',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 16,
                        color: Colors.black,
                        letterSpacing: 1.6,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _planCard({
    required String title,
    required String planName,
    required String amount,
    bool highlight = false,
  }) {
    return Container(
      width: double.maxFinite,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppColours.primary
              : AppColours.primary.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 12,
              color: AppColours.hintcolor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            planName,
            style: CustomTextStyles.montserratBold.copyWith(fontSize: 16),
          ),
          SizedBox(height: 4.h),
          Text(
            '$amount / ${widget.period}',
            style: CustomTextStyles.openSansSemiBold.copyWith(
              fontSize: 16,
              color: AppColours.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
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
          style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 14),
        ),
      ],
    );
  }
}
