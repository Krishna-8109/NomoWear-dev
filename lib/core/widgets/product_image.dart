import 'package:flutter/material.dart';
import 'package:nomowear/theme/theme_helper.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackAsset,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? fallbackAsset;

  static String resolveUrl(String? url, {String? fallback}) {
    final trimmed = url?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final fallbackTrimmed = fallback?.trim();
    if (fallbackTrimmed != null && fallbackTrimmed.isNotEmpty) {
      return fallbackTrimmed;
    }
    return '';
  }

  static bool isNetworkUrl(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static ImageProvider imageProvider(String? url, {String? fallback}) {
    final resolved = resolveUrl(url, fallback: fallback);
    if (isNetworkUrl(resolved)) return NetworkImage(resolved);
    return AssetImage(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveUrl(imageUrl, fallback: fallbackAsset);
    if (resolved.isEmpty) {
      return _placeholder();
    }
    Widget image;

    if (isNetworkUrl(resolved)) {
      image = Image.network(
        resolved,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      image = Image.asset(
        resolved,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _placeholder() {
    final iconSize = ((height ?? width ?? 48) * 0.35).clamp(16.0, 40.0);
    return Container(
      width: width,
      height: height,
      color: AppColours.primary.withOpacity(0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: AppColours.primary.withOpacity(0.35),
        size: iconSize,
      ),
    );
  }
}
