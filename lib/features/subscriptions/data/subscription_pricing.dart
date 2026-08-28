/// Subscription totals used by Plan Summary and payment.
///
/// Subtotal = Grand Total (No GST).
class SubscriptionPricing {
  const SubscriptionPricing({
    required this.subtotal,
    required this.grandTotal,
  });

  final double subtotal;
  final double grandTotal;

  factory SubscriptionPricing.fromPlanPrice(String priceString) {
    final cleanPrice =
        priceString.replaceAll(',', '').replaceAll('₹', '').trim();
    final subtotal = double.tryParse(cleanPrice) ?? 0.0;
    final grandTotal = subtotal;
    return SubscriptionPricing(
      subtotal: subtotal,
      grandTotal: grandTotal,
    );
  }

  int get subtotalPaise => (subtotal * 100).round();

  /// Amount in paise for Razorpay / create-order.
  int get amountInPaise => (grandTotal * 100).round();

  /// Prefer backend amount when it already matches; otherwise use plan amount.
  int razorpayAmountPaise(int backendAmount) {
    if (backendAmount <= 0) return amountInPaise;
    if (backendAmount == amountInPaise) return backendAmount;
    if (backendAmount == grandTotal.round()) return amountInPaise;
    return amountInPaise;
  }
}
