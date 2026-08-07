import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:nomowear/features/products/data/models/product.dart';
import 'package:nomowear/features/products/data/product_cache.dart';
import 'package:nomowear/features/products/data/product_mapper.dart';

class WishlistRepository {
  WishlistRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  Future<String> _authToken() async {
    final token = await _authStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }
    return token;
  }

  Future<List<FavoriteItem>> getWishlist() async {
    final authToken = await _authToken();

    final json = await _apiClient.get(
      ApiConstants.wishlistPath,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load wishlist',
      );
    }

    return _parseWishlist(json['data']);
  }

  Future<String?> addToWishlist(String productId) async {
    final authToken = await _authToken();

    final json = await _apiClient.post(
      ApiConstants.wishlistPath,
      {'product_id': productId},
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to add to wishlist',
      );
    }

    return _parseWishlistItemId(json['data']);
  }

  Future<void> removeFavorite(FavoriteItem item) async {
    var wishlistItemId = item.wishlistItemId;
    if (wishlistItemId == null || wishlistItemId.isEmpty) {
      final items = await getWishlist();
      for (final entry in items) {
        if (entry.id == item.id) {
          wishlistItemId = entry.wishlistItemId;
          break;
        }
      }
    }

    if (wishlistItemId == null || wishlistItemId.isEmpty) {
      throw const ApiException('Unable to remove wishlist item');
    }

    await _deleteWishlistItem(wishlistItemId);
  }

  Future<void> _deleteWishlistItem(String wishlistItemId) async {
    final authToken = await _authToken();

    final json = await _apiClient.delete(
      '${ApiConstants.wishlistPath}/$wishlistItemId',
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to remove from wishlist',
      );
    }
  }

  List<FavoriteItem> _parseWishlist(dynamic data) {
    if (data is! List) return const [];

    final items = <FavoriteItem>[];
    for (final entry in data) {
      if (entry is! Map<String, dynamic>) continue;
      final item = _mapWishlistEntry(entry);
      if (item != null) items.add(item);
    }
    return items;
  }

  FavoriteItem? _mapWishlistEntry(Map<String, dynamic> json) {
    final wishlistItemId = _parseWishlistItemId(json);

    if (json.containsKey('product_name') || json.containsKey('productName')) {
      return _favoriteFromProduct(
        Product.fromJson(json),
        wishlistItemId: wishlistItemId,
      );
    }

    final productRaw = json['product'];
    final productId = _nonEmpty(
          json['product_id'] ?? json['productId'],
        ) ??
        (productRaw is Map<String, dynamic>
            ? _nonEmpty(productRaw['id'])
            : null);

    if (productId == null) return null;

    if (productRaw is Map<String, dynamic>) {
      return _favoriteFromProduct(
        Product.fromJson(productRaw),
        wishlistItemId: wishlistItemId,
        productId: productId,
      );
    }

    Product? cached;
    for (final product in ProductCache.instance.products ?? const <Product>[]) {
      if (product.id == productId) {
        cached = product;
        break;
      }
    }
    if (cached != null) {
      return _favoriteFromProduct(
        cached,
        wishlistItemId: wishlistItemId,
        productId: productId,
      );
    }

    return FavoriteItem(
      id: productId,
      wishlistItemId: wishlistItemId,
      title: 'Product',
      subtitle: '',
      imageUrl: '',
    );
  }

  FavoriteItem _favoriteFromProduct(
    Product product, {
    String? wishlistItemId,
    String? productId,
  }) {
    final imageUrl = product.primaryImageUrl ??
        (product.imageUrls.isNotEmpty ? product.imageUrls.first : '');
    return FavoriteItem(
      id: productId ?? product.id,
      wishlistItemId: wishlistItemId,
      title: product.productName,
      subtitle: ProductMapper.formatPrice(product.actualPrice),
      imageUrl: imageUrl,
    );
  }

  String? _parseWishlistItemId(dynamic data) {
    if (data is Map<String, dynamic>) {
      return _nonEmpty(data['id'] ?? data['wishlist_id'] ?? data['wishlistId']);
    }
    return null;
  }

  String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
