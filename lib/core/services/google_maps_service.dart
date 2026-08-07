import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nomowear/core/config/google_maps_config.dart';

class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
}

class ResolvedAddress {
  const ResolvedAddress({
    required this.areaTitle,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
  });

  final String areaTitle;
  final String fullAddress;
  final double latitude;
  final double longitude;
}

class GoogleMapsService {
  GoogleMapsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PlacePrediction>> searchPlaces(String input) async {
    final query = input.trim();
    if (query.length < 2) return [];

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'key': GoogleMapsConfig.apiKey,
        'components': 'country:in',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 'OK' && json['status'] != 'ZERO_RESULTS') {
      return [];
    }

    final predictions = json['predictions'];
    if (predictions is! List) return [];

    return predictions
        .whereType<Map>()
        .map((item) {
          final structured = item['structured_formatting'];
          final mainText = structured is Map
              ? structured['main_text']?.toString() ?? ''
              : '';
          final secondaryText = structured is Map
              ? structured['secondary_text']?.toString() ?? ''
              : '';
          return PlacePrediction(
            placeId: item['place_id']?.toString() ?? '',
            description: item['description']?.toString() ?? '',
            mainText: mainText,
            secondaryText: secondaryText,
          );
        })
        .where((p) => p.placeId.isNotEmpty)
        .toList();
  }

  Future<ResolvedAddress?> resolvePlace(String placeId) async {
    if (placeId.isEmpty) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry,formatted_address,name',
        'key': GoogleMapsConfig.apiKey,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return null;

    final result = json['result'];
    if (result is! Map) return null;

    final geometry = result['geometry'];
    final location = geometry is Map ? geometry['location'] : null;
    if (location is! Map) return null;

    final lat = _parseDouble(location['lat']);
    final lng = _parseDouble(location['lng']);
    if (lat == null || lng == null) return null;

    final formatted = result['formatted_address']?.toString() ?? '';
    final name = result['name']?.toString() ?? '';

    return ResolvedAddress(
      areaTitle: name.isNotEmpty ? name : _areaFromAddress(formatted),
      fullAddress: formatted.isNotEmpty ? formatted : name,
      latitude: lat,
      longitude: lng,
    );
  }

  Future<ResolvedAddress?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '$latitude,$longitude',
        'key': GoogleMapsConfig.apiKey,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return null;

    final results = json['results'];
    if (results is! List || results.isEmpty) return null;

    final first = results.first;
    if (first is! Map) return null;

    final formatted = first['formatted_address']?.toString() ?? '';
    if (formatted.isEmpty) return null;

    return ResolvedAddress(
      areaTitle: _areaFromComponents(first) ?? _areaFromAddress(formatted),
      fullAddress: formatted,
      latitude: latitude,
      longitude: longitude,
    );
  }

  String? _areaFromComponents(Map<dynamic, dynamic> result) {
    final components = result['address_components'];
    if (components is! List) return null;

    for (final type in ['sublocality', 'sublocality_level_1', 'neighborhood']) {
      for (final item in components) {
        if (item is! Map) continue;
        final types = item['types'];
        if (types is List && types.contains(type)) {
          final name = item['long_name']?.toString().trim();
          if (name != null && name.isNotEmpty) return name;
        }
      }
    }
    return null;
  }

  String _areaFromAddress(String formatted) {
    final parts = formatted
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 3) return parts[parts.length - 3];
    if (parts.length >= 2) return parts[1];
    if (parts.isNotEmpty) return parts.first;
    return 'Selected location';
  }

  double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
