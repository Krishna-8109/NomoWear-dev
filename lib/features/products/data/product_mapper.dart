import 'package:nomowear/core/utils/image_constant.dart';
import 'package:nomowear/features/products/data/models/product.dart';
import 'package:nomowear/features/products/data/product_catalog.dart';
import 'package:nomowear/features/products/data/models/product_variant.dart';
import 'package:nomowear/features/wardrobe/presentation/screens/wardrobe_screen.dart';

class ProductMapper {
  ProductMapper._();

  static WardrobeItem toWardrobeItem(
    Product product, {
    String? category,
  }) {
    final listingCategory = category ??
        (ProductCatalog.isKidsProduct(product)
            ? 'Kids Wardrobe'
            : ProductCatalog.isEssentialsProduct(product)
                ? 'Essentials Wardrobe'
                : product.categoryName);
    final images = _productImages(product);
    final imageUrl =
        images.isNotEmpty ? images.first : ImageConstant.comfortWearImg7;
    final variantInfo = _extractVariantInfo(product, images);
    final isKids = ProductCatalog.isKidsProduct(product) ||
        (listingCategory?.toLowerCase().contains('kids') ?? false);

    return WardrobeItem(
      productId: product.id,
      title: product.productName,
      description: _descriptionFor(product),
      imageUrl: imageUrl,
      price: _formatPrice(product.actualPrice),
      colorVariantImages: variantInfo.colorImages,
      colorNames: variantInfo.colorNames,
      sizes: variantInfo.sizes,
      ages: isKids ? variantInfo.sizes : const [],
      genderTag: _genderTagFor(product),
      productDetails: _productDetailsFor(product),
      category: listingCategory,
      imageUrls: images,
      variants: product.variants,
    );
  }

  static List<String> _productImages(Product product) {
    if (product.imageUrls.isNotEmpty) return product.imageUrls;
    if (product.primaryImageUrl != null) {
      return [product.primaryImageUrl!];
    }
    return const [];
  }

  static String _descriptionFor(Product product) {
    final slug = product.productSlug.replaceAll('-', ' ').trim();
    if (slug.isNotEmpty &&
        slug.toLowerCase() != product.productName.toLowerCase()) {
      return slug;
    }
    return product.productName;
  }

  static String formatPrice(String actualPrice) => _formatPrice(actualPrice);

  static String _formatPrice(String actualPrice) {
    final parsed = double.tryParse(actualPrice);
    if (parsed == null) return '₹ $actualPrice';
    if (parsed == parsed.roundToDouble()) {
      return '₹ ${parsed.round()}';
    }
    return '₹ $actualPrice';
  }

  static List<String> _productDetailsFor(Product product) {
    final details = <String>[];
    if (product.stockStatus.isNotEmpty) {
      details.add('Stock: ${product.stockStatus.replaceAll('_', ' ')}');
    }
    if (product.categoryName != null) {
      details.add('Category: ${product.categoryName}');
    }
    if (product.attributes.isNotEmpty) {
      product.attributes.forEach((key, value) {
        details.add('$key: $value');
      });
    }
    if (details.isEmpty) {
      return const [
        'Fabric: Cotton',
        'Fit: Slim Fit',
        'Stretchable',
        'Length: Regular',
      ];
    }
    return details;
  }

  /// Resolves `'men' | 'women' | 'boy' | 'girl'` from attributes or product name.
  static String? _genderTagFor(Product product) {
    for (final entry in product.attributes.entries) {
      if (entry.key.toLowerCase() != 'gender' &&
          entry.key.toLowerCase() != 'sex') {
        continue;
      }
      final tag = _normalizeGenderLabel(entry.value);
      if (tag != null) return tag;
    }

    return _normalizeGenderLabel(product.productName);
  }

