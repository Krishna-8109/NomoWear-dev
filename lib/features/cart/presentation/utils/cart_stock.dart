import 'package:flutter/foundation.dart';

/// True when the backend indicates the selected variant has no stock.
bool cartVariantOutOfStockMessage(String? message) {
  if (message == null || message.isEmpty) return false;
  return message.toLowerCase().contains('out of stock');
}

/// True when the backend rejects due to subscription plan days quota.
bool isSubscriptionQuotaError(String? message) {
  if (message == null || message.isEmpty) return false;
  return message.toLowerCase().contains('subscription plan days quota');
}

/// Parsed subscription quota details from the backend error message.
class SubscriptionQuotaDetails {
  final int? remainingDays;
  final int? planDays;
  final int? otherCartDays;
  final int? thisKitDays;
  final String rawMessage;

  const SubscriptionQuotaDetails({
    this.remainingDays,
    this.planDays,
    this.otherCartDays,
    this.thisKitDays,
    required this.rawMessage,
  });

  String get userFriendlyMessage {
    if (remainingDays != null && planDays != null) {
      final buffer = StringBuffer('You have $remainingDays day(s) remaining');
      buffer.write(' out of $planDays in your active plan.');
      if (otherCartDays != null && thisKitDays != null) {
        buffer.write(
          '\n\nYour current cart uses $otherCartDays day(s) and this kit '
          'requires $thisKitDays day(s).',
        );
        final needed = otherCartDays! + thisKitDays!;
        buffer.write(
          '\n\nYou need $needed day(s), but only $remainingDays are available.',
        );
      }
      return buffer.toString();
    }
    return 'Your active subscription plan does not have enough remaining '
        'days for this kit. Please remove another kit from your cart or '
        'choose a shorter-duration kit.';
  }

  static SubscriptionQuotaDetails parse(String message) {
    int? remaining;
    int? plan;
    int? otherCart;
    int? thisKit;

    final remainingMatch = RegExp(r'(\d+)\s*day\(s\)\s*remaining').firstMatch(message);
    if (remainingMatch != null) remaining = int.tryParse(remainingMatch.group(1)!);

    final planMatch = RegExp(r'out of\s*(\d+)').firstMatch(message);
    if (planMatch != null) plan = int.tryParse(planMatch.group(1)!);

    final otherMatch = RegExp(r'Other kits in cart:\s*(\d+)').firstMatch(message);
    if (otherMatch != null) otherCart = int.tryParse(otherMatch.group(1)!);

    final thisMatch = RegExp(r'This kit:\s*(\d+)').firstMatch(message);
    if (thisMatch != null) thisKit = int.tryParse(thisMatch.group(1)!);

    return SubscriptionQuotaDetails(
      remainingDays: remaining,
      planDays: plan,
      otherCartDays: otherCart,
      thisKitDays: thisKit,
      rawMessage: message,
    );
  }
}

void logCartStockOut({
  required String productId,
  required String? variantId,
  required String? size,
  required String message,
}) {
  if (!kDebugMode) return;
  debugPrint('[CART_STOCK]');
  debugPrint('productId=$productId');
  debugPrint('variantId=${variantId ?? '-'}');
  debugPrint('size=${size ?? '-'}');
  debugPrint('status=OUT_OF_STOCK');
  debugPrint('message=$message');
}

void logCartQuota(SubscriptionQuotaDetails details) {
  if (!kDebugMode) return;
  debugPrint('[CART_QUOTA] quota error detected');
  debugPrint('remainingDays=${details.remainingDays}');
  debugPrint('planDays=${details.planDays}');
  debugPrint('otherCartDays=${details.otherCartDays}');
  debugPrint('thisKitDays=${details.thisKitDays}');
}
