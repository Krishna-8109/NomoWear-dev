import 'package:flutter/foundation.dart';
import 'package:nomowear/features/orders/data/models/order_history.dart';
import 'package:nomowear/features/orders/data/order_repository.dart';
import 'package:nomowear/features/subscriptions/data/models/active_subscription.dart';
import 'package:nomowear/features/subscriptions/data/subscription_cache.dart';
import 'package:nomowear/features/subscriptions/data/subscription_repository.dart';

/// Resolves remaining subscription garments for the current booking period.
///
/// Preference order:
/// 1. Explicit API `remainingGarments` / `usedGarments`
/// 2. Full [maxGarments] when no bookings have been used yet (new subscription)
/// 3. `maxGarments - sum(subscription orders in this plan period)` only when a
///    reliable period start exists
class SubscriptionGarmentBalance {
  SubscriptionGarmentBalance._();

  static const bool _kDebug = true;

  static void _log(String message) {
    if (_kDebug && kDebugMode) {
      debugPrint('[SUB_GARMENTS] $message');
    }
  }

  /// Sync read of last resolved remaining garments (for cart validation).
  static int? get cachedRemaining =>
      SubscriptionCache.instance.remainingGarmentsBalance;

  /// Clears cached remaining balance (e.g. logout).
  static void clearCache() {
    SubscriptionCache.instance.setRemainingGarmentsBalance(null);
  }

  /// Effective cart/kit garment cap for a subscription booking.
  ///
  /// When [remainingGarments] is null, the subscription balance is unknown and
  /// only the wardrobe kit max is applied.
  static int allowedGarmentsForBooking({
    required int kitMaxItems,
    int? remainingGarments,
  }) {
    final kitMax = kitMaxItems < 0 ? 0 : kitMaxItems;
    final remaining = remainingGarments ?? cachedRemaining;
    if (remaining == null) return kitMax;
    if (remaining <= 0) return 0;
    return kitMax < remaining ? kitMax : remaining;
  }