  static String? _normalizeGenderLabel(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;

    if (RegExp(r'\bboy(s)?\b').hasMatch(value) || value == 'b') {
      return 'boy';
    }
    if (RegExp(r'\bgirl(s)?\b').hasMatch(value) || value == 'g') {
      return 'girl';
    }
    if (RegExp(r'\bwom[ae]n\b').hasMatch(value) ||
        value == 'w' ||
        value == 'female') {
      return 'women';
    }
    if (RegExp(r'\bmen\b').hasMatch(value) ||
        RegExp(r'\bman\b').hasMatch(value) ||
        value == 'm' ||
        value == 'male') {
      return 'men';
    }
    return null;
  }

  static _VariantInfo _extractVariantInfo(
    Product product,
    List<String> fallbackImages,
  ) {
    if (product.variants.isEmpty) {
      return _VariantInfo(
        colorNames: const [],
        colorImages: const [],
        sizes: _sizesFromAttributes(product),
      );
    }

    final sizes = <String>{};
    final colors = <String>[];

    for (final variant in product.variants) {
      for (final entry in variant.options.entries) {
        final key = entry.key.trim().toLowerCase();
        final value = entry.value.trim();
        if (value.isEmpty) continue;

        if (key == 'size' || key == 'age' || _isSizeValue(value)) {
          // Keep original casing for kids ages like `2-3Y`.
          sizes.add(value);
        } else if (key == 'color' || key == 'colour') {
          final label = value.toUpperCase();
          if (!colors.contains(label)) colors.add(label);
        }
      }
    }

    // Color-only variants: still expose color swatches from images.
    final images = fallbackImages.isNotEmpty
        ? fallbackImages
        : product.variants
            .map((v) => v.primaryImageUrl)
            .whereType<String>()
            .toList();

    if (sizes.isEmpty) {
      sizes.addAll(_sizesFromAttributes(product));
    }

    return _VariantInfo(
      colorNames: colors,
      colorImages: images.isNotEmpty ? images : fallbackImages,
      sizes: sizes.toList(growable: false),
    );
  }

  static List<String> _sizesFromAttributes(Product product) {
    final sizes = <String>[];
    for (final entry in product.attributes.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key != 'size' && key != 'age' && key != 'ages') continue;
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      sizes.add(value);
    }
    return sizes;
  }

  static bool _isSizeValue(String value) {
    final upper = value.toUpperCase().trim();
    const adult = {'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'};
    if (adult.contains(upper)) return true;
    // Kids age-style sizes: 0-6M, 2-4Y, 2-3 Y, etc.
    return RegExp(
      r'^\d+\s*-\s*\d+\s*(M|Y|Months?|Years?)?$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  static ProductVariant? matchingVariant({
    required List<ProductVariant> variants,
    String? selectedColor,
    required String selectedSize,
  }) {
    if (variants.isEmpty) return null;

    String? optionValue(Map<String, String> options, String key) {
      for (final entry in options.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) {
          return entry.value.trim();
        }
      }
      return null;
    }

    final wantedColor = selectedColor?.trim().toUpperCase();
    final wantedSize = selectedSize.trim().toUpperCase();

    for (final variant in variants) {
      final color = optionValue(variant.options, 'Color')?.toUpperCase();
      final size = optionValue(variant.options, 'Size')?.toUpperCase();

      final colorMatches = wantedColor == null ||
          wantedColor.isEmpty ||
          color == wantedColor;
      final sizeMatches = size == null || size == wantedSize;

      if (colorMatches && sizeMatches) return variant;
    }

    // Fallback 1: keep size, ignore color.
    for (final variant in variants) {
      final size = optionValue(variant.options, 'Size')?.toUpperCase();
      if (size == wantedSize) return variant;
    }

    // Fallback 2: keep color, ignore size.
    if (wantedColor != null && wantedColor.isNotEmpty) {
      for (final variant in variants) {
        final color = optionValue(variant.options, 'Color')?.toUpperCase();
        if (color == wantedColor) return variant;
      }
    }

    return variants.first;
  }
}

class _VariantInfo {
  final List<String> colorNames;
  final List<String> colorImages;
  final List<String> sizes;

  const _VariantInfo({
    required this.colorNames,
    required this.colorImages,
    required this.sizes,
  });
}
