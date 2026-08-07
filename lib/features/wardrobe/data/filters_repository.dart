import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';
import 'package:nomowear/features/wardrobe/data/models/filter_options.dart';

class FiltersRepository {
  FiltersRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  static final Map<String, FilterOptions> _cache = {};
  static final Map<String, Future<FilterOptions>> _inFlight = {};

  /// [action] is `adults` or `kids`.
  Future<FilterOptions> getFilters({
    required String action,
    bool forceRefresh = false,
  }) async {
    final key = action.trim().toLowerCase();
    if (key.isEmpty) {
      throw const ApiException('Invalid filter action');
    }

    if (!forceRefresh) {
      final cached = _cache[key];
      if (cached != null) return cached;
      final pending = _inFlight[key];
      if (pending != null) return pending;
    }

    final request = _fetch(key);
    _inFlight[key] = request;
    try {
      final options = await request;
      _cache[key] = options;
      return options;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<FilterOptions> _fetch(String action) async {
    final authToken = await _authStorage.getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Not logged in. Please login again.');
    }

    final json = await _apiClient.get(
      ApiConstants.filtersPath,
      authToken: authToken,
      queryParameters: {'action': action},
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load filters',
      );
    }

    final data = json['data'];
    if (data is! Map) {
      throw const ApiException('Invalid filters response');
    }

    return FilterOptions.fromJson(Map<String, dynamic>.from(data));
  }
}
