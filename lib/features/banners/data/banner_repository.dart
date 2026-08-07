import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/banners/data/banner_cache.dart';
import 'package:nomowear/features/banners/data/models/promo_banner.dart';

class BannerRepository {
  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  BannerRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  Future<List<PromoBanner>> getBanners({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = BannerCache.instance.banners;
      if (cached != null) return cached;
    }

    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.get(
      ApiConstants.bannersPath,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load banners',
      );
    }

    final data = json['data'];
    if (data is! List) {
      throw const ApiException('Invalid banners response');
    }

    final banners = data
        .whereType<Map<String, dynamic>>()
        .map(PromoBanner.fromJson)
        .where(
          (b) =>
              b.id.isNotEmpty &&
              b.title.isNotEmpty &&
              b.imageUrl.isNotEmpty &&
              b.isActive,
        )
        .toList();

    BannerCache.instance.set(banners);
    return banners;
  }
}
