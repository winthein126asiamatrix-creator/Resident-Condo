import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract final class AppTimezone {
  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static tz.Location locationFor(String name) {
    ensureInitialized();
    final normalized = name.trim();
    if (normalized.isEmpty ||
        normalized.toLowerCase() == 'utc' ||
        normalized.toLowerCase() == 'gmt') {
      return tz.UTC;
    }
    try {
      return tz.getLocation(normalized);
    } catch (_) {
      return tz.UTC;
    }
  }

  static DateTime toLocalDateTime({
    required String date,
    required String time,
    required String timeZone,
  }) {
    final parsedDate = DateTime.tryParse(date) ?? DateTime(1970, 1, 1);
    final parts = time.trim().split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final source = tz.TZDateTime(
      locationFor(timeZone),
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      hour,
      minute,
    );
    return DateTime.fromMillisecondsSinceEpoch(
      source.millisecondsSinceEpoch,
      isUtc: true,
    ).toLocal();
  }

  static String localDate({
    required String date,
    required String time,
    required String timeZone,
  }) {
    final local = toLocalDateTime(date: date, time: time, timeZone: timeZone);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String formatLocalTime({
    required String date,
    required String time,
    required String timeZone,
  }) {
    final local = toLocalDateTime(date: date, time: time, timeZone: timeZone);
    return DateFormat('hh:mm a').format(local);
  }
}
