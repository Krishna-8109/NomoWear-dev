import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/services/auth_storage.dart';

/// Contract for State / City-Village master lists used by Profile Address.
///
/// Swap [LocalLocationRepository] → [ApiLocationRepository] once backend
/// master-data endpoints are available (paths on [ApiConstants]).
abstract class LocationRepository {
  /// Country is fixed to India in the Profile UI; kept as a param for API parity.
  Future<List<String>> getStates({String country = 'India'});

  /// Returns only cities/villages that belong to [state].
  Future<List<String>> getCitiesForState(String state);
}

/// Interim data source — keeps current product behavior until a dedicated
/// backend States/Cities API ships. UI must not embed these lists.
///
/// CHANGE: Hardcoded Profile Address options were moved out of
/// [EditProfileScreen] into this replaceable repository.
class LocalLocationRepository implements LocationRepository {
  /// Temporary master map. Replace by deleting this class usage when
  /// [ApiLocationRepository] is wired.
  static const Map<String, List<String>> _citiesByState = {
    'Telangana': ['Hyderabad'],
    'Karnataka': ['Bengaluru'],
    'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur'],
  };

  @override
  Future<List<String>> getStates({String country = 'India'}) async {
    // Simulate async so callers (Cubit) share one code path with the API impl.
    await Future<void>.delayed(Duration.zero);
    if (country.trim().toLowerCase() != 'india') return const [];
    return _citiesByState.keys.toList(growable: false);
  }

  @override
  Future<List<String>> getCitiesForState(String state) async {
    await Future<void>.delayed(Duration.zero);
    final key = state.trim();
    if (key.isEmpty || key == 'State') return const [];
    // Case-insensitive match so saved profile values still resolve.
    for (final entry in _citiesByState.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        return List<String>.unmodifiable(entry.value);
      }
    }
    return const [];
  }
}

/// Production-ready API implementation.
///
/// Enable by:
/// 1. Uncomment / set [ApiConstants.statesPath] and [ApiConstants.citiesPath]
/// 2. Construct [LocationCubit] with `ApiLocationRepository()` instead of local
///
/// Expected flexible JSON (any of):
/// - `{ "success": true, "data": ["Karnataka", ...] }`
/// - `{ "success": true, "data": [ { "name": "Karnataka" }, ... ] }`
/// - `{ "success": true, "data": { "states": [...] } }` / `{ "cities": [...] }`
class ApiLocationRepository implements LocationRepository {
  ApiLocationRepository({
    ApiClient? apiClient,
    AuthStorage? authStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _authStorage = authStorage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  Future<String?> _optionalAuthToken() async {
    final token = await _authStorage.getAuthToken();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  @override
  Future<List<String>> getStates({String country = 'India'}) async {
    final path = ApiConstants.statesPath;
    if (path == null || path.isEmpty) {
      throw const ApiException(
        'States API is not configured yet. Set ApiConstants.statesPath.',
      );
    }

    final token = await _optionalAuthToken();
    // ApiClient.get currently requires authToken; pass empty when public.
    final json = await _apiClient.get(
      path,
      authToken: token ?? '',
      queryParameters: {'country': country},
    );

    if (json['success'] == false) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load states',
      );
    }

    return _extractNames(json['data'], listKeys: const ['states', 'state']);
  }

  @override
  Future<List<String>> getCitiesForState(String state) async {
    final path = ApiConstants.citiesPath;
    if (path == null || path.isEmpty) {
      throw const ApiException(
        'Cities API is not configured yet. Set ApiConstants.citiesPath.',
      );
    }

    final trimmed = state.trim();
    if (trimmed.isEmpty || trimmed == 'State') return const [];

    final token = await _optionalAuthToken();
    final json = await _apiClient.get(
      path,
      authToken: token ?? '',
      queryParameters: {'state': trimmed},
    );

    if (json['success'] == false) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to load cities',
      );
    }

    return _extractNames(
      json['data'],
      listKeys: const ['cities', 'city', 'villages', 'village'],
    );
  }

  /// Normalizes several common backend list shapes into display names.
  List<String> _extractNames(
    dynamic data, {
    required List<String> listKeys,
  }) {
    if (data == null) return const [];

    if (data is List) {
      return _namesFromList(data);
    }

    if (data is Map) {
      for (final key in listKeys) {
        final nested = data[key];
        if (nested is List) return _namesFromList(nested);
      }
      // Single object with a name field.
      final name = _nameFromMap(Map<String, dynamic>.from(data));
      if (name != null) return [name];
    }

    return const [];
  }

  List<String> _namesFromList(List<dynamic> items) {
    final names = <String>[];
    for (final item in items) {
      if (item is String) {
        final t = item.trim();
        if (t.isNotEmpty) names.add(t);
      } else if (item is Map) {
        final name = _nameFromMap(Map<String, dynamic>.from(item));
        if (name != null) names.add(name);
      }
    }
    return List<String>.unmodifiable(names);
  }

  String? _nameFromMap(Map<String, dynamic> map) {
    for (final key in [
      'name',
      'state',
      'state_name',
      'stateName',
      'city',
      'city_name',
      'cityName',
      'village',
      'label',
      'title',
    ]) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
