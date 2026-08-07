import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/utils/api_id_utils.dart';
import 'package:nomowear/features/cart/data/cart_repository.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/cart/presentation/utils/cart_limits.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/home/presentation/screens/subscription_tab_widget.dart';

Future<void> _continueWithoutMembership(
  BuildContext context,
  BuildContext dialogContext,
) async {
  CartBloc? cartBloc;
  CartState snapshot = const CartState();
  try {
    cartBloc = context.read<CartBloc>();
    snapshot = cartBloc.state;
  } catch (_) {}

  Navigator.pop(dialogContext);

  // Wipe local cart immediately so badge/UI reset before navigation.
  cartBloc?.add(ClearLocalCartEvent());
  CheckoutSession.instance.clear();

  // Also clear server cart using the pre-clear snapshot.
  try {
    if (snapshot.items.isNotEmpty) {
      await CartRepository().clearRemoteCart(snapshot);
    }
  } catch (_) {}

  if (!context.mounted) return;
  Navigator.pushNamedAndRemoveUntil(
    context,
    AppRoutes.homeScreen,
    (route) => false,
  );
}

/// Garment / kit / subscription remaining limit reached.
/// Same layout as the non-subscriber alert — only the copy differs.
Future<void> showWardrobeLimitReachedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.88),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.maxFinite,
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: const Color(0xFF050816),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE6C279).withOpacity(0.35),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE6C279),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LIMIT REACHED',
                textAlign: TextAlign.center,
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 20,
                  color: AppColours.primary,
                  letterSpacing: 0.6,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'You’ve reached the maximum limit for garments and cannot add more. To select more garments, please upgrade to a higher membership.',
                textAlign: TextAlign.center,
                style: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.close,
                    size: 16,
                    color: AppColours.primary,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Add more garments beyond your current limit',
                      style: CustomTextStyles.openSansRegular.copyWith(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.maxFinite,
                height: 46.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.homeScreen,
                      (route) => false,
                      arguments: SubscriptionTabWidget.subscriptionTabIndex,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE6C27A),
                          Color(0xFFD9B35F),
                        ],
                      ),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        'UPGRADE TO MEMBERSHIP',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13.fSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.maxFinite,
                height: 46.h,
                child: OutlinedButton(
                  onPressed: () =>
                      _continueWithoutMembership(context, dialogContext),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.55)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'CONTINUE WITHOUT MEMBERSHIP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.fSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Non-subscriber tried to mix wardrobe categories in one cart.
Future<void> showSingleCategoryRestrictionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.88),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.maxFinite,
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: const Color(0xFF050816),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE6C279).withOpacity(0.35),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE6C279),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UNLOCK FULL ACCESS',
                textAlign: TextAlign.center,
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 20,
                  color: AppColours.primary,
                  letterSpacing: 0.6,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'As a non-subscriber, you can only select garments from one segment at a time. To purchase from all the segments please upgrade to a membership.',
                textAlign: TextAlign.center,
                style: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.close,
                    size: 16,
                    color: AppColours.primary,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Select garments from any segment',
                      style: CustomTextStyles.openSansRegular.copyWith(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.maxFinite,
                height: 46.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.homeScreen,
                      (route) => false,
                      arguments: SubscriptionTabWidget.subscriptionTabIndex,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE6C27A),
                          Color(0xFFD9B35F),
                        ],
                      ),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        'UPGRADE TO MEMBERSHIP',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13.fSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.maxFinite,
                height: 46.h,
                child: OutlinedButton(
                  onPressed: () =>
                      _continueWithoutMembership(context, dialogContext),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.55)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'CONTINUE WITHOUT MEMBERSHIP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.fSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

bool tryAddToCart(BuildContext context, CartItem item) {
  if (!isApiUuid(item.productId)) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This product cannot be ordered. Please add items from the loaded catalog.',
        ),
      ),
    );
    return false;
  }

  final cartBloc = context.read<CartBloc>();
  final cartState = cartBloc.state;

  final violatesCategory = CartLimits.wouldViolateSingleCategoryRule(
    cartState,
    incomingCategory: item.category,
    isEssential: item.isEssential,
  );
  final exceedsGarmentLimit = CartLimits.wouldExceedWardrobeLimit(
    cartState,
    item,
  );

  // Cross-segment (non-subscriber) → UNLOCK FULL ACCESS dialog.
  if (violatesCategory) {
    showSingleCategoryRestrictionDialog(context);
    return false;
  }

  // Same-segment kit / subscription remaining limit → Limit reached dialog.
  if (exceedsGarmentLimit) {
    showWardrobeLimitReachedDialog(context);
    return false;
  }

  cartBloc.add(AddToCartEvent(item));
  return true;
}
