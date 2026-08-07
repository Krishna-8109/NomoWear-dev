class ProfileDateUtils {
  static String? toApiDate(String displayDob) {
    final trimmed = displayDob.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split('/');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;

    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static String toDisplayDate(String? apiDob) {
    if (apiDob == null || apiDob.isEmpty) return '';

    final datePart = apiDob.contains('T') ? apiDob.split('T').first : apiDob;
    final parts = datePart.split('-');
    if (parts.length != 3) return apiDob;

    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}
