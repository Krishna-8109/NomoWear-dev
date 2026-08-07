import 'package:nomowear/features/subscriptions/data/models/active_subscription.dart';
import 'package:nomowear/features/subscriptions/data/subscription_garment_balance.dart';
import 'package:nomowear/features/subscriptions/data/subscription_repository.dart';

enum SubscriptionBookingUnavailableReason {
  none,
  notLoggedIn,
  noActiveSubscription,
  bookingsExhausted,
  garmentsExhausted,
}

class SubscriptionBookingEligibility {
  const SubscriptionBookingEligibility({
    required this.canBookWithSubscription,
    this.subscription,
    this.reason = SubscriptionBookingUnavailableReason.none,
  });

  final bool canBookWithSubscription;
  final ActiveSubscription? subscription;
  final SubscriptionBookingUnavailableReason reason;

  String get unavailableMessage {
    switch (reason) {
      case SubscriptionBookingUnavailableReason.noActiveSubscription:
        return 'You do not have an active subscription.';
      case SubscriptionBookingUnavailableReason.bookingsExhausted:
        return 'Your subscription booking limit has been reached for this period.';
      case SubscriptionBookingUnavailableReason.garmentsExhausted:
        return 'Your subscription garment limit has been reached for this period.';
      case SubscriptionBookingUnavailableReason.notLoggedIn:
        return 'Please log in to use your subscription.';
      case SubscriptionBookingUnavailableReason.none:
        return 'Subscription is unavailable for this booking.';
    }
  }

  static Future<SubscriptionBookingEligibility> check({
    SubscriptionRepository? repository,
    bool forceRefresh = true,
  }) async {
    final subscriptionRepository = repository ?? SubscriptionRepository();

    try {
      final active = await subscriptionRepository.getActiveSubscription(
        forceRefresh: forceRefresh,
      );

      if (active == null || !active.isActive) {
        return const SubscriptionBookingEligibility(
          canBookWithSubscription: false,
          reason: SubscriptionBookingUnavailableReason.noActiveSubscription,
        );
      }

      if (!active.hasRemainingBookings) {
        return SubscriptionBookingEligibility(
          canBookWithSubscription: false,
          subscription: active,
          reason: SubscriptionBookingUnavailableReason.bookingsExhausted,
        );
      }

      // Ensure garment balance is fresh before allowing another booking.
      final remaining = await SubscriptionGarmentBalance.resolveAndCache(
        subscriptionRepository: subscriptionRepository,
        forceRefresh: forceRefresh,
      );
      if (remaining != null && remaining <= 0) {
        return SubscriptionBookingEligibility(
          canBookWithSubscription: false,
          subscription: active,
          reason: SubscriptionBookingUnavailableReason.garmentsExhausted,
        );
      }

      return SubscriptionBookingEligibility(
        canBookWithSubscription: true,
        subscription: active,
      );
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('not logged in') || message.contains('login')) {
        return const SubscriptionBookingEligibility(
          canBookWithSubscription: false,
          reason: SubscriptionBookingUnavailableReason.notLoggedIn,
        );
      }
      return const SubscriptionBookingEligibility(
        canBookWithSubscription: false,
        reason: SubscriptionBookingUnavailableReason.noActiveSubscription,
      );
    }
  }
}
