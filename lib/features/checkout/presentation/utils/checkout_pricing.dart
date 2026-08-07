import 'package:nomowear/features/cart/data/models/remote_cart.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/orders/data/models/initiate_order_result.dart';

/// Shared order totals for checkout and payment screens.
class OrderSummary {
  const OrderSummary({
    required this.subtotal,
    required this.gst,
    required this.deliveryFee,
    required this.total,
    required this.wardrobeKitAmount,
    required this.essentialsAmount,
  });

  final int subtotal;
  final int gst;
  final int deliveryFee;
  final int total;
  final int wardrobeKitAmount;
  final int essentialsAmount;
}

/// Backend-only payable snapshot: cart breakdown + order-initiate amount (Razorpay).
///
/// CHANGE: Single source of truth for checkout — [initiate.amount] is what the
/// gateway charges; [displayTotalRupees] is derived from that same value.
class CheckoutPayableSnapshot {
  const CheckoutPayableSnapshot({
    required this.remoteCart,
    required this.initiate,
    required this.summary,
    required this.gatewayAmountPaise,
    required this.displayTotalRupees,
  });

  final RemoteCart remoteCart;
  final InitiateOrderResult initiate;
  final OrderSummary summary;

  /// Paise amount passed to Razorpay.
  final int gatewayAmountPaise;

  /// Rupee total shown in Payment Summary (converted from gateway amount).
  final int displayTotalRupees;
}

/// Prefetched checkout payload prepared before navigating to checkout screen.
class CheckoutPrefetchPayload {
  const CheckoutPrefetchPayload({
    required this.snapshot,
    required this.cartFingerprint,
  });

  final CheckoutPayableSnapshot snapshot;
  final String cartFingerprint;
}

class CheckoutPricing {
  CheckoutPricing._();

  /// Rental price for the selected wardrobe kit (by days).
  static const Map<int, int> wardrobeKitPriceByDays = {
    1: 2499,
    3: 4499,
    5: 6499,
    7: 8499,
  };

  static int wardrobeKitPrice(int kitDays) =>
      wardrobeKitPriceByDays[kitDays] ?? wardrobeKitPriceByDays[1]!;

  static int wardrobeKitPriceFromState(CartState state) {
    final fallback = wardrobeKitPrice(state.wardrobeKitDays);
    final raw = state.wardrobeKitPrice;
    if (raw != null && raw.trim().isNotEmpty) {
      final digits = raw.replaceAll(RegExp(r'[^0-9.]'), '');
      if (digits.isNotEmpty) {
        final parsed = num.tryParse(digits);
        if (parsed != null) {
          final amount = parsed.round();
          // Ignore invalid API values (e.g. "1") and use catalog price by duration.
          if (amount >= 100) return amount;
        }
      }
    }
    return fallback;
  }

  static int parseItemPrice(String? rawPrice, {required bool isEssential}) {
    if (rawPrice == null || rawPrice.trim().isEmpty) {
      return isEssential ? 999 : 0;
    }
    final cleaned = rawPrice.trim();
    // Prefer decimal parse so "1999.0" / "₹ 1,999.50" stay accurate.
    final normalized = cleaned.replaceAll(',', '');
    final asNum = num.tryParse(normalized.replaceAll(RegExp(r'[^\d.]'), ''));
    if (asNum != null) return asNum.round();
    final digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? (isEssential ? 999 : 0);
  }

  static OrderSummary fromCartState(
    CartState state, {
    bool wardrobeCoveredBySubscription = false,
  }) {
    final wardrobeAmount = state.wardrobeItems.isNotEmpty &&
            !wardrobeCoveredBySubscription
        ? wardrobeKitPriceFromState(state)
        : 0;

    final essentialsAmount = state.essentialItems.fold<int>(
      0,
      (sum, item) =>
          sum +
          parseItemPrice(item.price, isEssential: true) * item.quantity,
    );

    final subtotal = wardrobeAmount + essentialsAmount;
    final gst = (subtotal * 0.18).round();
    final total = subtotal + gst;

    return OrderSummary(
      subtotal: subtotal,
      gst: gst,
      deliveryFee: 0,
      total: total,
      wardrobeKitAmount: wardrobeAmount,
      essentialsAmount: essentialsAmount,
    );
  }

