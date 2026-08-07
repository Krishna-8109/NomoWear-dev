/// Maps profile UI measurements to/from mobile profile API format.
class ProfileMeasurementUtils {
  ProfileMeasurementUtils._();

  static const Map<String, String> _heightUiToApi = {
    '5\'7"': '5.7 ft',
    '5\'8"': '5.8 ft',
    '5\'9"': '5.9 ft',
    '5\'10"': '5.10 ft',
    '5\'11"': '5.11 ft',
    '6\'0"': '6.0 ft',
  };

  static String? heightToApi(String? uiHeight) {
    if (uiHeight == null || uiHeight.isEmpty) return null;
    return _heightUiToApi[uiHeight];
  }

  static String? heightFromApi(String? apiHeight) {
    if (apiHeight == null || apiHeight.isEmpty) return null;
    final normalized = apiHeight.trim().toLowerCase();
    for (final entry in _heightUiToApi.entries) {
      if (entry.value.toLowerCase() == normalized) return entry.key;
    }
    return null;
  }
}
