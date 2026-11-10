/// Small formatting helpers shared by the resident modules.
abstract final class AppFormatters {
  static String currency(double value) {
    return value.abs().toStringAsFixed(0);
  }

  /// Formats an amount using the currency code returned by the backend.
  ///
  /// USD is not assumed: an unknown code is kept in front of the amount, so a
  /// currency the app has no symbol for is still unambiguous.
  static String money(double value, String currency) {
    final code = currency.trim().toUpperCase();
    final symbol = switch (code) {
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      'MMK' => 'K',
      'SGD' => r'S$',
      'THB' => '฿',
      'JPY' || 'CNY' => '¥',
      _ => '',
    };
    final amount = value.abs().toStringAsFixed(2);
    final text = symbol.isEmpty
        ? (code.isEmpty ? amount : '$code $amount')
        : '$symbol$amount';
    return value < 0 ? '-$text' : text;
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
