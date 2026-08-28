import 'package:nomowear/features/products/data/models/product.dart';

class ProductCache {
  ProductCache._();

  static final ProductCache instance = ProductCache._();

  List<Product>? _products;

  List<Product>? get products => _products;

  void set(List<Product> products) {
    _products = List.unmodifiable(products);
  }

  void upsert(Product product) {
    if (_products == null) {
      _products = List.unmodifiable([product]);
      return;
    }

    final updated = [..._products!];
    final index = updated.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      updated[index] = product;
    } else {
      updated.add(product);
    }
    _products = List.unmodifiable(updated);
  }

  Product? findById(String id) {
    final list = _products;
    if (list == null) return null;
    for (final product in list) {
      if (product.id == id) return product;
    }
    return null;
  }

  Map<String, dynamic>? lastNearbyMetadata;

  void clear() {
    _products = null;
    lastNearbyMetadata = null;
  }
}
