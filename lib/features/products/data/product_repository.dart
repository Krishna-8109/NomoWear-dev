import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/products/data/models/product.dart';
import 'package:nomowear/features/products/data/product_cache.dart';

class ProductRepository {
  static Future<List<Product>>? _inFlightProductsRequest;

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  ProductRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  /// [action] is `kids` or `adults` (same as filter options API).
  /// [age] / [gender] match filter API field names (`data.age`, `data.gender`).
  /// Filtered / action-scoped requests bypass the shared product cache.
  Future<List<Product>> getProducts({
    bool forceRefresh = false,
    String? action,
    String? age,
    String? gender,
  }) async {
    final actionParam = action?.trim().toLowerCase();
    final ageParam = age?.trim();
    final genderParam = gender?.trim();
    final hasAction =
        actionParam != null &&
        actionParam.isNotEmpty &&
        actionParam != 'all';
    final hasFilters = (ageParam != null && ageParam.isNotEmpty) ||
        (genderParam != null && genderParam.isNotEmpty) ||
        hasAction;

    if (!hasFilters && !forceRefresh) {
      final cached = ProductCache.instance.products;
      if (cached != null) return cached;
    }

    // Deduplicate only unfiltered catalogue fetches.
    if (!hasFilters && _inFlightProductsRequest != null) {
      return _inFlightProductsRequest!;
    }

    final request = () async {
      final authToken = await _authStorage.getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        throw const ApiException('Not logged in. Please login again.');
      }

      final query = <String, String>{};
      if (actionParam != null && actionParam.isNotEmpty) {
        query['action'] = actionParam;
      }
      if (ageParam != null && ageParam.isNotEmpty) {
        query['age'] = ageParam;
      }
      if (genderParam != null && genderParam.isNotEmpty) {
        query['gender'] = genderParam;
      }

      final json = await _apiClient.get(
        ApiConstants.productsPath,
        authToken: authToken,
        queryParameters: query.isEmpty ? null : query,
      );

      if (json['success'] != true) {
        throw ApiException(
          json['message']?.toString() ?? 'Failed to load products',
        );
      }

      final data = json['data'];
      if (data is! List) {
        throw const ApiException('Invalid products response');
      }

      final products = data
          .whereType<Map>()
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id.isNotEmpty && p.productName.isNotEmpty)
          .toList();

      if (!hasFilters) {
        ProductCache.instance.set(products);
      }
      return products;
    }();

    if (!hasFilters) {
      _inFlightProductsRequest = request;
    }
    try {
      return await request;
    } finally {
      if (!hasFilters) {
        _inFlightProductsRequest = null;
      }
    }
  }

  Future<Product> getProductById(String id) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.get(
      '${ApiConstants.productsPath}/$id',
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load product',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid product response');
    }

    final product = Product.fromJson(data);
    if (product.id.isEmpty) {
      throw const ApiException('Invalid product response');
    }

    ProductCache.instance.upsert(product);
    return product;
  }
}
