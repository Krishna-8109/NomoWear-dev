class PlanPriceFormatter {
  PlanPriceFormatter._();

  static String format(num amount) {
    final value = amount.round();
    final negative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    if (negative) buffer.write('-');

    if (digits.length <= 3) {
      buffer.write(digits);
      return buffer.toString();
    }

    final lastThree = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    buffer.write('${parts.join(',')},$lastThree');
    return buffer.toString();
  }
}
