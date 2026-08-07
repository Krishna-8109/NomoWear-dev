class InitiateOrderResult {
  const InitiateOrderResult({
    required this.orderId,
    this.orderNumber = '',
    required this.status,
    this.razorpayOrderId,
    this.razorpayKeyId,
    this.amount = 0,
    this.currency = 'INR',
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String? razorpayOrderId;
  final String? razorpayKeyId;
  final int amount;
  final String currency;

  bool get requiresPayment =>
      razorpayOrderId != null && razorpayOrderId!.trim().isNotEmpty;

  bool get isConfirmed {
    final normalized = status.trim().toUpperCase();
    return normalized == 'CONFIRMED' ||
        normalized == 'SUCCESS' ||
        normalized == 'COMPLETED';
  }

  bool get canOpenRazorpay =>
      requiresPayment &&
      razorpayKeyId != null &&
      razorpayKeyId!.trim().isNotEmpty &&
      amount > 0;

  factory InitiateOrderResult.fromJson(Map<String, dynamic> json) {
    final order = _asMap(json['order']);
    final payment = _asMap(json['payment']);
    final razorpay = _asMap(json['razorpay']);
    final sources = [payment, razorpay, json, order];

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
        const ['razorpayOrderId', 'razorpay_order_id', 'order_id'],
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
      amount: _parseAmount(
        _pickDynamic(sources, const ['amount', 'totalAmount', 'total_amount']),
      ),
      currency: _pickString(
        sources,
        const ['currency'],
        fallback: 'INR',
      ),
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

int _parseAmount(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.contains('.')) {
      final rupees = double.tryParse(trimmed.replaceAll(',', ''));
      if (rupees != null) return (rupees * 100).round();
    }
    return int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }
  return 0;
}
