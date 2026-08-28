import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nomowear/core/app_export.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/utils/api_id_utils.dart';
import 'package:nomowear/core/utils/size_utils.dart';
import 'package:nomowear/theme/theme_helper.dart';
import 'package:nomowear/routes/app_routes.dart';
import 'package:nomowear/features/orders/data/order_repository.dart';
import 'package:nomowear/features/orders/data/pending_return_store.dart';
import 'package:nomowear/features/orders/data/user_order_mapper.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/products/data/product_mapper.dart';
import 'package:nomowear/features/products/data/product_repository.dart';
import 'package:nomowear/features/profile/data/profile_repository.dart';
import 'package:nomowear/features/profile/domain/user_order.dart';
import 'package:nomowear/features/wardrobe/presentation/screens/product_details_screen.dart';
import 'package:nomowear/features/wardrobe/presentation/screens/wardrobe_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderRepository _orderRepository = OrderRepository();
  final ProductRepository _productRepository = ProductRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final Set<String> _ratedProductIds = <String>{};
  final Map<String, int> _ratedProductValues = <String, int>{};

  bool _isLoading = true;
  String? _errorMessage;
  UserOrder? _order;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = false;
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await PendingReturnStore.instance.ensureLoaded();
      final detail = await _orderRepository.getOrderDetail(widget.orderId);
      final customer = await _profileRepository.getProfile();
      final mapped = UserOrderMapper.fromHistoryItem(detail, customer: customer);
      final ratedRatings = await _loadRatedProductRatings(mapped);

      final existingIndex =
          userOrdersList.indexWhere((order) => order.id == mapped.id);
      if (existingIndex >= 0) {
        userOrdersList[existingIndex] = mapped;
      } else {
        userOrdersList.insert(0, mapped);
      }

      if (!mounted) return;
      setState(() {
        _order = mapped;
        _expanded = mapped.hasLineItems;
        _ratedProductIds
          ..clear()
          ..addAll(ratedRatings.keys);
        _ratedProductValues
          ..clear()
          ..addAll(ratedRatings);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load order details. Please try again.';
      });
    }
  }

  UserOrder? get o => _order;

  Future<Map<String, int>> _loadRatedProductRatings(UserOrder order) async {
    final lineItems = order.lineItems ?? const <OrderLineItem>[];
    final productIds = lineItems
        .map((item) => item.productId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (productIds.isEmpty) return const <String, int>{};
    try {
      return await _orderRepository.getMyProductRatings(productIds: productIds);
    } catch (_) {
      // Keep order-details loading resilient even if rating status API fails.
      return const <String, int>{};
    }
  }

  Future<void> _refreshRatedProductIds() async {
    final order = _order;
    if (order == null) return;
    final ratedRatings = await _loadRatedProductRatings(order);
    if (!mounted) return;
    if (ratedRatings.isEmpty) return;
    setState(() {
      _ratedProductIds
        ..clear()
        ..addAll(ratedRatings.keys);
      _ratedProductValues
        ..clear()
        ..addAll(ratedRatings);
    });
  }

  WardrobeItem _productFromOrderLineItem(OrderLineItem item) {
    final productId = item.productId.trim();
    if (productId.isNotEmpty) {
      final cached = ProductCache.instance.findById(productId);
      if (cached != null) {
        final mapped = ProductMapper.toWardrobeItem(
          cached,
          category: item.category,
        );
        return WardrobeItem(
          productId: mapped.productId,
          title: mapped.title,
          description: mapped.description,
          imageUrl: _isNetworkImage(item.imageAsset)
              ? item.imageAsset
              : mapped.imageUrl,
          price: mapped.price,
          imageUrls: mapped.imageUrls,
          colorVariantImages: mapped.colorVariantImages,
          colorNames: mapped.colorNames,
          sizes: mapped.sizes,
          ages: mapped.ages,
          productDetails: mapped.productDetails,
          variants: mapped.variants,
          category: item.category ?? mapped.category,
          genderTag: mapped.genderTag,
        );
      }
    }

    return WardrobeItem(
      productId: isApiUuid(productId) ? productId : null,
      title: item.productName,
      description: '',
      imageUrl: item.imageAsset,
      sizes: item.sizeLabel != '-' ? [item.sizeLabel] : const [],
      category: item.category,
    );
  }

  bool _isNetworkImage(String source) {
    return source.startsWith('http://') || source.startsWith('https://');
  }

  Future<void> _openProductDetails(OrderLineItem item) async {
    final productId = item.productId.trim();
    if (!isApiUuid(productId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product details are not available for this item.'),
        ),
      );
      return;
    }

    try {
      await _productRepository.getProductById(productId);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.isNotEmpty
                ? e.message
                : 'This product is no longer available.',
          ),
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open product details. Please try again.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          product: _productFromOrderLineItem(item),
        ),
      ),
    );
  }

  Future<void> _onRateTap(OrderLineItem item) async {
    final productId = item.productId.trim();
    if (productId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product id missing for this item.')),
      );
      return;
    }

    if (_ratedProductIds.contains(productId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already rated this product.')),
      );
      return;
    }

    final draft = await _showRatingDialog(item.productName);
    if (draft == null) return;

    try {
      final message = await _orderRepository.submitProductRating(
        productId: productId,
        rating: draft.rating,
        review: draft.review,
      );
      if (!mounted) return;
      setState(() {
        _ratedProductIds.add(productId);
        _ratedProductValues[productId] = draft.rating;
      });
      await _refreshRatedProductIds();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to submit rating. Please try again.')),
      );
    }
  }

  Future<_RatingDraft?> _showRatingDialog(String productName) async {
    final reviewController = TextEditingController();
    var selectedRating = 1;
    try {
      return await showDialog<_RatingDraft>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (builderContext, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF111319),
                title: Text(
                  'Rate Product',
                  style: TextStyle(color: AppColours.primary, fontSize: 16.fSize),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(5, (index) {
                          final value = index + 1;
                          return IconButton(
                            onPressed: () {
                              setDialogState(() => selectedRating = value);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              value <= selectedRating ? Icons.star : Icons.star_border,
                              color: AppColours.primary,
                              size: 24,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reviewController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Write a review (optional)',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          filled: true,
                          fillColor: const Color(0xFF1A1D24),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColours.primary.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColours.primary.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColours.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      FocusScope.of(dialogContext).unfocus();
                      Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      FocusScope.of(dialogContext).unfocus();
                      Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop(
                        _RatingDraft(
                          rating: selectedRating,
                          review: reviewController.text.trim(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColours.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minimumSize: const Size(88, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Submit'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // Dispose after dialog teardown completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        reviewController.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: AppColours.primary),
                  ),
                  Expanded(
                    child: Text(
                      'Order Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColours.primary,
                        fontSize: 18.fSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
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
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColours.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14.fSize),
              ),
              SizedBox(height: 16.h),
              OutlinedButton(
                onPressed: _loadOrder,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColours.primary.withOpacity(0.9)),
                  foregroundColor: AppColours.primary,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final order = o;
    if (order == null) {
      return Center(
        child: Text(
          'Order not found',
          style: TextStyle(color: Colors.white70, fontSize: 14.fSize),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(
            order: order,
            expanded: _expanded,
            onToggle: order.hasLineItems
                ? () => setState(() => _expanded = !_expanded)
                : null,
            onReturnSubmitted: () async {
              await _loadOrder();
            },
          ),
          if (_expanded && order.hasLineItems) ...[
            SizedBox(height: 24.h),
            ..._buildGroupedSections(order),
            SizedBox(height: 20.h),
            _buildPaymentSummary(order),
          ],
          SizedBox(height: 20.h),
          Container(height: 1, color: Colors.white24),
          SizedBox(height: 20.h),
          Text(
            'Delivery Addresses',
            style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 15),
          ),
          SizedBox(height: 10.h),
          Text(
            order.addressLabel,
            style: TextStyle(
              color: AppColours.primary,
              fontSize: 15.fSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            order.addressLines.isNotEmpty
                ? order.addressLines
                : 'Address not available',
            style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 15),
          ),
          if (order.mobileDisplay.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Mobile Number: ${order.mobileDisplay}',
              style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 12),
            ),
          ],
          SizedBox(height: 20.h),
          Container(
            height: 1,
            color: AppColours.primary.withOpacity(0.35),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSections(UserOrder order) {
    final items = order.lineItems ?? [];
    final subscriptionItems = items
        .where((i) => i.itemType == 'subscription')
        .toList();
    final nonSubscriptionItems = items
        .where((i) => i.itemType == 'non_subscription')
        .toList();
    final kidsEssentialItems = items
        .where((i) => i.itemType == 'kids' || i.itemType == 'essentials')
        .toList();

    final widgets = <Widget>[];

    if (subscriptionItems.isNotEmpty) {
      widgets.addAll(_buildGarmentSection(
        title: 'Subscription Kit',
        items: subscriptionItems,
        order: order,
      ));
    }

    if (nonSubscriptionItems.isNotEmpty) {
      widgets.addAll(_buildGarmentSection(
        title: 'Non-Subscription Kit',
        items: nonSubscriptionItems,
        order: order,
      ));
    }

    if (kidsEssentialItems.isNotEmpty) {
      widgets.addAll(_buildGarmentSection(
        title: 'Kids & Essentials',
        items: kidsEssentialItems,
        order: order,
      ));
    }

    // Fallback: items with no recognized itemType
    final otherItems = items
        .where((i) =>
            i.itemType != 'subscription' &&
            i.itemType != 'non_subscription' &&
            i.itemType != 'kids' &&
            i.itemType != 'essentials')
        .toList();
    if (otherItems.isNotEmpty &&
        subscriptionItems.isEmpty &&
        nonSubscriptionItems.isEmpty &&
        kidsEssentialItems.isEmpty) {
      widgets.addAll(_buildGarmentSection(
        title: 'Order Items',
        items: otherItems,
        order: order,
      ));
    }

    return widgets;
  }

  List<Widget> _buildGarmentSection({
    required String title,
    required List<OrderLineItem> items,
    required UserOrder order,
  }) {
    return [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColours.primary.withOpacity(0.25),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: AppColours.primary,
            fontSize: 14.fSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      SizedBox(height: 12.h),
      ...items.map(
        (item) => Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: _LineItemRow(
            item: item,
            showReviewRating: order.isDelivered,
            alreadyRated: _ratedProductIds.contains(item.productId.trim()),
            ratingValue: _ratedProductValues[item.productId.trim()],
            onRateTap: _ratedProductIds.contains(item.productId.trim())
                ? null
                : () => _onRateTap(item),
            onProductTap: () => _openProductDetails(item),
          ),
        ),
      ),
    ];
  }

  Widget _buildPaymentSummary(UserOrder order) {
    final items = order.lineItems ?? [];

    final subscriptionTotal = items
        .where((i) => i.itemType == 'subscription')
        .fold<num>(0, (sum, i) => sum + i.lineTotal);
    final nonSubscriptionTotal = items
        .where((i) => i.itemType == 'non_subscription')
        .fold<num>(0, (sum, i) => sum + i.lineTotal);
    final kidsEssentialTotal = items
        .where((i) => i.itemType == 'kids' || i.itemType == 'essentials')
        .fold<num>(0, (sum, i) => sum + i.lineTotal);

    final hasSubscription = items.any((i) => i.itemType == 'subscription');
    final hasNonSubscription = items.any((i) => i.itemType == 'non_subscription');
    final hasKidsEssential =
        items.any((i) => i.itemType == 'kids' || i.itemType == 'essentials');

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF080812),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColours.primary.withOpacity(0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary',
            style: TextStyle(
              color: AppColours.primary,
              fontSize: 15.fSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 14.h),
          if (hasNonSubscription)
            _paymentRow('Non-Subscription Kit', nonSubscriptionTotal),
          if (hasKidsEssential)
            _paymentRow('Kids & Essentials', kidsEssentialTotal),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Container(
              height: 1,
              color: AppColours.primary.withOpacity(0.25),
            ),
          ),
          _paymentRow(
            'Total Amount',
            order.totalAmount,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _paymentRow(String label, num amount, {bool isBold = false}) {
    final formatted = '₹ ${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? AppColours.primary : Colors.white70,
              fontSize: isBold ? 14.fSize : 13.fSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            formatted,
            style: TextStyle(
              color: isBold ? AppColours.primary : Colors.white,
              fontSize: isBold ? 15.fSize : 13.fSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final UserOrder order;
  final bool expanded;
  final VoidCallback? onToggle;
  final Future<void> Function()? onReturnSubmitted;

  const _SummaryCard({
    required this.order,
    required this.expanded,
    required this.onToggle,
    this.onReturnSubmitted,
  });

  Widget _buildCoverImage(String source) {
    final isNetwork =
        source.startsWith('http://') || source.startsWith('https://');
    if (isNetwork) {
      return Image.network(source, fit: BoxFit.cover);
    }
    return Image.asset(source, fit: BoxFit.cover);
  }

  Widget _buildCoverThumb() {
    final paths = order.coverImageAssets;
    const thumbW = 104.0;
    const thumbH = 104.0;

    Widget child;
    if (paths.isEmpty) {
      child = ColoredBox(
        color: const Color(0xFF1A1A22),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColours.primary.withOpacity(0.5),
          ),
        ),
      );
    } else if (paths.length == 1) {
      child = _buildCoverImage(paths.first);
    } else {
      child = GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final path = paths[index % paths.length];
          return _buildCoverImage(path);
        },
      );
    }

    return SizedBox(
      width: thumbW.w,
      height: thumbH.w,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD8B26A)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasChevron = onToggle != null;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: const Color(0xFF080812),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFB89146).withOpacity(0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverThumb(),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.title,
                            style: TextStyle(
                              color: const Color(0xFFD8B26A),
                              fontSize: 17.fSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (hasChevron)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onToggle,
                              borderRadius: BorderRadius.circular(20),
                              child: Icon(
                                expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: const Color(0xFFD8B26A),
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Order Id: ${order.orderIdDisplay}',
                      style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 12),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '${order.attributeLabel}: ${order.attributeValue}',
                      style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 12),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '${order.statusLabel}: ${order.statusDate}',
                      style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 12),
                    ),
                    SizedBox(height: 12.h),
                    if (!order.isDelivered)
                      SizedBox(
                        height: 44.h,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.orderTrackingScreen,
                            arguments: order.id,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0x66E6C27A),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Track Your Order',
                            style: CustomTextStyles.openSansSemiBold.copyWith(
                              fontSize: 10,
                              color: AppColours.secondary,
                            ),
                          ),
                        ),
                      )
                    else if (order.canReturn)
                      SizedBox(
                        height: 44.h,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final submitted = await Navigator.pushNamed(
                              context,
                              AppRoutes.returnOrderScreen,
                              arguments: {
                                'orderId': order.id,
                                'orderNumber': order.orderIdDisplay,
                              },
                            );
                            if (submitted == true && context.mounted) {
                              await onReturnSubmitted?.call();
                              if (!context.mounted) return;
                              Navigator.pushNamed(
                                context,
                                AppRoutes.orderTrackingScreen,
                                arguments: order.id,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD8B26A),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Return Your Order',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 13.fSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 44.h,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.orderTrackingScreen,
                            arguments: order.id,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD8B26A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            order.isInReturnFlow
                                ? 'Track Return'
                                : 'Track Your Order',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.fSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final OrderLineItem item;
  final bool showReviewRating;
  final bool alreadyRated;
  final int? ratingValue;
  final VoidCallback? onRateTap;
  final VoidCallback? onProductTap;

  const _LineItemRow({
    required this.item,
    required this.showReviewRating,
    this.alreadyRated = false,
    this.ratingValue,
    this.onRateTap,
    this.onProductTap,
  });

  Widget _buildImage() {
    final source = item.imageAsset;
    final isNetwork =
        source.startsWith('http://') || source.startsWith('https://');
    if (isNetwork) {
      return Image.network(source, width: 68, height: 68, fit: BoxFit.cover);
    }
    return Image.asset(source, width: 68, height: 68, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            onTap: onProductTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImage(),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(
                          color: AppColours.primary,
                          fontSize: 14.fSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Order Id: ${item.orderIdDisplay}',
                        style: CustomTextStyles.montserratMedium.copyWith(fontSize: 12),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Size: ${item.sizeLabel}',
                        style: CustomTextStyles.montserratMedium.copyWith(fontSize: 12),
                      ),
                      if (item.quantity > 1) ...[
                        SizedBox(height: 3.h),
                        Text(
                          'Qty: ${item.quantity}',
                          style: CustomTextStyles.montserratMedium.copyWith(fontSize: 12),
                        ),
                      ],
                      if (item.itemType != 'subscription') ...[
                        SizedBox(height: 3.h),
                        Text(
                          item.lineTotal > 0
                              ? '₹ ${item.lineTotal.toStringAsFixed(item.lineTotal.truncateToDouble() == item.lineTotal ? 0 : 2)}'
                              : 'Included in Subscription',
                          style: TextStyle(
                            color: item.lineTotal > 0
                                ? Colors.white
                                : AppColours.primary.withOpacity(0.7),
                            fontSize: 12.fSize,
                            fontWeight: FontWeight.w600,
                            fontStyle: item.lineTotal > 0
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ],
                      SizedBox(height: 6.h),
                      if (showReviewRating && item.isDelivered)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColours.primary,
                              size: 16,
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                item.statusText,
                                style: TextStyle(
                                  color: AppColours.primary,
                                  fontSize: 12.fSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          item.statusText,
                          style: TextStyle(
                            color: AppColours.primary,
                            fontSize: 12.fSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showReviewRating)
          _RateProductBox(
            alreadyRated: alreadyRated,
            ratingValue: ratingValue,
            onTap: onRateTap,
          ),
      ],
    );
  }
}

class _RateProductBox extends StatelessWidget {
  final bool alreadyRated;
  final int? ratingValue;
  final VoidCallback? onTap;

  const _RateProductBox({
    this.alreadyRated = false,
    this.ratingValue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alreadyRated ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 106.w,
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 7.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColours.primary.withOpacity(0.40)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.5.w),
                  child: Icon(
                    i < (ratingValue ?? 0) ? Icons.star : Icons.star_border,
                    color: AppColours.primary,
                    size: 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              alreadyRated
                  ? ((ratingValue ?? 0) > 0
                      ? 'Rated ${ratingValue!}/5'
                      : 'Rated')
                  : 'Rate this Product',
              textAlign: TextAlign.center,
              style: CustomTextStyles.montserratRegular.copyWith(
                fontSize: 10,
                color: const Color(0xFFF5E6C8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingDraft {
  final int rating;
  final String review;

  const _RatingDraft({
    required this.rating,
    required this.review,
  });
}
