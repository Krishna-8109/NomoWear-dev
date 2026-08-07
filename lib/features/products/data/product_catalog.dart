import 'package:nomowear/features/products/data/models/product.dart';

class ProductCatalog {
  ProductCatalog._();

  static const homeWardrobeKeys = [
    'Comfort Wardrobe',
    'Professional Wardrobe',
    'Premium Wardrobe',
    'Kids Wardrobe',
  ];

  static bool isKidsProduct(Product product) {
    if (!product.isSingleItem) return false;
    final category = product.categoryName?.toLowerCase() ?? '';
    return category == 'kids wardrobe' || category.contains('kids');
  }

  static bool isEssentialsProduct(Product product) {
    if (!product.isSingleItem) return false;
    final cat = product.categoryName?.toLowerCase() ?? '';
    return cat == 'essentials' ||
        cat == 'essentials wardrobe' ||
        cat.contains('essentials');
  }

  /// Single items bought directly (essentials + kids), not via wardrobe kits.
  static bool isDirectPurchaseProduct(Product product) =>
      isEssentialsProduct(product) || isKidsProduct(product);

  static Product? findWardrobeKit(List<Product> products, String categoryOrName) {
    final kits = products.where((p) => p.isWardrobeKit).toList();
    final needle = categoryOrName.toLowerCase().trim();

    for (final kit in kits) {
      if (kit.productName.toLowerCase() == needle) return kit;
      final category = kit.categoryName?.toLowerCase() ?? '';
      if (category == needle) return kit;
    }

    final normalized = needle.replaceAll(' wardrobe', '').trim();
    if (normalized.isNotEmpty) {
      for (final kit in kits) {
        final name = kit.productName.toLowerCase();
        final category = kit.categoryName?.toLowerCase() ?? '';
        if (name.contains(normalized) || category.contains(normalized)) {
          return kit;
        }
      }
    }

    return null;
  }

  static List<Product> homeWardrobeCards(List<Product> products) {
    final result = <Product>[];
    for (final key in homeWardrobeKeys) {
      if (key == 'Kids Wardrobe') {
        final kit = findWardrobeKit(products, key);
        if (kit != null) {
          result.add(kit);
        } else {
          final featured = kidsFeaturedProduct(products);
          if (featured != null) result.add(featured);
        }
        continue;
      }

      final match = findWardrobeKit(products, key);
      if (match != null) result.add(match);
    }

    if (result.isNotEmpty) return result;

    return products
        .where(
          (p) =>
              p.isWardrobeKit &&
              p.productName.toLowerCase().contains('wardrobe') &&
              !isKidsProduct(p),
        )
        .toList(growable: false);
  }

  static Product? essentialsWardrobeProduct(List<Product> products) {
    for (final product in products) {
      if (product.productName == 'Essentials Wardrobe') return product;
    }
    final essentials = essentialsItems(products);
    if (essentials.isNotEmpty) return essentials.first;
    return null;
  }

  static Product? kidsFeaturedProduct(List<Product> products) {
    final kids = kidsItems(products);
    if (kids.isEmpty) return null;
    return kids.first;
  }

  static List<Product> essentialsItems(List<Product> products) {
    return products
        .where(isEssentialsProduct)
        .toList(growable: false);
  }

  static List<Product> kidsItems(List<Product> products) {
    return products.where(isKidsProduct).toList(growable: false);
  }

  static List<Product> kitListingItems(
    Product kit,
    List<Product> allProducts,
  ) {
    final nested = kit.items
        .where((item) => !isDirectPurchaseProduct(item))
        .toList(growable: false);
    if (nested.isNotEmpty) return nested;

    if (kit.kitItems.isEmpty) return const [];

    final byId = {for (final product in allProducts) product.id: product};
    final resolved = <Product>[];
    final seen = <String>{};
    for (final ref in kit.kitItems) {
      final product = byId[ref.id];
      if (product == null || isDirectPurchaseProduct(product)) continue;
      if (seen.add(product.id)) resolved.add(product);
    }
    return resolved;
  }

  static List<Product> wardrobeListingItems(
    List<Product> products,
    String category,
  ) {
    if (category == 'Essentials Wardrobe') {
      return essentialsItems(products);
    }

    if (category == 'Kids Wardrobe') {
      return kidsItems(products);
    }

    final kit = findWardrobeKit(products, category);
    if (kit != null) {
      final items = kitListingItems(kit, products);
      if (items.isNotEmpty) return items;
    }

    final normalized = category.toLowerCase().replaceAll(' wardrobe', '');
    return products
        .where(
          (p) =>
              p.isSingleItem &&
              !isDirectPurchaseProduct(p) &&
              (p.categoryName == category ||
                  (p.categoryName?.toLowerCase().contains(normalized) ??
                      false)),
        )
        .toList(growable: false);
  }

  static String wardrobeDisplayCategory(Product kit) {
    if (kit.productName.endsWith(' Wardrobe')) {
      return kit.productName;
    }
    return kit.categoryName ?? kit.productName;
  }
}
