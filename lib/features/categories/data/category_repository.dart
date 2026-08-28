import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/categories/data/category_cache.dart';
import 'package:nomowear/features/categories/data/models/wardrobe_category.dart';

class CategoryRepository {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  CategoryRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  Future<List<WardrobeCategory>> getCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = CategoryCache.instance.categories;
      if (cached != null) return cached;
    }

    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.get(
      ApiConstants.categoriesPath,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load categories',
      );
    }

    final categories = _parseCategories(json['data'])
        .where((category) => category.name.isNotEmpty && category.isActive)
        .toList(growable: false);

    CategoryCache.instance.set(categories);
    return categories;
  }

  static List<WardrobeCategory> _parseCategories(dynamic data) {
    Iterable raw = const [];
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      final nested = data['items'] ??
          data['categories'] ??
          data['results'] ??
          data['data'];
      if (nested is List) raw = nested;
    }

    return raw
        .whereType<Map>()
        .map((item) => WardrobeCategory.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
