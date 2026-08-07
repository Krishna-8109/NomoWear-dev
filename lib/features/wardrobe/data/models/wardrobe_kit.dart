class WardrobeKit {
  const WardrobeKit({
    required this.id,
    required this.kitName,
    required this.kitSlug,
    required this.description,
    required this.kitType,
    required this.gender,
    required this.durationDays,
    required this.maxItems,
    required this.price,
    this.imageUrl,
    this.status = 1,
  });

  final String id;
  final String kitName;
  final String kitSlug;
  final String description;
  final String kitType;
  final String gender;
  final int durationDays;
  final int maxItems;
  final String price;
  final String? imageUrl;
  final int status;

  bool get isActive => status == 1;

  String get displayTitle {
    final name = kitName.trim();
    if (name.isEmpty) return '$durationDays-Day Wardrobe Kit';
    return name;
  }

  /// Matches Male / Female selection; unisex kits are available to both.
  bool matchesGender(String selectedGender) {
    final kitGender = gender.trim().toLowerCase();
    if (kitGender.isEmpty ||
        kitGender == 'unisex' ||
        kitGender == 'both' ||
        kitGender == 'all') {
      return true;
    }
    return kitGender == selectedGender.trim().toLowerCase();
  }

  factory WardrobeKit.fromJson(Map<String, dynamic> json) {
    final kitName = json['kit_name']?.toString() ??
        json['kitName']?.toString() ??
        '';
    final kitSlug = json['kit_slug']?.toString() ??
        json['kitSlug']?.toString() ??
        '';
    final apiDays =
        _parseInt(json['duration_days'] ?? json['durationDays']);
    final namedDays = _daysFromName(kitName) ?? _daysFromName(kitSlug);

    // Prefer days implied by kit name/slug when API duration is missing or
    // clearly wrong (e.g. "7-Day Kit" with duration_days: 30).
    final durationDays = namedDays ?? apiDays ?? 1;

    return WardrobeKit(
      id: json['id']?.toString() ?? '',
      kitName: kitName,
      kitSlug: kitSlug,
      description: json['description']?.toString() ?? '',
      kitType: json['kit_type']?.toString() ??
          json['kitType']?.toString() ??
          'standard',
      gender: json['gender']?.toString() ?? '',
      durationDays: durationDays,
      maxItems: _parseInt(json['max_items'] ?? json['maxItems']) ?? 0,
      price: json['price']?.toString() ?? '0',
      imageUrl: _nonEmpty(json['image_url'] ?? json['imageUrl']),
      status: _parseInt(json['status']) ?? 1,
    );
  }

  /// Extracts N from patterns like "7-Day Wardrobe Kit" / "5-day-kit-...".
  static int? _daysFromName(String value) {
    final match = RegExp(
      r'(\d+)\s*[-_]?\s*day',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
