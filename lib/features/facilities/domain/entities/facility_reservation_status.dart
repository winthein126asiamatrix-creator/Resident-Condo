import '../../../../core/utils/app_dates.dart';
import 'facility.dart';

/// Statuses the reservation flow understands.
///
/// The repository stores the status as a plain string so a backend can add its
/// own values without a schema change; this is the app's reading of them, and
/// [fromLabel] keeps an unrecognised value from breaking the UI.
enum FacilityReservationStatus {
  confirmed,
  pending,
  cancelled,
  completed,
  upcoming,
  other;

  static FacilityReservationStatus fromLabel(String value) {
    return switch (value.trim().toLowerCase()) {
      'confirmed' => FacilityReservationStatus.confirmed,
      'pending' => FacilityReservationStatus.pending,
      'cancelled' || 'canceled' => FacilityReservationStatus.cancelled,
      'completed' => FacilityReservationStatus.completed,
      'upcoming' => FacilityReservationStatus.upcoming,
      _ => FacilityReservationStatus.other,
    };
  }

  /// Whether the slot has already been used, which is what puts a reservation
  /// in the past group.
  bool get isPast =>
      this == FacilityReservationStatus.completed ||
      this == FacilityReservationStatus.cancelled;
}

/// The moment a reservation starts, used to sort and group the list.
///
/// Times are stored as labels such as `6:00 PM` or `Custom · 7:45 AM`. Anything
/// unrecognised falls back to the start of the day, so an unknown format never
/// hides a reservation.
DateTime reservationStart(FacilityReservation reservation) {
  final date = AppDates.parse(reservation.date);
  final (hour, minute) = _parseTime(reservation.time);
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// True once the reservation's start time has gone by. A cancelled reservation
/// is always past, whatever its date says.
bool isReservationPast(FacilityReservation reservation) {
  if (FacilityReservationStatus.fromLabel(reservation.status).isPast) {
    return true;
  }
  return reservationStart(reservation).isBefore(DateTime.now());
}

(int, int) _parseTime(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])').firstMatch(value);
  if (match == null) {
    return (0, 0);
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
  return (hour, minute);
}