  /// Converts order-initiate / Razorpay amount (paise) to rupees for UI display.
  static int rupeesFromGatewayAmount(int gatewayAmountPaise) {
    if (gatewayAmountPaise <= 0) return 0;
    return (gatewayAmountPaise / 100).round();
  }

  /// Builds checkout summary using backend cart lines and initiate-order total.
  ///
  /// Grand total always comes from [payableTotalRupees] (initiate-order amount),
  /// not from local math, so UI and Razorpay stay aligned.
  static CheckoutPayableSnapshot payableSnapshot({
    required RemoteCart remoteCart,
    required InitiateOrderResult initiate,
    required CartState cartState,
    bool wardrobeCoveredBySubscription = false,
  }) {
    final normalizedPayable = _normalizePayable(
      rawInitiateAmount: initiate.amount,
      remoteCart: remoteCart,
    );
    final payableTotalRupees = normalizedPayable.displayRupees;
    final wardrobeKitAmount = wardrobeCoveredBySubscription
        ? 0
        : wardrobeKitAmountFromRemote(
            remoteCart,
            cartState.wardrobeKitProductId ?? cartState.wardrobeKitId,
          );

    final remoteSubtotal = remoteCart.subtotal.round();
    final remoteGst = remoteCart.taxAmount.round();
    final derivedDelivery = payableTotalRupees - remoteSubtotal - remoteGst;
    final effectiveDelivery = remoteSubtotal > 0 && derivedDelivery > 0
        ? derivedDelivery
        : 0;
    final displaySubtotal = remoteSubtotal > 0
        ? payableTotalRupees - remoteGst - effectiveDelivery
        : payableTotalRupees;

    final summary = OrderSummary(
      subtotal: displaySubtotal > 0 ? displaySubtotal : 0,
      gst: remoteGst > 0 ? remoteGst : 0,
      deliveryFee: effectiveDelivery,
      total: payableTotalRupees,
      wardrobeKitAmount: wardrobeKitAmount,
      essentialsAmount: 0,
    );

    return CheckoutPayableSnapshot(
      remoteCart: remoteCart,
      initiate: initiate,
      summary: summary,
      gatewayAmountPaise: normalizedPayable.gatewayAmountPaise,
      displayTotalRupees: normalizedPayable.displayRupees,
    );
  }

  static _NormalizedPayable _normalizePayable({
    required int rawInitiateAmount,
    required RemoteCart remoteCart,
  }) {
    if (rawInitiateAmount <= 0) {
      return const _NormalizedPayable(gatewayAmountPaise: 0, displayRupees: 0);
    }

    final expectedRupees = <int>[
      remoteCart.subtotal.round(),
      remoteCart.totalAmount.round(),
    ].where((v) => v > 0).toList();

    if (expectedRupees.isEmpty) {
      if (rawInitiateAmount >= 10000) {
        return _NormalizedPayable(
          gatewayAmountPaise: rawInitiateAmount,
          displayRupees: rupeesFromGatewayAmount(rawInitiateAmount),
        );
      }
      return _NormalizedPayable(
        gatewayAmountPaise: rawInitiateAmount * 100,
        displayRupees: rawInitiateAmount,
      );
    }

    int closestDistance(int amountRupees) {
      var best = 1 << 30;
      for (final expected in expectedRupees) {
        final d = (amountRupees - expected).abs();
        if (d < best) best = d;
      }
      return best;
    }

    final asRupeesDistance = closestDistance(rawInitiateAmount);
    final asPaiseDistance =
        closestDistance(rupeesFromGatewayAmount(rawInitiateAmount));
    final isRupeeAmount = asRupeesDistance <= asPaiseDistance;

    if (isRupeeAmount) {
      return _NormalizedPayable(
        gatewayAmountPaise: rawInitiateAmount * 100,
        displayRupees: rawInitiateAmount,
      );
    }

    return _NormalizedPayable(
      gatewayAmountPaise: rawInitiateAmount,
      displayRupees: rupeesFromGatewayAmount(rawInitiateAmount),
    );
  }

