import 'package:nomowear/features/products/data/models/product.dart';

class ProductCatalog {
  ProductCatalog._();

  /// Exact Admin / backend `tab` query values for `GET /mobile/v1/products`.
  static const wardrobeApiTabs = [
    'Comfort wardrobe',
    'Professional wardrobe',
    'Premium wardrobe',
    'Kids wardrobe',
    'Essentials wardrobe',
  ];

  /// Non-essentials tabs used for category-lock matching only — not card inventory.
  static List<String> get homeWardrobeKeys => wardrobeApiTabs
      .where((tab) => !isEssentialsTab(tab))
      .toList(growable: false);

  static bool isEssentialsTab(String tab) {
    return tab.trim().toLowerCase().contains('essentials');
  }

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

  /// Maps a display category (e.g. product name) to the backend `tab` value.
  static String? apiTabForCategory(String category) {
    final needle = category.trim().toLowerCase();
    if (needle.isEmpty) return null;

    for (final tab in wardrobeApiTabs) {
      if (needle == tab.toLowerCase()) return tab;
    }

    for (final tab in wardrobeApiTabs) {
      final core = tab.toLowerCase().replaceAll('wardrobe', '').trim();
      if (core.isEmpty) continue;
      if (needle.contains(core)) return tab;
    }

    return null;
  }

  /// One Home card from a tab response. Empty `data` → no card.
  static Product? cardFromTabProducts(List<Product> products) {
    if (products.isEmpty) return null;
    for (final product in products) {
      if (product.isWardrobeKit) return product;
    }
    return products.first;
  }

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

  static List<Product> essentialsItems(List<Product> products) {
    return products.where(isEssentialsProduct).toList(growable: false);
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
    final tab = apiTabForCategory(category);
    final isEssentials = tab != null
        ? isEssentialsTab(tab)
        : category.toLowerCase().contains('essential');
    final isKids = tab != null
        ? tab.toLowerCase().contains('kids')
        : category.toLowerCase().contains('kids');

    if (isEssentials) {
      final items = essentialsItems(products);
      if (items.isNotEmpty) return items;
      return _nonKitProducts(products);
    }

    if (isKids) {
      // Kids Wear should display both single items and Wardrobe Kits (e.g. 'Kids Wardrobe')
      final items = products.where((p) {
        final cat = p.categoryName?.toLowerCase() ?? '';
        final isKidsCat = cat == 'kids wardrobe' || cat.contains('kids');
        return isKidsCat || isKidsProduct(p);
      }).toList(growable: false);
      
      if (items.isNotEmpty) return items;
      return products;
    }

    final isProfessional = tab != null
        ? tab.toLowerCase().contains('professional')
        : category.toLowerCase().contains('professional');

    if (isProfessional) {
      return products;
    }

    final singles = products.where((p) => p.isSingleItem).toList(growable: false);
    if (singles.isNotEmpty) return singles;

    Product? kit = findWardrobeKit(products, category);
    if (kit == null) {
      for (final product in products) {
        if (product.isWardrobeKit) {
          kit = product;
          break;
        }
      }
    }
    if (kit != null) {
      final items = kitListingItems(kit, products);
      if (items.isNotEmpty) return items;
    }

    return _nonKitProducts(products);

  }

  static List<Product> _nonKitProducts(List<Product> products) {
    return products.where((p) => !p.isWardrobeKit).toList(growable: false);
  }

  static String wardrobeDisplayCategory(Product kit) {
    if (kit.categoryName != null && kit.categoryName!.trim().isNotEmpty) {
      return kit.categoryName!;
    }
    return kit.productName;
  }
}
