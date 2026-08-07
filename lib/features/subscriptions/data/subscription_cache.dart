import 'package:nomowear/features/subscriptions/data/models/active_subscription.dart';

class SubscriptionCache {
  SubscriptionCache._();

  static final SubscriptionCache instance = SubscriptionCache._();

  ActiveSubscription? _activeSubscription;
  int? _remainingGarmentsBalance;

  ActiveSubscription? get activeSubscription => _activeSubscription;

  /// Last resolved remaining garments for subscription booking validation.
  int? get remainingGarmentsBalance => _remainingGarmentsBalance;

  void setActiveSubscription(ActiveSubscription? subscription) {
    final previousId = _activeSubscription?.id;
    _activeSubscription = subscription;

    if (subscription == null) {
      _remainingGarmentsBalance = null;
      return;
    }

    // New subscription id → drop stale remaining from a previous plan.
    if (previousId != null && previousId != subscription.id) {
      _remainingGarmentsBalance = null;
    }

    final fromApi = subscription.apiRemainingGarments;
    if (fromApi != null) {
      _remainingGarmentsBalance = fromApi;
      return;
    }

    // Fresh plan with no bookings used → full garment balance immediately.
    final used = subscription.bookingsUsed;
    if (used != null && used <= 0 && subscription.maxGarments > 0) {
      _remainingGarmentsBalance = subscription.maxGarments;
    }
  }

  void setRemainingGarmentsBalance(int? remaining) {
    _remainingGarmentsBalance = remaining;
  }

  void clear() {
    _activeSubscription = null;
    _remainingGarmentsBalance = null;
  }
}
