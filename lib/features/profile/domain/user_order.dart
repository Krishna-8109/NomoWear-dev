/// Single garment line inside a kit / multi-item order (order details).
class OrderLineItem {
  final String productId;
  final String productName;
  final String orderIdDisplay;
  final String sizeLabel;
  final String statusText;
  final bool isDelivered;
  final String imageAsset;
  final String? category;
  final String? itemType;
  final int quantity;
  final num unitPrice;
  final num lineTotal;

  const OrderLineItem({
    required this.productId,
    required this.productName,
    required this.orderIdDisplay,
    required this.sizeLabel,
    required this.statusText,
    required this.isDelivered,
    required this.imageAsset,
    this.category,
    this.itemType,
    this.quantity = 1,
    this.unitPrice = 0,
    this.lineTotal = 0,
  });
}

/// One order shown in My Orders and Order Details.
class UserOrder {
  final String id;
  final String title;
  /// Thumbnails: one asset for a simple row, or four for a 2×2 grid.
  final List<String> coverImageAssets;
  final String orderIdDisplay;
  final String attributeLabel;
  final String attributeValue;
  final String statusLabel;
  final String statusDate;
  final bool isDelivered;
  /// When true and [isDelivered], list/details show "Return This Order".
  final bool canReturn;
  /// Order is in return pickup / approval flow (not eligible for a new return).
  final bool isInReturnFlow;
  final List<OrderLineItem>? lineItems;
  final String addressLabel;
  final String addressLines;
  final String mobileDisplay;
  /// When [isDelivered] is true, order details summary uses Return if true, else Track.
  final bool deliveredSummaryShowsReturn;
  final bool isWardrobeKit;
  final int totalGarmentsCount;
  final String? deliveryDateFormatted;
  final num totalAmount;

  const UserOrder({
    required this.id,
    required this.title,
    required this.coverImageAssets,
    required this.orderIdDisplay,
    required this.attributeLabel,
    required this.attributeValue,
    required this.statusLabel,
    required this.statusDate,
    required this.isDelivered,
    this.canReturn = false,
    this.isInReturnFlow = false,
    this.lineItems,
    required this.addressLabel,
    required this.addressLines,
    required this.mobileDisplay,
    this.deliveredSummaryShowsReturn = true,
    this.isWardrobeKit = false,
    this.totalGarmentsCount = 0,
    this.deliveryDateFormatted,
    this.totalAmount = 0,
  });

  bool get hasLineItems => lineItems != null && lineItems!.isNotEmpty;

  bool get useCoverGrid => coverImageAssets.length >= 4;

  /// Order details: “Return This Order” — show review stars + expand when [hasLineItems].
  bool get isReturnOrderDetails => isDelivered && deliveredSummaryShowsReturn;

  /// Order details: tracking (no stars). Opposite of [isReturnOrderDetails] for rating UI.
  bool get isTrackOrderDetails => !isReturnOrderDetails;

  UserOrder copyWith({
    String? id,
    String? title,
    List<String>? coverImageAssets,
    String? orderIdDisplay,
    String? attributeLabel,
    String? attributeValue,
    String? statusLabel,
    String? statusDate,
    bool? isDelivered,
    bool? canReturn,
    bool? isInReturnFlow,
    List<OrderLineItem>? lineItems,
    String? addressLabel,
    String? addressLines,
    String? mobileDisplay,
    bool? deliveredSummaryShowsReturn,
    bool? isWardrobeKit,
    int? totalGarmentsCount,
    String? deliveryDateFormatted,
    num? totalAmount,
  }) {
    return UserOrder(
      id: id ?? this.id,
      title: title ?? this.title,
      coverImageAssets: coverImageAssets ?? this.coverImageAssets,
      orderIdDisplay: orderIdDisplay ?? this.orderIdDisplay,
      attributeLabel: attributeLabel ?? this.attributeLabel,
      attributeValue: attributeValue ?? this.attributeValue,
      statusLabel: statusLabel ?? this.statusLabel,
      statusDate: statusDate ?? this.statusDate,
      isDelivered: isDelivered ?? this.isDelivered,
      canReturn: canReturn ?? this.canReturn,
      isInReturnFlow: isInReturnFlow ?? this.isInReturnFlow,
      lineItems: lineItems ?? this.lineItems,
      addressLabel: addressLabel ?? this.addressLabel,
      addressLines: addressLines ?? this.addressLines,
      mobileDisplay: mobileDisplay ?? this.mobileDisplay,
      deliveredSummaryShowsReturn:
          deliveredSummaryShowsReturn ?? this.deliveredSummaryShowsReturn,
      isWardrobeKit: isWardrobeKit ?? this.isWardrobeKit,
      totalGarmentsCount: totalGarmentsCount ?? this.totalGarmentsCount,
      deliveryDateFormatted: deliveryDateFormatted ?? this.deliveryDateFormatted,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}

/// In-memory list populated from GET /mobile/v1/orders.
final List<UserOrder> userOrdersList = <UserOrder>[];

UserOrder? findUserOrderById(String id) {
  for (final o in userOrdersList) {
    if (o.id == id) return o;
  }
  return null;
}

void replaceUserOrders(List<UserOrder> orders) {
  userOrdersList
    ..clear()
    ..addAll(orders);
}

void appendUserOrder(UserOrder order) {
  userOrdersList.insert(0, order);
}

void upsertUserOrder(UserOrder order) {
  final index = userOrdersList.indexWhere((o) => o.id == order.id);
  if (index >= 0) {
    userOrdersList[index] = order;
  } else {
    userOrdersList.insert(0, order);
  }
}

/// Marks a locally submitted / waitlisted return on the in-memory order list.
void markUserOrderReturnSubmitted(String orderId) {
  final id = orderId.trim();
  if (id.isEmpty) return;
  final index = userOrdersList.indexWhere((o) => o.id == id);
  if (index < 0) return;
  final current = userOrdersList[index];
  userOrdersList[index] = current.copyWith(
    canReturn: false,
    isInReturnFlow: true,
    deliveredSummaryShowsReturn: false,
    statusLabel: 'Return status',
    statusDate: 'Pending approval',
  );
}