  /// Refresh subscription + remaining garments and cache the result.
  ///
  /// Returns `null` when there is no active subscription / balance is unknown
  /// (caller must not treat that as "0 remaining").
  static Future<int?> resolveAndCache({
    SubscriptionRepository? subscriptionRepository,
    OrderRepository? orderRepository,
    bool forceRefresh = true,
  }) async {
    final subscriptions = subscriptionRepository ?? SubscriptionRepository();
    final orders = orderRepository ?? OrderRepository();

    ActiveSubscription? active;
    try {
      active = await subscriptions.getActiveSubscription(
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      active = SubscriptionCache.instance.activeSubscription;
    }

    if (active == null || !active.isActive) {
      _log('no active subscription — clear remaining cache');
      SubscriptionCache.instance.setRemainingGarmentsBalance(null);
      return null;
    }

    final max = active.maxGarments < 0 ? 0 : active.maxGarments;
    _log(
      'active=${active.id} plan=${active.planName} maxGarments=$max '
      'bookingsUsed=${active.bookingsUsed} '
      'remainingBookings=${active.remainingBookings} '
      'apiRemaining=${active.remainingGarments} '
      'apiUsed=${active.usedGarments} '
      'start=${active.startDate} created=${active.createdAt}',
    );

    if (max <= 0) {
      SubscriptionCache.instance.setRemainingGarmentsBalance(0);
      return 0;
    }

    // 1) Trust explicit garment fields from API when present.
    final fromApi = active.apiRemainingGarments;
    if (fromApi != null) {
      _log('using API remaining=$fromApi');
      SubscriptionCache.instance.setRemainingGarmentsBalance(fromApi);
      return fromApi;
    }

    // 2) Brand-new / unused subscription → full garment balance.
    //    Do NOT subtract historical orders from a previous plan.
    if (_hasUnusedBookings(active)) {
      _log('unused bookings — remaining=full max=$max');
      SubscriptionCache.instance.setRemainingGarmentsBalance(max);
      return max;
    }

    // 3) Derive from orders only when we know when this subscription started.
    final start = _periodStart(active);
    if (start == null) {
      _log('no period start — remaining=full max=$max (avoid over-count)');
      SubscriptionCache.instance.setRemainingGarmentsBalance(max);
      return max;
    }

    List<OrderHistoryItem> history = const [];
    try {
      history = await orders.getOrderHistory(forceRefresh: forceRefresh);
    } catch (e) {
      _log('order history failed ($e) — remaining=full max=$max');
      SubscriptionCache.instance.setRemainingGarmentsBalance(max);
      return max;
    }

    final used = usedGarmentsFromOrders(active, history);
    final remaining = (max - used).clamp(0, max);
    _log('from orders used=$used remaining=$remaining (max=$max start=$start)');
    SubscriptionCache.instance.setRemainingGarmentsBalance(remaining);
    return remaining;
  }

  /// True when the customer has not consumed any booking on this plan yet.
  static bool _hasUnusedBookings(ActiveSubscription subscription) {
    final used = subscription.bookingsUsed;
    if (used != null) return used <= 0;

    final remaining = subscription.remainingBookings;
    if (remaining != null && subscription.noOfBookings > 0) {
      return remaining >= subscription.noOfBookings;
    }

    // Unknown booking usage — treat as unused only when remainingBookings /
    // bookingsUsed are absent AND we have no period start to safely attribute
    // orders. Handled by caller via period-start check.
    return false;
  }

  static DateTime? _periodStart(ActiveSubscription subscription) {
    return _parseDate(subscription.startDate) ??
        _parseDate(subscription.createdAt);
  }

  /// Sums wardrobe garments from prior subscription bookings in the plan period.
  static int usedGarmentsFromOrders(
    ActiveSubscription subscription,
    List<OrderHistoryItem> orders,
  ) {
    final start = _periodStart(subscription);
    final end = _parseDate(subscription.endDate);

    // Without a start boundary, never attribute historical orders to this plan.
    if (start == null) return 0;

    var total = 0;
    for (final order in orders) {
      if (!_countsTowardSubscriptionUsage(order)) continue;
      if (!_inSubscriptionPeriod(order.createdAt, start: start, end: end)) {
        continue;
      }
      total += garmentCountForOrder(order);
    }
    return total;
  }

  static int garmentCountForOrder(OrderHistoryItem order) {
    final items = order.orderItems;
    if (items.isEmpty) return 0;

    var count = 0;
    var countedAny = false;
    for (final item in items) {
      if (_isKitProductLine(item)) continue;
      countedAny = true;
      count += item.quantity < 0 ? 0 : item.quantity;
    }

    // Fallback: if API only returned kit lines, avoid under-counting to zero.
    if (!countedAny) {
      return items.fold<int>(
        0,
        (sum, item) => sum + (item.quantity < 0 ? 0 : item.quantity),
      );
    }
    return count;
  }

  static bool _countsTowardSubscriptionUsage(OrderHistoryItem order) {
    if (!order.isSubscription) return false;
    final status = order.orderStatus?.trim().toUpperCase() ?? '';
    if (status == 'CANCELLED' ||
        status == 'CANCELED' ||
        status == 'FAILED' ||
        status == 'REFUNDED' ||
        status == 'REJECTED') {
      return false;
    }
    return true;
  }

  static bool _inSubscriptionPeriod(
    DateTime? createdAt, {
    required DateTime start,
    DateTime? end,
  }) {
    if (createdAt == null) return false;
    if (createdAt.isBefore(start)) return false;
    if (end != null && createdAt.isAfter(end)) return false;
    return true;
  }

  static bool _isKitProductLine(OrderHistoryLineItem item) {
    final pc = item.productClass?.trim().toLowerCase() ?? '';
    if (pc.contains('wardrobe_kit') || pc == 'kit') return true;
    final name = item.productName?.trim().toLowerCase() ?? '';
    return name.contains('wardrobe kit');
  }

  static DateTime? _parseDate(String? iso) {
    final raw = iso?.trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
