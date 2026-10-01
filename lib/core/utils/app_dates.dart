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

  static const _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
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

  /// `Wednesday, October 1`, used where a date is read out in full.
  static String formatLong(DateTime value) =>
      '${_weekdays[value.weekday - 1]}, ${_months[value.month - 1]} ${value.day}';

  static String weekday(DateTime value) => _weekdays[value.weekday - 1];

  /// Number of whole days between two dates, ignoring the time of day.
  static int daysBetween(DateTime from, DateTime to) => DateTime(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime(from.year, from.month, from.day)).inDays;

  /// Calendar days a span covers, counting the first and the last day. A lease
  /// running from the 1st to the 31st covers 31 days, not 30.
  static int inclusiveDaysBetween(DateTime from, DateTime to) =>
      daysBetween(from, to) + 1;

  /// Average length of a calendar month, used to turn a span of days into the
  /// whole months rent is billed by.
  static const averageMonthDays = 30.44;

  /// Whole months a span covers, rounded the way rent is billed. A year long
  /// term reads as 12 months rather than 11 and a bit, which is what a resident
  /// is comparing the term against.
  static int monthsBetween(DateTime from, DateTime to) {
    final days = inclusiveDaysBetween(from, to);
    if (days <= 0) {
      return 0;
    }
    return (days / averageMonthDays).round();
  }

  /// Drops the time of day, so two dates on the same day compare equal.
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Adds calendar months, keeping the day of the month where it exists and
  /// landing on the last day of a shorter month where it does not.
  static DateTime addMonths(DateTime value, int months) {
    final target = value.month + months;
    final year = value.year + (target - 1) ~/ 12;
    final month = (target - 1) % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, value.day > lastDay ? lastDay : value.day);
  }
}
