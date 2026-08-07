/// Normalizes Indian mobile numbers to 10 digits for UI and API calls.
class MobileNumberUtils {
  MobileNumberUtils._();

  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  /// Returns a 10-digit mobile number, or null if it cannot be normalized.
  static String? normalizeIndianMobile(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    var digits = digitsOnly(raw.trim());
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length == 10) return digits;
    return null;
  }

  static bool isValidIndianMobile(String? raw) =>
      normalizeIndianMobile(raw) != null;
}
