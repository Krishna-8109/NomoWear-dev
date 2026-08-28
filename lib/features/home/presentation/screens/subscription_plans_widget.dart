import 'package:flutter/material.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/plans/data/models/plan_category.dart';
import 'package:nomowear/features/plans/data/models/wardrobe_plan.dart';
import 'package:nomowear/features/plans/data/plan_price_formatter.dart';
import 'package:nomowear/features/plans/data/plan_repository.dart';
import 'package:nomowear/features/subscriptions/data/models/active_subscription.dart';

class SubscriptionPlansWidget extends StatefulWidget {
  final PlanCategory category;
  final VoidCallback onBack;
  final ActiveSubscription? currentSubscription;

  const SubscriptionPlansWidget({
    Key? key,
    required this.category,
    required this.onBack,
    this.currentSubscription,
  }) : super(key: key);

  @override
  State<SubscriptionPlansWidget> createState() =>
      _SubscriptionPlansWidgetState();
}

class _SubscriptionPlansWidgetState extends State<SubscriptionPlansWidget> {
  final PlanRepository _planRepository = PlanRepository();

  List<WardrobePlan> _plans = [];
  bool _isLoading = true;
  bool _isYearlyTab = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (widget.category.plans.isNotEmpty) {
      if (mounted) {
        setState(() {
          _plans = widget.category.plans;
          _isLoading = false;
        });
      }
      // Refresh in background so plan ids stay in sync with backend.
      _refreshPlansFromApi();
      return;
    }

