class ProductVariant {
  final String id;
  final String productId;
  final String variantName;
  final String actualPrice;
  final String? costPrice;
  final String? primaryImageUrl;
  final int stockOnHand;
  final String stockStatus;
  final Map<String, String> options;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.variantName,
    required this.actualPrice,
    this.costPrice,
    this.primaryImageUrl,
    this.stockOnHand = 0,
    this.stockStatus = 'IN_STOCK',
    this.options = const {},
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];
    final options = <String, String>{};
    if (optionsRaw is Map) {
      optionsRaw.forEach((key, value) {
        options[key.toString()] = value?.toString() ?? '';
      });
    }

    return ProductVariant(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ??
          json['productId']?.toString() ??
          '',
      variantName: json['variant_name']?.toString() ??
          json['variantName']?.toString() ??
          '',
      actualPrice: json['actual_price']?.toString() ??
          json['actualPrice']?.toString() ??
          '0',
      costPrice: json['cost_price']?.toString() ??
          json['costPrice']?.toString(),
      primaryImageUrl: _nonEmpty(
        json['primary_image_url'] ?? json['primaryImageUrl'],
      ),
      stockOnHand: _parseInt(json['stock_on_hand'] ?? json['stockOnHand']) ?? 0,
      stockStatus: json['stock_status']?.toString() ??
          json['stockStatus']?.toString() ??
          'IN_STOCK',
      options: options,
    );
  }
}

String? _nonEmpty(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