  /// Wardrobe kit line total from synced backend cart (no local price table).
  static int wardrobeKitAmountFromRemote(
    RemoteCart cart,
    String? kitProductId,
  ) {
    final id = kitProductId?.trim();
    if (id == null || id.isEmpty) return 0;

    for (final item in cart.items) {
      if (item.productId == id) {
        final line = item.lineTotal.round();
        if (line > 0) return line;
        return (item.unitPrice * item.quantity).round();
      }
    }
    return 0;
  }

  /// Fingerprint of cart contents — reload payable snapshot when this changes.
  static String cartFingerprint(CartState state) {
    final parts = <String>[
      state.wardrobeKitId ?? '',
      state.wardrobeKitProductId ?? '',
      '${state.wardrobeKitDays}',
    ];
    for (final item in state.items) {
      parts.add('${item.id}|${item.quantity}|${item.selectedSize}');
    }
    return parts.join(';');
  }

  /// Prefer server cart totals when available; fall back to local pricing.
  ///
  /// NOTE: Checkout screen uses [payableSnapshot] instead — no local fallback.
  static OrderSummary resolveSummary(
    CartState state, {
    RemoteCart? remoteCart,
    bool wardrobeCoveredBySubscription = false,
  }) {
    final local = fromCartState(
      state,
      wardrobeCoveredBySubscription: wardrobeCoveredBySubscription,
    );

    if (wardrobeCoveredBySubscription || remoteCart == null) {
      return local;
    }

    final remoteSubtotal = remoteCart.subtotal.round();
    final remoteGst = remoteCart.taxAmount.round();
    final remoteTotal = remoteCart.totalAmount.round();

    if (remoteTotal >= 100) {
      return OrderSummary(
        subtotal: remoteSubtotal > 0 ? remoteSubtotal : local.subtotal,
        gst: remoteGst > 0 ? remoteGst : local.gst,
        deliveryFee: remoteCart.deliveryCharge.round(),
        total: remoteTotal,
        wardrobeKitAmount: local.wardrobeKitAmount,
        essentialsAmount: local.essentialsAmount,
      );
    }

    return local;
  }

  /// Instant Order Summary from local cart lines (qty × unit price).
  /// Used so Subtotal/Grand Total update immediately on quantity changes
  /// while the authoritative initiate-order snapshot reloads in the background.
  static OrderSummary fromLocalCartLines(CartState state) {
    var subtotal = 0;
    var essentialsAmount = 0;
    for (final item in state.items) {
      final line = parseItemPrice(
            item.price,
            isEssential: item.isEssential,
          ) *
          item.quantity;
      subtotal += line;
      if (item.isEssential) essentialsAmount += line;
    }

    return OrderSummary(
      subtotal: subtotal,
      gst: 0,
      deliveryFee: 0,
      total: subtotal,
      wardrobeKitAmount: 0,
      essentialsAmount: essentialsAmount,
    );
  }

  static String formatMoney(int value) {
    final asString = value.toString();
    final buffer = StringBuffer('₹');
    for (int i = 0; i < asString.length; i++) {
      final fromEnd = asString.length - i;
      buffer.write(asString[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _NormalizedPayable {
  const _NormalizedPayable({
    required this.gatewayAmountPaise,
    required this.displayRupees,
  });

  final int gatewayAmountPaise;
  final int displayRupees;
}
