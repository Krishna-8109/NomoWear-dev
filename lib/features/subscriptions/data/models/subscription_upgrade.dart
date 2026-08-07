import 'package:nomowear/features/plans/data/plan_price_formatter.dart';

class SubscriptionUpgradeProration {
  const SubscriptionUpgradeProration({
    required this.creditAmount,
    required this.upgradeAmount,
    required this.remainingDays,
    required this.totalDays,
    required this.remainingBookings,
    required this.totalBookings,
    required this.prorationType,
    this.currentPlanAmount,
    this.newPlanAmount,
  });

  final num creditAmount;
  final num upgradeAmount;
  final int remainingDays;
  final int totalDays;
  final int remainingBookings;
  final int totalBookings;
  final String prorationType;
  final num? currentPlanAmount;
  final num? newPlanAmount;

  factory SubscriptionUpgradeProration.fromJson(Map<String, dynamic> json) {
    return SubscriptionUpgradeProration(
      creditAmount: _num(json['creditAmount'] ?? json['credit_amount']) ?? 0,
      upgradeAmount: _num(json['upgradeAmount'] ?? json['upgrade_amount']) ?? 0,
      remainingDays:
          _int(json['remainingDays'] ?? json['remaining_days']) ?? 0,
      totalDays: _int(json['totalDays'] ?? json['total_days']) ?? 0,
      remainingBookings:
          _int(json['remainingBookings'] ?? json['remaining_bookings']) ?? 0,
      totalBookings:
          _int(json['totalBookings'] ?? json['total_bookings']) ?? 0,
      prorationType: json['prorationType']?.toString() ??
          json['proration_type']?.toString() ??
          'days',
      currentPlanAmount:
          _num(json['currentPlanAmount'] ?? json['current_plan_amount']),
      newPlanAmount: _num(json['newPlanAmount'] ?? json['new_plan_amount']),
    );
  }

  String get creditLabel => '₹${PlanPriceFormatter.format(creditAmount)}';

  String get upgradeLabel => '₹${PlanPriceFormatter.format(upgradeAmount)}';
}

class SubscriptionUpgradePlanSummary {
  const SubscriptionUpgradePlanSummary({
    required this.id,
    required this.planName,
    required this.planAmount,
    required this.billingPeriod,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String planName;
  final num planAmount;
  final String billingPeriod;
  final String? startDate;
  final String? endDate;

  factory SubscriptionUpgradePlanSummary.fromJson(Map<String, dynamic> json) {
    return SubscriptionUpgradePlanSummary(
      id: json['id']?.toString() ?? '',
      planName: json['planName']?.toString() ??
          json['plan_name']?.toString() ??
          '',
      planAmount: _num(json['planAmount'] ?? json['plan_amount']) ?? 0,
      billingPeriod: json['billingPeriod']?.toString() ??
          json['billing_period']?.toString() ??
          'monthly',
      startDate: _nonEmpty(json['startDate'] ?? json['start_date']),
      endDate: _nonEmpty(json['endDate'] ?? json['end_date']),
    );
  }

  String get amountLabel => '₹${PlanPriceFormatter.format(planAmount)}';
}

class SubscriptionUpgradePreview {
  const SubscriptionUpgradePreview({
    required this.currentSubscription,
    required this.newPlan,
    required this.proration,
  });

  final SubscriptionUpgradePlanSummary currentSubscription;
  final SubscriptionUpgradePlanSummary newPlan;
  final SubscriptionUpgradeProration proration;

  factory SubscriptionUpgradePreview.fromJson(Map<String, dynamic> json) {
    final currentRaw = json['currentSubscription'] ?? json['current_subscription'];
    final newPlanRaw = json['newPlan'] ?? json['new_plan'];
    final prorationRaw = json['proration'];

    if (currentRaw is! Map || newPlanRaw is! Map || prorationRaw is! Map) {
      throw const FormatException('Invalid upgrade preview response');
    }

    return SubscriptionUpgradePreview(
      currentSubscription: SubscriptionUpgradePlanSummary.fromJson(
        Map<String, dynamic>.from(currentRaw),
      ),
      newPlan: SubscriptionUpgradePlanSummary.fromJson(
        Map<String, dynamic>.from(newPlanRaw),
      ),
      proration: SubscriptionUpgradeProration.fromJson(
        Map<String, dynamic>.from(prorationRaw),
      ),
    );
  }
}

class SubscriptionUpgradeOrder {
  const SubscriptionUpgradeOrder({
    required this.paymentOrderId,
    required this.razorpayOrderId,
    required this.razorpayKeyId,
    required this.amount,
    required this.currency,
    required this.planName,
    required this.billingPeriod,
    required this.proration,
    this.purpose = 'upgrade',
    this.customerName,
    this.customerEmail,
    this.customerContact,
  });

  final String paymentOrderId;
  final String razorpayOrderId;
  final String razorpayKeyId;
  final num amount;
  final String currency;
  final String planName;
  final String billingPeriod;
  final String purpose;
  final SubscriptionUpgradeProration proration;
  final String? customerName;
  final String? customerEmail;
  final String? customerContact;

  int get amountInPaise => (amount * 100).round();

  factory SubscriptionUpgradeOrder.fromJson(Map<String, dynamic> json) {
    final prorationRaw = json['proration'];
    final customerRaw = json['customer'];

    return SubscriptionUpgradeOrder(
      paymentOrderId: json['paymentOrderId']?.toString() ??
          json['payment_order_id']?.toString() ??
          '',
      razorpayOrderId: json['razorpayOrderId']?.toString() ??
          json['razorpay_order_id']?.toString() ??
          '',
      razorpayKeyId: json['razorpayKeyId']?.toString() ??
          json['razorpay_key_id']?.toString() ??
          '',
      amount: _num(json['amount']) ?? 0,
      currency: json['currency']?.toString() ?? 'INR',
      planName: json['planName']?.toString() ??
          json['plan_name']?.toString() ??
          '',
      billingPeriod: json['billingPeriod']?.toString() ??
          json['billing_period']?.toString() ??
          'monthly',
      purpose: json['purpose']?.toString() ?? 'upgrade',
      proration: prorationRaw is Map
          ? SubscriptionUpgradeProration.fromJson(
              Map<String, dynamic>.from(prorationRaw),
            )
          : const SubscriptionUpgradeProration(
              creditAmount: 0,
              upgradeAmount: 0,
              remainingDays: 0,
              totalDays: 0,
              remainingBookings: 0,
              totalBookings: 0,
              prorationType: 'days',
            ),
      customerName: customerRaw is Map
          ? _nonEmpty(customerRaw['name'])
          : null,
      customerEmail: customerRaw is Map
          ? _nonEmpty(customerRaw['email'])
          : null,
      customerContact: customerRaw is Map
          ? _nonEmpty(customerRaw['contact'])
          : null,
    );
  }
}

num? _num(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
