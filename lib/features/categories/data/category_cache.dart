import 'package:nomowear/features/categories/data/models/wardrobe_category.dart';

class CategoryCache {
  CategoryCache._();

  static final CategoryCache instance = CategoryCache._();

  List<WardrobeCategory>? _categories;

  List<WardrobeCategory>? get categories => _categories;

  void set(List<WardrobeCategory> categories) {
    _categories = List.unmodifiable(categories);
  }

  void clear() {
    _categories = null;
  }
}
