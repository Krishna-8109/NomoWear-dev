import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/gestures.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/cart/data/cart_repository.dart';
import 'package:nomowear/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:nomowear/features/checkout/data/checkout_session.dart';
import 'package:nomowear/features/checkout/presentation/utils/checkout_pricing.dart';
import 'package:nomowear/features/profile/presentation/utils/profile_order_guard.dart';
import 'package:nomowear/features/home/presentation/bloc/home_bloc.dart';
import 'package:nomowear/features/orders/data/order_repository.dart';
import 'package:nomowear/features/profile/data/profile_cache.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/products/data/product_mapper.dart';
import 'package:nomowear/features/wardrobe/presentation/screens/product_details_screen.dart';
import 'package:nomowear/features/wardrobe/presentation/screens/wardrobe_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _noteController = TextEditingController();
  final CartRepository _cartRepository = CartRepository();
  final OrderRepository _orderRepository = OrderRepository();
  bool _wardrobeGarmentsExpanded = false;
  bool _isPreparingCheckout = false;

  static const List<String> _allSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  static const List<int> _qtyOptions = [1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CheckoutSession.instance.restore().then((_) {
        if (mounted) setState(() {});
      });
      final cartState = context.read<CartBloc>().state;
      if (cartState.items.isEmpty) {
        context.read<CartBloc>().add(LoadCartEvent());
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CartBloc, CartState>(
      listenWhen: (previous, current) =>
          previous.items.isNotEmpty && current.isEmpty,
      listener: (context, state) {
        if (state.isEmpty && _wardrobeGarmentsExpanded) {
          setState(() => _wardrobeGarmentsExpanded = false);
        }
      },
      builder: (context, state) {
        final isEmpty = state.isEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFF0F1012),
          body: Stack(
            children: [
              AbsorbPointer(
                absorbing: _isPreparingCheckout,
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildAppBar(isEmpty ? 0 : state.totalItems),
                      Expanded(
                        child: isEmpty
                            ? _buildEmptyCart()
                            : _buildCartContent(context, state),
                      ),
                      if (!isEmpty) _buildPlaceOrderButton(context),
                    ],
                  ),
                ),
              ),
              if (_isPreparingCheckout) ...[
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x66000000)),
                ),
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFFE6C27A),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _onPlaceOrderPressed(BuildContext context) async {
    if (_isPreparingCheckout) return;
    final canProceed = await ProfileOrderGuard.ensureCompleteProfile(context);
    if (!canProceed || !context.mounted) return;
    await _prefetchCheckoutAndNavigate(context);
  }

  Widget _buildAppBar(int count) {
    return Column(
      children: [
        // 🔹 Top Header (Cart Text)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Center(
            child: Text(
              'Cart',
              style: TextStyle(
                color: AppColours.primary,
                fontSize: 20.fSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // 🔥 Custom Gradient Divider
        Container(
          height: 2,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFE6C27A).withOpacity(0.15),
                Color(0xFFE6C27A),
                Color(0xFFE6C27A).withOpacity(0.15),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildCartContent(BuildContext context, CartState state) {
    final wardrobeItems = state.groupedWardrobeItems;
    final essentialItems = state.groupedEssentialItems;

    if (wardrobeItems.isEmpty && essentialItems.isEmpty) {
      return _buildEmptyCart();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16.h),
          _buildBackNavigationRow(context, state),

          if (wardrobeItems.isNotEmpty) ...[
            SizedBox(height: 24.h),
            _buildWardrobeKitSection(context, state, wardrobeItems),
          ],
          if (essentialItems.isNotEmpty) ...[
            if (wardrobeItems.isNotEmpty) SizedBox(height: 24.h),
            if (wardrobeItems.isNotEmpty) Divider(color: Colors.white12),
            SizedBox(height: 16.h),
            _buildSectionHeader('ESSENTIAL WEAR', '${essentialItems.length} Item'),
            SizedBox(height: 16.h),
            ...essentialItems.map((item) => _buildCartItem(context, item, isWardrobe: false)).toList(),
          ],
          SizedBox(height: 28.h),
          _buildDeliveryDetails(),
          SizedBox(height: 28.h),
          _buildAddNote(),
          SizedBox(height: 16.h),
          _buildTermsText(context),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  String? _resolveListingCategory(CartState state) {
    if (state.wardrobeItems.isNotEmpty) {
      return state.wardrobeItems.first.category ?? 'Comfort Wardrobe';
    }
    if (state.essentialItems.isNotEmpty) {
      return state.essentialItems.first.category ?? 'Essentials Wardrobe';
    }
    return null;
  }

  /// Formats line price from cart API / local item price for display.
  String _formatCartItemPrice(CartItem item) {
    final raw = item.price?.trim() ?? '';
    final unit = CheckoutPricing.parseItemPrice(
      item.price,
      isEssential: item.isEssential,
    );
    if (raw.isEmpty && unit <= 0) return 'Free';
    return CheckoutPricing.formatMoney(unit * item.quantity);
  }

  void _goBackToCategory(BuildContext context) {
    try {
      context.read<HomeBloc>().add(ChangeBottomNavEvent(0));
    } catch (_) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.homeScreen,
        (route) => false,
      );
    }
  }

  void _goBackToProductListing(BuildContext context, String category) {
    Navigator.pushNamed(
      context,
      AppRoutes.wardrobeScreen,
      arguments: category,
    );
  }

  WardrobeItem _productFromCartItem(CartItem item) {
    final productId = item.id.contains('_')
        ? item.id.split('_').first
        : item.id;
    final cached = ProductCache.instance.findById(productId);
    if (cached != null) {
      final mapped = ProductMapper.toWardrobeItem(
        cached,
        category: item.category,
      );
      // Keep the cart-line thumbnail (selected color), not product primary.
      return WardrobeItem(
        productId: mapped.productId,
        title: mapped.title,
        description: mapped.description,
        imageUrl: item.imageUrl.isNotEmpty ? item.imageUrl : mapped.imageUrl,
        price: item.price ?? mapped.price,
        imageUrls: mapped.imageUrls,
        colorVariantImages: mapped.colorVariantImages,
        colorNames: mapped.colorNames,
        sizes: mapped.sizes,
        ages: mapped.ages,
        productDetails: mapped.productDetails,
        variants: mapped.variants,
        category: mapped.category,
        genderTag: mapped.genderTag,
      );
    }

    WardrobeItem? match;

    final categoryItems = item.category != null
        ? WardrobeCatalogue.items[item.category]
        : null;
    if (categoryItems != null) {
      for (final wardrobeItem in categoryItems) {
        if (wardrobeItem.title == item.title) {
          match = wardrobeItem;
          break;
        }
      }
    }

    if (match == null) {
      for (final entry in WardrobeCatalogue.items.entries) {
        for (final wardrobeItem in entry.value) {
          if (wardrobeItem.title == item.title) {
            match = wardrobeItem;
            break;
          }
        }
        if (match != null) break;
      }
    }

    if (match != null) {
      return WardrobeItem(
        productId: match.productId,
        title: match.title,
        description: match.description,
        imageUrl: item.imageUrl,
        price: item.price ?? match.price,
        imageUrls: match.imageUrls,
        colorVariantImages: match.colorVariantImages,
        colorNames: match.colorNames,
        sizes: match.sizes,
        ages: match.ages,
        productDetails: match.productDetails,
        variants: match.variants,
        category: item.category ?? match.category,
        genderTag: match.genderTag,
      );
    }

    return WardrobeItem(
      productId: productId.length > 20 ? productId : null,
      title: item.title,
      description: '',
      imageUrl: item.imageUrl,
      price: item.price,
      category: item.category,
    );
  }

  void _openProductDetails(BuildContext context, CartItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          product: _productFromCartItem(item),
        ),
      ),
    );
  }

  Widget _buildBackNavigationRow(BuildContext context, CartState state) {
    final category = _resolveListingCategory(state);
    if (category == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBackNavButton(
                label: 'Back to Category',
                onTap: () => _goBackToCategory(context),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildBackNavButton(
                label: 'Back to Product Listing',
                onTap: () => _goBackToProductListing(context, category),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
      ],
    );
  }

  Widget _buildBackNavButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColours.primary.withOpacity(0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: CustomTextStyles.openSansSemiBold.copyWith(
          fontSize: 10,
          color: AppColours.primary,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: CustomTextStyles.montserratBold.copyWith(fontSize: 12,color: AppColours.primary,letterSpacing: 1),
        ),
        Text(
          trailing,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.fSize,
          ),
        ),
      ],
    );
  }

  Widget _buildWardrobeKitSection(
    BuildContext context,
    CartState state,
    List<CartItem> wardrobeItems,
  ) {
    final garmentCount =
        wardrobeItems.fold<int>(0, (sum, item) => sum + item.quantity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SELECTED WARDROBE', '1 Item'),
        SizedBox(height: 16.h),
        _buildWardrobeKitSummaryCard(
          state: state,
          items: wardrobeItems,
          garmentCount: garmentCount,
        ),
        if (_wardrobeGarmentsExpanded) ...[
          SizedBox(height: 24.h),
          _buildSectionHeader(
            'SELECTED GARMENTS',
            '${wardrobeItems.length} Item${wardrobeItems.length == 1 ? '' : 's'}',
          ),
          SizedBox(height: 16.h),
          ...wardrobeItems.map(
            (item) => _buildCartItem(
              context,
              item,
              isWardrobe: true,
              // Non-sub kit garments show unit prices; subscription kits stay free-looking.
              showPrice: !CheckoutSession.instance.useSubscriptionBooking,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWardrobeKitSummaryCard({
    required CartState state,
    required List<CartItem> items,
    required int garmentCount,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _wardrobeGarmentsExpanded = !_wardrobeGarmentsExpanded),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWardrobeCollage(items),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.wardrobeKitTitle,
                  style: CustomTextStyles.montserratSemiBold.copyWith(
                    color: AppColours.primary,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'No of Garments: $garmentCount',
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 12,
                    color: AppColours.secondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: AnimatedRotation(
              turns: _wardrobeGarmentsExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: AppColours.primary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobeCollage(List<CartItem> items) {
    final images = items
        .map((e) => ProductImage.resolveUrl(e.imageUrl))
        .take(4)
        .toList();
    while (images.length < 4) {
      images.add(images.isNotEmpty ? images.last : ImageConstant.comfortWearImg1);
    }

    Widget cell(String url, {BorderRadius? radius}) {
      return ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: ProductImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 88.w,
        height: 88.w,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: cell(
                      images[0],
                      radius: const BorderRadius.only(topLeft: Radius.circular(8)),
                    ),
                  ),
                  SizedBox(width: 2),
                  Expanded(
                    child: cell(
                      images[1],
                      radius: const BorderRadius.only(topRight: Radius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: cell(
                      images[2],
                      radius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                    ),
                  ),
                  SizedBox(width: 2),
                  Expanded(
                    child: cell(
                      images[3],
                      radius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    CartItem item, {
    bool isWardrobe = false,
    bool? showPrice,
  }) {
    final shouldShowPrice = showPrice ?? !isWardrobe;
    final priceLabel = shouldShowPrice ? _formatCartItemPrice(item) : null;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openProductDetails(context, item),
            child: ProductImage(
              imageUrl: item.imageUrl,
              width: 70.w,
              height: 85.h,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openProductDetails(context, item),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          item.title,
                          style: CustomTextStyles.montserratSemiBold.copyWith(color: AppColours.primary,fontSize: 14),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context
                          .read<CartBloc>()
                          .add(RemoveFromCartEvent(item.id)),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.white54,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                if (priceLabel != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    priceLabel,
                    style: TextStyle(
                      color: AppColours.primary,
                      fontSize: 14.fSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownChip(
                        value: item.selectedSize,
                        items: {
                          ..._allSizes,
                          item.selectedSize,
                        }.toList(),
                        prefix: 'Size: ',
                        onChanged: (val) {
                          if (val != null) {
                            context
                                .read<CartBloc>()
                                .add(UpdateCartItemSizeEvent(item.id, val));
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildDropdownChip<int>(
                        value: item.quantity,
                        items: {
                          ..._qtyOptions,
                          item.quantity,
                        }.toList()
                          ..sort(),
                        prefix: 'Qty: ',
                        onChanged: (val) {
                          if (val != null) {
                            context
                                .read<CartBloc>()
                                .add(UpdateCartItemQuantityEvent(item.id, val));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip<T>({
    required T value,
    required List<T> items,
    required String prefix,
    required ValueChanged<T?> onChanged,
  }) {


    return Container(
      height: 28.h,
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: BoxDecoration(
        color: AppColours.secondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColours.primary.withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: AppColours.secondary,
          icon: Icon(Icons.arrow_drop_down,
              color: Colors.black, size: 18),
          style: TextStyle(color: Colors.white, fontSize: 11.fSize),
          onChanged: onChanged,
          items: items
              .map((s) => DropdownMenuItem<T>(
                    value: s,
                    child: Text(
                      '$prefix$s',
                      style: CustomTextStyles.montserratSemiBold.copyWith(
                        color: Colors.black,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              color: AppColours.primary.withOpacity(0.5), size: 64),
          SizedBox(height: 16.h),
          Text(
            'Your cart is empty',
            style: TextStyle(color: Colors.white, fontSize: 18.fSize),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails() {
    final session = CheckoutSession.instance;
    final customer = ProfileCache.instance.customer;
    final selectedAddressId = session.addressId?.trim();
    final matchedAddress = customer == null || customer.addresses.isEmpty
        ? null
        : customer.addresses.firstWhere(
            (a) => a.id?.trim() == selectedAddressId,
            orElse: () => customer.primaryAddress ?? customer.addresses.first,
          );

    final addressText = session.addressLines?.trim().isNotEmpty == true
        ? session.addressLines!.trim()
        : (matchedAddress?.fullAddress?.trim().isNotEmpty == true
            ? matchedAddress!.fullAddress!.trim()
            : session.addressDisplay);

    final deliveryDateText = session.deliveryDate != null
        ? session.deliveryDateDisplay
        : 'Not selected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DELIVERY DETAILS',
          style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary,fontSize: 12),
        ),
        SizedBox(height: 16.h),
        _deliveryItem(
          Icons.location_on_outlined,
          'DELIVERY ADDRESS',
          addressText,
        ),
        SizedBox(height: 16.h),
        _deliveryItem(
          Icons.calendar_today_outlined,
          'DELIVERY DATE',
          deliveryDateText,
        ),
      ],
    );
  }

  Widget _deliveryItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColours.primary, size: 20),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 12,letterSpacing: 1.2,color: Color(0xFFF5E6C8).withOpacity(0.6)),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: CustomTextStyles.openSansMedium.copyWith(fontSize: 14),

              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddNote() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADD NOTE',
          style: CustomTextStyles.montserratBold.copyWith(fontSize: 12,color: AppColours.primary),

        ),
        SizedBox(height: 12.h),
        DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(8),
          dashPattern: const [6, 3], // 🔥 dot size & spacing
          color: Color(0xFFE6C27A).withOpacity(0.6),
          strokeWidth: 1.2,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: TextField(
              controller: _noteController,
              maxLines: 6,
              style: TextStyle(color: Colors.white70, fontSize: 13.fSize),
              decoration: InputDecoration(
                hintText: 'Please leave the order at the doorstep',
                hintStyle: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 12,
                  color: const Color(0xFFF5E6C8).withOpacity(0.6),
                ),
                border: InputBorder.none,
              ),
              
            ),
          ),
        )
      ],
    );
  }

  Widget _buildTermsText(BuildContext context) {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12),
          children: [
            const TextSpan(
              text: 'By placing this order, you agree to the Nomowear ',
            ),

            // 🔥 Terms & Conditions
            TextSpan(
              text: 'Terms & conditions',
              style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12,color: AppColours.primary),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.pushNamed(context, AppRoutes.termsConditionsScreen);
                },
            ),

            const TextSpan(text: ' and '),

            // 🔥 Privacy Policy
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: AppColours.primary,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.pushNamed(context, AppRoutes.privacyPolicyScreen);
                },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceOrderButton(BuildContext context) {
    return Container(
      width: double.maxFinite,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: ElevatedButton(
        onPressed: () => _onPlaceOrderPressed(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColours.primary,
          minimumSize: Size(double.maxFinite, 54.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          'PLACE ORDER',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16.fSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  bool _isSubscriptionWardrobeBooking(CartState state) {
    if (state.wardrobeItems.isEmpty || state.essentialItems.isNotEmpty) {
      return false;
    }
    return CheckoutSession.instance.useSubscriptionBooking;
  }

  Future<void> _prefetchCheckoutAndNavigate(BuildContext context) async {
    if (_isPreparingCheckout) return;
    final state = context.read<CartBloc>().state;
    if (state.isEmpty) return;

    setState(() => _isPreparingCheckout = true);
    try {
      if (_isSubscriptionWardrobeBooking(state)) {
        if (!context.mounted) return;
        Navigator.pushNamed(context, AppRoutes.essentialsCheckoutScreen);
        return;
      }

      final checkoutType = state.wardrobeItems.isNotEmpty ? 'kit' : 'essentials';
      final hasEssentials = state.essentialItems.isNotEmpty;

      // Sync local qty/size to server before building checkout totals.
      final remoteCart = await _cartRepository.syncCartState(state);
      final initiate = await _orderRepository.initiateOrder(
        checkoutType: checkoutType,
        nonSubscription: true,
        productClass: hasEssentials ? 'single_item' : 'wardrobe_kit',
        wardrobeKitId: state.wardrobeItems.isNotEmpty
            ? (state.wardrobeKitProductId ?? state.wardrobeKitId)
            : null,
      );

      if (!context.mounted) return;

      if (!initiate.canOpenRazorpay) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              initiate.requiresPayment
                  ? 'Payment details missing from server. Please try again.'
                  : 'Unable to load payable amount. Please try again.',
            ),
          ),
        );
        return;
      }

      final latestState = context.read<CartBloc>().state;
      final snapshot = CheckoutPricing.payableSnapshot(
        remoteCart: remoteCart.isEmpty
            ? await _cartRepository.getCart()
            : remoteCart,
        initiate: initiate,
        cartState: latestState,
      );

      final payload = CheckoutPrefetchPayload(
        snapshot: snapshot,
        cartFingerprint: CheckoutPricing.cartFingerprint(latestState),
      );

      Navigator.pushNamed(
        context,
        AppRoutes.essentialsCheckoutScreen,
        arguments: payload,
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to prepare checkout. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPreparingCheckout = false);
    }
  }
}
