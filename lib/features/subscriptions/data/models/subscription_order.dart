class SubscriptionOrder {
  const SubscriptionOrder({
    required this.subscriptionId,
    required this.razorpayOrderId,
    required this.razorpayKeyId,
    required this.amount,
    required this.currency,
  });

  final String subscriptionId;
  final String razorpayOrderId;
  final String razorpayKeyId;
  final int amount;
  final String currency;

  factory SubscriptionOrder.fromJson(Map<String, dynamic> json) {
    return SubscriptionOrder(
      subscriptionId: json['subscriptionId']?.toString() ??
          json['subscription_id']?.toString() ??
          '',
      razorpayOrderId: json['razorpayOrderId']?.toString() ??
          json['razorpay_order_id']?.toString() ??
          '',
      razorpayKeyId: json['razorpayKeyId']?.toString() ??
          json['razorpay_key_id']?.toString() ??
          '',
      amount: _parseAmount(
        json['totalAmount'] ??
            json['total_amount'] ??
            json['payableAmount'] ??
            json['payable_amount'] ??
            json['grandTotal'] ??
            json['grand_total'] ??
            json['amount'],
      ),
      currency: json['currency']?.toString() ?? 'INR',
    );
  }

  static int _parseAmount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
