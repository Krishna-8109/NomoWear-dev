class InitiateOrderResult {
  const InitiateOrderResult({
    required this.orderId,
    this.orderNumber = '',
    required this.status,
    this.razorpayOrderId,
    this.razorpayKeyId,
    this.amount = 0,
    this.currency = 'INR',
    this.isSubscriptionBooking,
    this.subscriptionGarments = 0,
    this.paidItemsCount = 0,
    this.payableAmountRupees = 0,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String? razorpayOrderId;
  final String? razorpayKeyId;

  /// Razorpay amount in paise.
  final int amount;
  final String currency;

  /// Backend mixed-cart flag. Null when older payloads omit it.
  final bool? isSubscriptionBooking;
  final int subscriptionGarments;
  final int paidItemsCount;

  /// Initiate `amount` / `summary.payableAmount` in rupees.
  final double payableAmountRupees;

  bool get requiresPayment =>
      razorpayOrderId != null && razorpayOrderId!.trim().isNotEmpty;

  bool get isConfirmed {
    final normalized = status.trim().toUpperCase();
    return normalized == 'CONFIRMED' ||
        normalized == 'SUCCESS' ||
        normalized == 'COMPLETED';
  }

  bool get isMixedCart =>
      subscriptionGarments > 0 && paidItemsCount > 0;

  /// Free subscription booking only when backend says so and payment is absent.
  bool get isFreeSubscriptionBooking =>
      isSubscriptionBooking == true && !requiresPayment && amount <= 0;

  bool get canOpenRazorpay =>
      requiresPayment &&
      razorpayKeyId != null &&
      razorpayKeyId!.trim().isNotEmpty &&
      amount > 0;

  int get displayRupees {
    if (payableAmountRupees > 0) return payableAmountRupees.round();
    if (amount <= 0) return 0;
    return (amount / 100).round();
  }

  factory InitiateOrderResult.fromJson(Map<String, dynamic> json) {
    final order = _asMap(json['order']);
    final payment = _asMap(json['payment']);
    final razorpay = _asMap(json['razorpay']);
    final summary = _asMap(json['summary']);
    final sources = [payment, razorpay, json, order, summary];

    final rupeesRaw = _pickDynamic(
      [summary, order, json, payment, razorpay],
      const [
        'payableAmount',
        'payable_amount',
        'totalAmount',
        'total_amount',
        'amount',
      ],
    );
    final payableRupees = _parseRupeesValue(rupeesRaw);

    final paymentAmountRaw = _pickDynamic(
      [payment, razorpay],
      const ['amount', 'payableAmount', 'payable_amount'],
    );

    int amountPaise = 0;
    if (paymentAmountRaw != null) {
      final parsedPayment = _parseRupeesValue(paymentAmountRaw);
      if (payableRupees > 0 && parsedPayment == payableRupees * 100) {
        amountPaise = parsedPayment.round();
      } else if (payableRupees > 0) {
        amountPaise = (payableRupees * 100).round();
      } else {
        amountPaise = (parsedPayment * 100).round();
      }
    } else if (payableRupees > 0) {
      amountPaise = (payableRupees * 100).round();
    }

    return InitiateOrderResult(
      orderId: _pickString(
        [order, json],
        const ['orderId', 'order_id', 'id'],
      ),
      orderNumber: _pickString(
        [order, json],
        const ['orderNumber', 'order_number'],
      ),
      status: _pickString(
        [order, json],
        const ['status', 'orderStatus', 'order_status'],
      ),
      razorpayOrderId: _pickString(
        sources,
        const ['razorpayOrderId', 'razorpay_order_id'],
      ),
      razorpayKeyId: _pickString(
        sources,
        const [
          'razorpayKeyId',
          'razorpay_key_id',
          'key_id',
          'keyId',
        ],
      ),
      amount: amountPaise,
      currency: _pickString(
        sources,
        const ['currency'],
        fallback: 'INR',
      ),
      isSubscriptionBooking: _pickBool(
        [json, order, summary],
        const [
          'isSubscriptionBooking',
          'is_subscription_booking',
        ],
      ),
      subscriptionGarments: _pickInt(
        [summary, json],
        const ['subscriptionGarments', 'subscription_garments'],
      ),
      paidItemsCount: _pickInt(
        [summary, json],
        const ['paidItemsCount', 'paid_items_count'],
      ),
      payableAmountRupees: payableRupees,
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String _pickString(
  List<Map<String, dynamic>?> maps,
  List<String> keys, {
  String fallback = '',
}) {
  for (final map in maps) {
    if (map == null) continue;
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
  }
  return fallback;
}

dynamic _pickDynamic(List<Map<String, dynamic>?> maps, List<String> keys) {
  for (final map in maps) {
    if (map == null) continue;
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return map[key];
      }
    }
  }
  return null;
}

bool? _pickBool(List<Map<String, dynamic>?> maps, List<String> keys) {
  final value = _pickDynamic(maps, keys);
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

int _pickInt(List<Map<String, dynamic>?> maps, List<String> keys) {
  final value = _pickDynamic(maps, keys);
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    final cleaned = value.trim().replaceAll(',', '');
    return int.tryParse(cleaned) ?? (double.tryParse(cleaned)?.round() ?? 0);
  }
  return 0;
}

double _parseRupeesValue(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final cleaned = value.trim().replaceAll(',', '');
    final parsed = double.tryParse(cleaned);
    if (parsed != null) return parsed;
    final digitsOnly = cleaned.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(digitsOnly) ?? 0;
  }
  return 0;
}
