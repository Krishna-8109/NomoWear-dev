class WardrobeCategory {
  final String id;
  final String name;
  final String? status;
  final String? imageUrl;
  final List<String> features;
  final List<String> returnItems;

  const WardrobeCategory({
    required this.id,
    required this.name,
    this.status,
    this.imageUrl,
    this.features = const [],
    this.returnItems = const [],
  });

  bool get isActive {
    final value = status?.trim().toLowerCase();
    if (value == null || value.isEmpty) return true;
    return value == 'active' || value == 'true' || value == '1' || value == 'enabled';
  }

  String? get featuresSubtitle {
    final parts = features
        .map((feature) => feature.trim())
        .where((feature) => feature.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  bool get isKids {
    return name.toLowerCase().contains('kids');
  }

  bool get isEssentials {
    return name.toLowerCase().contains('essential');
  }

  factory WardrobeCategory.fromJson(Map<String, dynamic> json) {
    return WardrobeCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      status: _statusValue(
        json['status'] ?? json['is_active'] ?? json['isActive'],
      ),
      imageUrl: _nonEmpty(json['image_url'] ?? json['imageUrl']),
      features: _stringList(json['features']),
      returnItems: _stringList(json['return_items'] ?? json['returnItems']),
    );
  }
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _nonEmpty(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

String? _statusValue(dynamic value) {
  if (value is bool) return value ? 'active' : 'inactive';
  return _nonEmpty(value);
}
