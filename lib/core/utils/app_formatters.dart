import 'package:intl/intl.dart';

/// Small formatting helpers shared by the resident modules.
abstract final class AppFormatters {
  static final NumberFormat _decimal = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _whole = NumberFormat('#,##0', 'en_US');

  static String currency(double value) {
    return value.abs().toStringAsFixed(0);
  }

  /// Formats an amount using the currency code returned by the backend.
  ///
  /// USD is not assumed: an unknown code is kept in front of the amount, so a
  /// currency the app has no symbol for is still unambiguous. Kyat is written
  /// as a suffix because that is how the backend's MMK amounts are displayed.
  static String money(double value, String currency) {
    final code = currency.trim().toUpperCase();
    final amount = code == 'MMK'
        ? _whole.format(value.abs())
        : _decimal.format(value.abs());
    final text = switch (code) {
      'USD' => '\$$amount',
      'EUR' => '€$amount',
      'GBP' => '£$amount',
      'MMK' => '$amount Ks',
      'SGD' => 'S\$$amount',
      'THB' => '฿$amount',
      'JPY' || 'CNY' => '¥$amount',
      _ => code.isEmpty ? amount : '$code $amount',
    };
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
