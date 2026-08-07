class PromoBanner {
  final String id;
  final String title;
  final String? description;
  final String imageUrl;
  final String? redirectUrl;
  final bool isActive;

  const PromoBanner({
    required this.id,
    required this.title,
    this.description,
    required this.imageUrl,
    this.redirectUrl,
    this.isActive = true,
  });

  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    return PromoBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: _nonEmpty(json['description']),
      imageUrl: json['image_url']?.toString() ??
          json['imageUrl']?.toString() ??
          '',
      redirectUrl: _nonEmpty(json['redirect_url'] ?? json['redirectUrl']),
      isActive: _parseBool(json['is_active'] ?? json['isActive'] ?? true),
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

String? _nonEmpty(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
