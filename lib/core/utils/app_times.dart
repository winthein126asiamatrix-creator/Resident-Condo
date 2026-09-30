import 'package:flutter/material.dart';

/// Time arithmetic and formatting shared by the reservation and visitor flows.
///
/// Times are stored and shown as plain labels such as `2:00 PM`, which is what
/// the existing records already hold, so this works on strings and avoids
/// changing any stored format.
abstract final class AppTimes {
  /// `2:00 PM`, matching the default locale.
  static String format(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Reads a time out of a label such as `6:00 PM`. Takes the first match, so
  /// it also copes with `2:00 PM – 4:00 PM` and `Custom · 2:00 PM`.
  static TimeOfDay? parse(String value) {
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])').firstMatch(value);
    if (match == null) {
      return null;
    }
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final isPm = match.group(3)!.toLowerCase() == 'pm';
    if (isPm && hour != 12) {
      hour += 12;
    }
    if (!isPm && hour == 12) {
      hour = 0;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// `start + hours`, rolling over midnight when the result is earlier than the
  /// start.
  static TimeOfDay addHours(TimeOfDay start, int hours) {
    final total = (start.hour * 60 + start.minute) + hours * 60;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  /// True when [end] has wrapped past midnight relative to [start].
  static bool rollsOver(TimeOfDay start, TimeOfDay end) {
    return end.hour * 60 + end.minute < start.hour * 60 + start.minute;
  }
}

/// A start and end time with the label shown to a resident.
class AppTimeRange {
  const AppTimeRange({required this.start, required this.end});

  final TimeOfDay start;
  final TimeOfDay end;

  bool get nextDay => AppTimes.rollsOver(start, end);

  /// `2:00 PM – 4:00 PM`, marked when the visit runs past midnight.
  String get label => nextDay
      ? '${AppTimes.format(start)} – ${AppTimes.format(end)} (next day)'
      : '${AppTimes.format(start)} – ${AppTimes.format(end)}';

  /// Builds the range from a start label and a duration in hours.
  static AppTimeRange? fromLabel(String startLabel, int hours) {
    final start = AppTimes.parse(startLabel);
    if (start == null) {
      return null;
    }
    return AppTimeRange(start: start, end: AppTimes.addHours(start, hours));
  }
}
