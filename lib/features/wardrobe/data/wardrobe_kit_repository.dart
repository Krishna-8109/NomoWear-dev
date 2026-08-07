import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/wardrobe/data/models/wardrobe_kit.dart';

class WardrobeKitRepository {
  WardrobeKitRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  Future<List<WardrobeKit>> getWardrobeKits() async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.get(
      ApiConstants.wardrobeKitsPath,
      authToken: authToken,
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load wardrobe kits',
      );
    }

    final data = json['data'];
    if (data is! List) {
      throw const ApiException('Invalid wardrobe kits response');
    }

    return data
        .whereType<Map>()
        .map((item) => WardrobeKit.fromJson(Map<String, dynamic>.from(item)))
        .where((kit) => kit.id.isNotEmpty && kit.isActive)
        .toList()
      ..sort((a, b) => a.durationDays.compareTo(b.durationDays));
  }
}
