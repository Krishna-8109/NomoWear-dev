class WardrobePlan {
  final String id;
  final String categoryId;
  final String? categoryName;
  final String name;
  final String planCode;
  final String planRef;
  final String? description;
  final int durationDays;
  final int maxGarments;
  final num monthPrice;
  final num yearPrice;
  final num price;
  final List<String> features;
  final int displayOrder;
  final bool isActive;

  const WardrobePlan({
    required this.id,
    required this.categoryId,
    this.categoryName,
    required this.name,
    required this.planCode,
    required this.planRef,
    this.description,
    required this.durationDays,
    required this.maxGarments,
    required this.monthPrice,
    required this.yearPrice,
    required this.price,
    this.features = const [],
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory WardrobePlan.fromJson(Map<String, dynamic> json) {
    final featuresRaw = json['features'];
    final features = <String>[];
    if (featuresRaw is List) {
      for (final item in featuresRaw) {
        final text = item?.toString().trim();
        if (text != null && text.isNotEmpty) features.add(text);
      }
    }

    return WardrobePlan(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ??
          json['category_id']?.toString() ??
          '',
      categoryName: _nonEmpty(json['categoryName'] ?? json['category_name']),
      name: json['name']?.toString() ?? '',
      planCode: json['planCode']?.toString() ??
          json['plan_code']?.toString() ??
          '',
      planRef: _nonEmpty(json['planRef'] ?? json['plan_ref']) ??
          json['id']?.toString() ??
          _nonEmpty(json['planCode'] ?? json['plan_code']) ??
          '',
      description: _nonEmpty(json['description']),
      durationDays: _parseInt(json['durationDays'] ?? json['duration_days']) ?? 0,
      maxGarments:
          _parseInt(json['maxGarments'] ?? json['max_garments']) ?? 0,
      monthPrice: _parseNum(json['monthPrice'] ?? json['month_price']) ?? 0,
      yearPrice: _parseNum(json['yearPrice'] ?? json['year_price']) ?? 0,
      price: _parseNum(json['price']) ?? 0,
      features: features,
      displayOrder:
          _parseInt(json['displayOrder'] ?? json['display_order']) ?? 0,
      isActive: _parseBool(json['isActive'] ?? json['is_active'] ?? true),
    );
  }
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }
  return true;
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

String? _nonEmpty(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
