/// Small formatting helpers shared by the resident modules.
abstract final class AppFormatters {
  static String currency(double value) {
    final sign = value < 0 ? '-' : '';
    return '$sign\$${value.abs().toStringAsFixed(2)}';
  }

  static String currencyCompact(double value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      final text = thousands == thousands.roundToDouble()
          ? thousands.toStringAsFixed(0)
          : thousands.toStringAsFixed(1);
      return '\$${text}k';
    }
    return currency(value);
  }

  static String percent(double ratio) => '${(ratio * 100).round()}%';
}
