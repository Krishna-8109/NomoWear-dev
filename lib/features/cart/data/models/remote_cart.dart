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
    this.selectedItems,
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
  final List<dynamic>? selectedItems;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (gender != null && gender!.isNotEmpty) map['gender'] = gender;
    if (bodyType != null && bodyType!.isNotEmpty) map['bodyType'] = bodyType;
    if (kitType != null && kitType!.isNotEmpty) map['kit_type'] = kitType;
    if (deliveryDate != null && deliveryDate!.isNotEmpty) {
      map['delivery_date'] = deliveryDate;
      map['deliveryDate'] = deliveryDate;
    }
    if (deliveryTime != null && deliveryTime!.isNotEmpty) {
      map['delivery_time'] = deliveryTime;
      map['deliveryTime'] = deliveryTime;
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
    if (selectedItems != null && selectedItems!.isNotEmpty) {
      map['selectedItems'] = selectedItems;
    }
    return map;
  }
}

class RemoteCartItem {
  const RemoteCartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.itemType,
    this.variantId,
    this.imageUrl,
    this.categoryName,
    this.productClass,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.size,
    this.kitDetails,
  });

  final String productId;
  final String productName;
  final String? variantId;
  final String? imageUrl;
  final String? categoryName;
  final String? productClass;
  final String itemType;
  final int quantity;
  final num unitPrice;
  final num lineTotal;
  final String? size;
  final RemoteCartKitDetails? kitDetails;

  factory RemoteCartItem.fromJson(
    Map<String, dynamic> json, {
    String defaultType = '',
  }) {
    final kitRaw = json['kitDetails'] ?? json['kit_details'];
    return RemoteCartItem(
      productId: json['productId']?.toString() ??
          json['product_id']?.toString() ??
          '',
      productName: json['productName']?.toString() ??
          json['product_name']?.toString() ??
          'Product',
      variantId: _nonEmpty(json['variantId'] ?? json['variant_id']),
      imageUrl: _nonEmpty(
        json['imageUrl'] ??
            json['image_url'] ??
            json['primaryImageUrl'] ??
            json['primary_image_url'],
      ),
      categoryName: _nonEmpty(
        json['categoryName'] ?? json['category_name'] ?? json['category'],
      ),
      productClass: _nonEmpty(json['productClass'] ?? json['product_class']),
      itemType: _normalizeItemType(
        json['item_type'] ?? json['itemType'] ?? defaultType,
      ),
      quantity: _parseInt(json['quantity']) ?? 0,
      unitPrice: _parseNum(json['unitPrice'] ?? json['unit_price'] ?? json['price']) ?? 0,
      lineTotal: _parseNum(json['lineTotal'] ?? json['line_total'] ?? json['price']) ?? 0,
      size: _nonEmpty(json['size'] ?? json['selectedSize']),
      kitDetails: kitRaw is Map
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
              selectedItems: kitRaw['selectedItems'] is List
                  ? List.from(kitRaw['selectedItems'] as List)
                  : null,
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
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.itemCount = 0,
    this.cartStatus = 'active',
    this.updatedAt,
    this.subscriptionCount = 0,
    this.nonSubscriptionCount = 0,
    this.essentialsCount = 0,
    this.kidsCount = 0,
  });

  final String id;
  final List<RemoteCartItem> items;
  final String? customerAddressId;
  final num subtotal;
  final num deliveryCharge;
  final num discountAmount;
  final num taxAmount;
  final num totalAmount;
  final int itemCount;
  final String cartStatus;
  final String? updatedAt;
  final int subscriptionCount;
  final int nonSubscriptionCount;
  final int essentialsCount;
  final int kidsCount;

  bool get isEmpty => itemCount <= 0 && items.isEmpty;

  factory RemoteCart.fromJson(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final summary = json['summary'];
    final cartItems = _parseItemList(
      json['cartItems'] ?? json['cart_items'] ?? json['items'],
    );
    final sectionItems = _itemsFromSections(sectionsRaw);
    final items = _canonicalCartLines(cartItems, sectionItems);

    int sectionCount(String key) {
      if (sectionsRaw is! Map) return 0;
      final block = sectionsRaw[key];
      if (block is! Map) return 0;
      final listed = block['item_count'] ?? block['itemCount'];
      if (listed is num) return listed.toInt();
      final list = block['items'];
      if (list is List) {
        return list.fold<int>(0, (sum, row) {
          if (row is! Map) return sum;
          return sum + (_parseInt(row['quantity']) ?? 0);
        });
      }
      return 0;
    }

    final summaryCount = summary is Map
        ? _parseInt(summary['item_count'] ?? summary['itemCount'])
        : null;
    final topCount = _parseInt(json['item_count'] ?? json['itemCount']);
    final qtySum = items.fold<int>(0, (sum, item) => sum + item.quantity);

    return RemoteCart(
      id: json['id']?.toString() ?? '',
      items: items,
      customerAddressId: _nonEmpty(
        json['customer_address_id'] ?? json['customerAddressId'],
      ),
      subtotal: _parseNum(json['subtotal']) ?? 0,
      deliveryCharge:
          _parseNum(json['delivery_charge'] ?? json['deliveryCharge']) ?? 0,
      discountAmount: _parseNum(
            json['discount_amount'] ??
                json['discountAmount'] ??
                (summary is Map
                    ? (summary['discount_amount'] ?? summary['discountAmount'])
                    : null),
          ) ??
          0,
      taxAmount: _parseNum(json['tax_amount'] ?? json['taxAmount']) ?? 0,
      totalAmount:
          _parseNum(json['total_amount'] ?? json['totalAmount']) ?? 0,
      itemCount: qtySum,
      cartStatus: json['cart_status']?.toString() ??
          json['cartStatus']?.toString() ??
          'active',
      updatedAt: _nonEmpty(json['updated_at'] ?? json['updatedAt']),
      subscriptionCount: sectionCount('subscription'),
      nonSubscriptionCount: sectionCount('non_subscription'),
      essentialsCount: sectionCount('essentials'),
      kidsCount: sectionCount('kids'),
    );
  }
}

