/// Date helpers so mock data can be written as plain strings while the
/// features still do real date maths (lease progress, expiry, due dates).
abstract final class AppDates {
  static const _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Parses strings such as `2026-10-31` or `Oct 31, 2026`.
  static DateTime parse(String value) {
    final iso = DateTime.tryParse(value);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }
    final cleaned = value.replaceAll(',', '').trim().split(RegExp(r'\s+'));
    if (cleaned.length == 3) {
      final month = _months.indexWhere(
        (name) => name.toLowerCase() == cleaned.first.toLowerCase(),
      );
      final day = int.tryParse(cleaned[1]);
      final year = int.tryParse(cleaned[2]);
      if (month >= 0 && day != null && year != null) {
        return DateTime(year, month + 1, day);
      }
    }
    return DateTime(2026, 9, 25);
  }

  static String format(DateTime value) =>
      '${_months[value.month - 1]} ${value.day}, ${value.year}';

  static String formatShort(DateTime value) =>
      '${_months[value.month - 1]} ${value.day}';

  /// Number of whole days between two dates, ignoring the time of day.
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime(to.year, to.month, to.day)
          .difference(DateTime(from.year, from.month, from.day))
          .inDays;
}