    await _refreshPlansFromApi();
  }

  Future<void> _refreshPlansFromApi() async {
    try {
      final plans = await _planRepository.getPlansByCategoryId(
        widget.category.id,
        forceRefresh: false,
      );
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<WardrobePlan> get _visiblePlans {
    if (_plans.isEmpty) return _plans;
    return _plans.where((plan) {
      if (plan.billingPeriod.isNotEmpty) {
        final isPlanYearly = plan.billingPeriod.toLowerCase().contains('year');
        return isPlanYearly == _isYearlyTab;
      }
      final price = _isYearlyTab ? plan.yearPrice : plan.monthPrice;
      return price > 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          children: [
            SizedBox(height: 20.h),
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Icon(Icons.arrow_back, color: AppColours.primary),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.category.name,
                      style: CustomTextStyles.openSansSemiBold.copyWith(
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(width: 24.w),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              height: 2,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE6C27A).withOpacity(0.15),
                    Color(0xFFE6C27A),
                    Color(0xFFE6C27A).withOpacity(0.15),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isYearlyTab = false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: !_isYearlyTab
                            ? AppColours.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: !_isYearlyTab
                              ? Colors.transparent
                              : AppColours.primary.withOpacity(0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "Monthly Plans",
                          style: TextStyle(
                            color: !_isYearlyTab
                                ? Colors.black
                                : AppColours.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isYearlyTab = true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: _isYearlyTab
                            ? AppColours.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isYearlyTab
                              ? Colors.transparent
                              : AppColours.primary.withOpacity(0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "Yearly Plans",
                          style: TextStyle(
                            color: _isYearlyTab
                                ? Colors.black
                                : AppColours.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            if (_isLoading)
              const PlanGridShimmer()
            else if (_visiblePlans.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Text(
                  'No plans available for this membership.',
                  textAlign: TextAlign.center,
                  style: CustomTextStyles.openSansRegular.copyWith(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              )
            else
              _plansGrid(),
            SizedBox(height: 32.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Key Terms & Conditions",
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 16,
                  color: AppColours.primary,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            _bullet(
              "Subscription usage is defined by fixed days and bookings.",
            ),
            _bullet(
              "Bookings can be used across all wardrobe categories;\nPremium & Professional garments are subject to fair-use limits",
            ),
            _bullet(
              "New garments are optional paid add-ons and not included by default.",
            ),
            _bullet(
              "No security deposit is required; a valid auto-debit payment method is mandatory.",
            ),
            _bullet(
              "Normal wear and tear is free. Charges only apply for non-return, loss, or damage beyond repair.",
            ),
            _bullet(
              "Subscription remains active until all garments from the final booking are returned and cleared.",
            ),
            Divider(color: AppColours.primary, thickness: 0.2),
            Text(
              "Flexible wardrobe rentals with transparent and fair-use terms.\nUpgrade, downgrade or cancel anytime.",
              textAlign: TextAlign.center,
              style: CustomTextStyles.openSansRegular.copyWith(fontSize: 11),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _plansGrid() {
    final plans = _visiblePlans;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plans.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 0.91,
      ),
      itemBuilder: (context, index) => _card(plans[index]),
    );
  }

  Widget _card(WardrobePlan plan) {
    final priceValue = plan.price > 0
        ? plan.price
        : (_isYearlyTab ? plan.yearPrice : plan.monthPrice);
    final price = PlanPriceFormatter.format(priceValue);
    final periodStr = plan.billingPeriod.isNotEmpty
        ? (plan.billingPeriod.toLowerCase().contains('year') ? '/year' : '/month')
        : (_isYearlyTab ? "/year" : "/month");
    final features = plan.features;

    final current = widget.currentSubscription;
    final isUpgradeMode = current != null;
    final isCurrentPlan = isUpgradeMode &&
        (current.planRef == plan.id || current.planRef == plan.planRef);
    final currentPrice = num.tryParse(current?.planPrice ?? '') ?? 0;
    final canUpgrade = isUpgradeMode && !isCurrentPlan && priceValue > currentPrice;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColours.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            plan.name,
            style: CustomTextStyles.openSansSemiBold.copyWith(
              color: AppColours.primary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '₹ $price $periodStr',
            style: CustomTextStyles.openSansSemiBold.copyWith(
              color: AppColours.primary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 10.h),
          // Features grow upward; Spacer keeps Subscribe buttons aligned
          // across all cards even when feature line counts differ.
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: features
                      .map(
                        (feature) => Padding(
                          padding: EdgeInsets.only(bottom: 4.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: CustomTextStyles.openSansRegular.copyWith(
                                  fontSize: 10,
                                  color: AppColours.primary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: CustomTextStyles.openSansRegular.copyWith(
                                    fontSize: 10,
                                    color: AppColours.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          if (isCurrentPlan)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColours.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColours.primary.withOpacity(0.45),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check,
                    color: AppColours.primary,
                    size: 11.w,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Current plan',
                    style: CustomTextStyles.openSansSemiBold.copyWith(
                      color: AppColours.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (isUpgradeMode && !canUpgrade)
            Text(
              'Not available',
              style: CustomTextStyles.openSansSemiBold.copyWith(
                color: Colors.white38,
                fontSize: 10,
              ),
            )
          else
            SizedBox(
              height: 28.h,
              width: 100.w,
              child: ElevatedButton(
                onPressed: () {
                  final routeArgs = {
                    'title': plan.name,
                    'price': price,
                    'period': plan.billingPeriod.isNotEmpty
                        ? (plan.billingPeriod.toLowerCase().contains('year') ? 'year' : 'month')
                        : (_isYearlyTab ? 'year' : 'month'),
                    'billingPeriod': plan.billingPeriod.isNotEmpty
                        ? plan.billingPeriod
                        : (_isYearlyTab ? 'yearly' : 'monthly'),
                    'features': features,
                    'planRef': plan.id,
                    'planId': plan.id,
                    'categoryName': widget.category.name,
                  };

                  Navigator.pushNamed(
                    context,
                    canUpgrade
                        ? AppRoutes.membershipUpgradeScreen
                        : AppRoutes.membershipPurchaseScreen,
                    arguments: routeArgs,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColours.primary,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  canUpgrade ? 'Upgrade' : 'Subscribe',
                  style: CustomTextStyles.openSansSemiBold.copyWith(
                    color: AppColours.black,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: EdgeInsets.only(top: 6.h, right: 8.w),
            decoration: const BoxDecoration(
              color: AppColours.secondary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