String _normalizeItemType(dynamic raw) {
  final type = raw?.toString().trim().toLowerCase() ?? '';
  if (type == 'subscription') return 'subscription';
  if (type == 'non_subscription' ||
      type == 'non-subscription' ||
      type == 'paid' ||
      type == 'paid_rental') {
    return 'non_subscription';
  }
  if (type == 'essentials' || type == 'essential') return 'essentials';
  if (type == 'kids' || type == 'kid') return 'kids';
  return '';
}

List<RemoteCartItem> _canonicalCartLines(
  List<RemoteCartItem> cartItems,
  List<RemoteCartItem> sectionItems,
) {
  if (sectionItems.isEmpty) return cartItems;
  final extras = <RemoteCartItem>[];
  for (final item in cartItems) {
    final inSection = sectionItems.any(
      (section) =>
          section.productId.trim() == item.productId.trim() &&
          (section.variantId ?? '') == (item.variantId ?? '') &&
          section.itemType == item.itemType,
    );
    if (!inSection) extras.add(item);
  }
  return [...sectionItems, ...extras];
}

void _flattenAndAdd(
  RemoteCartItem parsed,
  List<RemoteCartItem> items,
  String defaultType,
) {
  if (parsed.productId.isEmpty || parsed.quantity <= 0) return;

  final selectedItems = parsed.kitDetails?.selectedItems;
  if (selectedItems != null && selectedItems.isNotEmpty) {
    for (final sub in selectedItems) {
      if (sub is Map) {
        final subMap = Map<String, dynamic>.from(sub);
        subMap['item_type'] = subMap['item_type'] ?? parsed.itemType;
        
        // Preserve the parent kit details (which contains the Master Kit Product ID)
        // so that CartBloc can still look up state.wardrobeKitProductId!
        if (parsed.kitDetails != null && 
            !subMap.containsKey('kitDetails') && 
            !subMap.containsKey('kit_details')) {
          final kitJson = parsed.kitDetails!.toJson();
          // We don't want to deeply nest the garments onto each garment!
          kitJson.remove('selectedItems');
          
          // INJECT the Master Kit's Product ID so CartBloc knows it!
          kitJson['wardrobe_kit_product_id'] = parsed.productId;
          
          subMap['kitDetails'] = kitJson;
        }

        final subParsed = RemoteCartItem.fromJson(
          subMap,
          defaultType: defaultType,
        );
        if (subParsed.productId.isNotEmpty && subParsed.quantity > 0) {
          items.add(subParsed);
        }
      }
    }
  } else {
    items.add(parsed);
  }
}

List<RemoteCartItem> _parseItemList(dynamic itemsRaw) {
  final items = <RemoteCartItem>[];
  if (itemsRaw is! List) return items;
  for (final item in itemsRaw) {
    if (item is Map) {
      final parsed = RemoteCartItem.fromJson(Map<String, dynamic>.from(item));
      _flattenAndAdd(parsed, items, parsed.itemType);
    }
  }
  return items;
}

List<RemoteCartItem> _itemsFromSections(dynamic sections) {
  if (sections is! Map) return const [];
  final map = Map<String, dynamic>.from(sections);
  final items = <RemoteCartItem>[];

  void addSection(String key) {
    final block = map[key];
    if (block is! Map) return;
    final list = block['items'];
    if (list is! List) return;
    for (final row in list) {
      if (row is! Map) continue;
      final parsed = RemoteCartItem.fromJson(
        Map<String, dynamic>.from(row),
        defaultType: key,
      );
      _flattenAndAdd(parsed, items, key);
    }
  }

  addSection('subscription');
  addSection('non_subscription');
  addSection('essentials');
  addSection('kids');
  return items;
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
