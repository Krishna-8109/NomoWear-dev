class RemoteCartKitDetails {
  const RemoteCartKitDetails({
    this.gender,
    this.bodyType,
    this.kitType,
    this.deliveryDate,
    this.deliveryTime,
    this.customerAddressId,
    this.height,
    this.weight,
    this.wardrobeKitId,
    this.wardrobeKitProductId,
    this.durationDays,
  });

  final String? gender;
  final String? bodyType;
  final String? kitType;
  final String? deliveryDate;
  final String? deliveryTime;
  final String? customerAddressId;
  final String? height;
  final String? weight;
  final String? wardrobeKitId;
  final String? wardrobeKitProductId;
  final int? durationDays;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (gender != null && gender!.isNotEmpty) map['gender'] = gender;
    if (bodyType != null && bodyType!.isNotEmpty) map['bodyType'] = bodyType;
    if (kitType != null && kitType!.isNotEmpty) map['kit_type'] = kitType;
    if (deliveryDate != null && deliveryDate!.isNotEmpty) {
      map['delivery_date'] = deliveryDate;
    }
    if (deliveryTime != null && deliveryTime!.isNotEmpty) {
      map['delivery_time'] = deliveryTime;
    }
    if (deliveryTime != null && deliveryTime!.isNotEmpty) {
      map['deliveryTime'] = deliveryTime;
    }
    if (deliveryDate != null && deliveryDate!.isNotEmpty) {
      map['deliveryDate'] = deliveryDate;
    }
    if (customerAddressId != null && customerAddressId!.isNotEmpty) {
      map['customerAddressId'] = customerAddressId;
    }
    if (height != null && height!.isNotEmpty) map['height'] = height;
    if (weight != null && weight!.isNotEmpty) map['weight'] = weight;
    if (wardrobeKitId != null && wardrobeKitId!.isNotEmpty) {
      map['wardrobe_kit_id'] = wardrobeKitId;
      map['kitId'] = wardrobeKitId;
    }
    if (wardrobeKitProductId != null && wardrobeKitProductId!.isNotEmpty) {
      map['wardrobe_kit_product_id'] = wardrobeKitProductId;
    }
    if (durationDays != null && durationDays! > 0) {
      map['duration_days'] = durationDays;
      map['durationDays'] = durationDays;
    }
    return map;
  }
}

class RemoteCartItem {
  const RemoteCartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.variantId,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.kitDetails,
  });

  final String productId;
  final String productName;
  final String? variantId;
  final int quantity;
  final num unitPrice;
  final num lineTotal;
  final RemoteCartKitDetails? kitDetails;

  factory RemoteCartItem.fromJson(Map<String, dynamic> json) {
    final kitRaw = json['kitDetails'] ?? json['kit_details'];
    return RemoteCartItem(
      productId: json['productId']?.toString() ??
          json['product_id']?.toString() ??
          '',
      productName: json['productName']?.toString() ??
          json['product_name']?.toString() ??
          'Product',
      variantId: _nonEmpty(json['variantId'] ?? json['variant_id']),
      quantity: _parseInt(json['quantity']) ?? 0,
      unitPrice: _parseNum(json['unitPrice'] ?? json['unit_price']) ?? 0,
      lineTotal: _parseNum(json['lineTotal'] ?? json['line_total']) ?? 0,
      kitDetails: kitRaw is Map<String, dynamic>
          ? RemoteCartKitDetails(
              gender: _nonEmpty(kitRaw['gender']),
              bodyType: _nonEmpty(kitRaw['bodyType'] ?? kitRaw['body_type']),
              kitType: _nonEmpty(kitRaw['kit_type'] ?? kitRaw['kitType']),
              deliveryDate:
                  _nonEmpty(kitRaw['delivery_date'] ?? kitRaw['deliveryDate']),
              deliveryTime:
                  _nonEmpty(kitRaw['delivery_time'] ?? kitRaw['deliveryTime']),
              customerAddressId: _nonEmpty(
                kitRaw['customerAddressId'] ?? kitRaw['customer_address_id'],
              ),
              height: _nonEmpty(kitRaw['height']),
              weight: _nonEmpty(kitRaw['weight']),
              wardrobeKitId: _nonEmpty(
                kitRaw['wardrobe_kit_id'] ??
                    kitRaw['wardrobeKitId'] ??
                    kitRaw['kitId'],
              ),
              wardrobeKitProductId: _nonEmpty(
                kitRaw['wardrobe_kit_product_id'] ??
                    kitRaw['wardrobeKitProductId'],
              ),
              durationDays: _parseInt(
                kitRaw['duration_days'] ?? kitRaw['durationDays'],
              ),
            )
          : null,
    );
  }
}

class RemoteCart {
  const RemoteCart({
    required this.id,
    required this.items,
    this.customerAddressId,
    this.subtotal = 0,
    this.deliveryCharge = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.itemCount = 0,
    this.cartStatus = 'active',
  });

  final String id;
  final List<RemoteCartItem> items;
  final String? customerAddressId;
  final num subtotal;
  final num deliveryCharge;
  final num taxAmount;
  final num totalAmount;
  final int itemCount;
  final String cartStatus;

  bool get isEmpty => items.isEmpty;

  factory RemoteCart.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['cartItems'] ?? json['cart_items'] ?? json['items'];
    final items = <RemoteCartItem>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map<String, dynamic>) {
          final parsed = RemoteCartItem.fromJson(item);
          if (parsed.productId.isNotEmpty && parsed.quantity > 0) {
            items.add(parsed);
          }
        }
      }
    }

    return RemoteCart(
      id: json['id']?.toString() ?? '',
      items: items,
      customerAddressId: _nonEmpty(
        json['customer_address_id'] ?? json['customerAddressId'],
      ),
      subtotal: _parseNum(json['subtotal']) ?? 0,
      deliveryCharge:
          _parseNum(json['delivery_charge'] ?? json['deliveryCharge']) ?? 0,
      taxAmount: _parseNum(json['tax_amount'] ?? json['taxAmount']) ?? 0,
      totalAmount:
          _parseNum(json['total_amount'] ?? json['totalAmount']) ?? 0,
      itemCount: _parseInt(json['item_count'] ?? json['itemCount']) ??
          items.fold<int>(0, (sum, item) => sum + item.quantity),
      cartStatus: json['cart_status']?.toString() ??
          json['cartStatus']?.toString() ??
          'active',
    );
  }
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

num? _parseNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}
