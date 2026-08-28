import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';

/// Builds /orders/initiate fields from the live cart.
///
/// Mixed / Continue Without carts must NOT send `product_class: wardrobe_kit`
/// plus the continuation kit id. That makes the backend bill the kit
/// (e.g. ₹100) instead of the paid garment line prices shown in the cart.
class CheckoutInitiateRequest {
  const CheckoutInitiateRequest({
    required this.checkoutType,
    required this.nonSubscription,
    this.productClass,
    this.wardrobeKitId,
  });

  final String checkoutType;
  final bool nonSubscription;
  final String? productClass;
  final String? wardrobeKitId;

  static bool isPaidOrMixed(CartState state) {
    return state.hasPaidRentalGarments ||
        state.hasMixedWardrobeTypes ||
        CheckoutSession.instance.continueWithoutMembership;
  }

  static CheckoutInitiateRequest fromCart(CartState state) {
    final paidOrMixed = isPaidOrMixed(state);
    final hasWardrobe = state.wardrobeItems.isNotEmpty;
    final hasEssentials = state.essentialItems.isNotEmpty;

    return CheckoutInitiateRequest(
      checkoutType: hasWardrobe ? 'kit' : 'essentials',
      nonSubscription: paidOrMixed ||
          !CheckoutSession.instance.useSubscriptionBooking,
      productClass: (paidOrMixed || hasEssentials)
          ? 'single_item'
          : (hasWardrobe ? 'wardrobe_kit' : 'single_item'),
      wardrobeKitId: paidOrMixed
          ? null
          : (hasWardrobe
              ? (state.wardrobeKitProductId ?? state.wardrobeKitId)
              : null),
    );
  }
}
