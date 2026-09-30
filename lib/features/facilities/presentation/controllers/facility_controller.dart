import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/app_dates.dart';
import '../../../../core/utils/app_times.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/facility_reservation_status.dart';
import '../../domain/usecases/facility_usecases.dart';

class FacilityController extends GetxController {
  FacilityController(this.useCases);

  /// Today plus the next five days.
  static const reservationWindowDays = 6;

  /// How long a reservation may run for, in hours.
  static const reservationDurations = <int>[1, 2, 3];

  final FacilityUseCases useCases;
  final facilities = <Facility>[].obs;
  final reservations = <FacilityReservation>[].obs;
  final selectedFacility = Rxn<Facility>();
  final selectedDate = AppDates.format(_today).obs;
  final selectedSlot = RxnString();

  /// Set when the resident picks their own time instead of one of the
  /// predefined slots, and cleared as soon as they pick a predefined one.
  final customTime = Rxn<TimeOfDay>();

  /// How long the reservation runs for. Always one of [reservationDurations],
  /// so the resident never has to pick an end time themselves.
  final selectedDurationHours = 1.obs;
  final isLoading = false.obs;

  /// Tracked separately from [isLoading] so the facilities grid is not blanked
  /// out while My Reservations refreshes.
  final isReservationsLoading = false.obs;
  final isBooking = false.obs;
  final errorMessage = RxnString();
  final reservationsError = RxnString();
  final bookingSuccess = Rxn<FacilityReservation>();

  /// The bookable window, generated from the current date so the chips always
  /// start at today.
  List<String> get reservationDates => List.generate(
    reservationWindowDays,
    (index) => AppDates.format(
      DateTime(_today.year, _today.month, _today.day + index),
    ),
  );

  /// The selected date read out in full, for the dialog and the success page.
  String get selectedDateLong =>
      AppDates.formatLong(AppDates.parse(selectedDate.value));

  /// The start time as a label, whether it came from a slot or the picker.
  String? get selectedStartTimeLabel {
    final time = customTime.value;
    if (time != null) {
      return AppTimes.format(time);
    }
    return selectedSlot.value;
  }

  /// Start plus the chosen duration. Null until a start time is picked.
  AppTimeRange? get reservationRange {
    final start = selectedStartTimeLabel;
    if (start == null) {
      return null;
    }
    return AppTimeRange.fromLabel(start, selectedDurationHours.value);
  }

  /// Why the current start time and duration cannot be booked, or null when they
  /// are fine. Checked against the facility's own opening hours so the app does
  /// not invent availability.
  String? get durationError {
    final facility = selectedFacility.value;
    final range = reservationRange;
    if (facility == null || range == null) {
      return null;
    }
    final closing = AppTimes.parse(_closingTime(facility.openingHours));
    if (closing == null) {
      return null;
    }
    if (!range.nextDay && _isAfter(range.end, closing)) {
      return 'A ${selectedDurationHours.value} hour booking would run past '
          '${facility.openingHours.split('–').last.trim()}. Pick an earlier '
          'time or a shorter duration.';
    }
    if (range.nextDay) {
      return 'A ${selectedDurationHours.value} hour booking would run past '
          'midnight. Pick an earlier time or a shorter duration.';
    }
    return null;
  }

  /// Nothing is submitted until the resident has picked a date, a start time and
  /// a duration that fits inside the facility's opening hours.
  bool get canConfirmBooking =>
      selectedFacility.value != null &&
      selectedDate.value.isNotEmpty &&
      reservationRange != null &&
      durationError == null;

  /// Reservations whose start time is still ahead of us, soonest first.
  List<FacilityReservation> get upcomingReservations {
    final upcoming = reservations
        .where((reservation) => !isReservationPast(reservation))
        .toList();
    upcoming.sort((a, b) => reservationStart(a).compareTo(reservationStart(b)));
    return upcoming;
  }

  /// Reservations that have already happened, most recent first.
  List<FacilityReservation> get pastReservations {
    final past = reservations
        .where((reservation) => isReservationPast(reservation))
        .toList();
    past.sort((a, b) => reservationStart(b).compareTo(reservationStart(a)));
    return past;
  }

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void onInit() {
    super.onInit();
    loadFacilities();
  }

  Future<void> loadFacilities() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loadedFacilities = await useCases.getFacilities();
      final loadedReservations = await useCases.getReservations();
      facilities.assignAll(loadedFacilities);
      reservations.assignAll(loadedReservations);
      final selected = selectedFacility.value;
      if (selected != null) {
        selectedFacility.value = _findFacility(selected.id) ?? selected;
      }
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load facility information.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Reloads just the reservations, used by My Reservations. The facility list
  /// is left alone so opening the page never blanks the amenities grid.
  Future<void> loadReservations() async {
    isReservationsLoading.value = true;
    reservationsError.value = null;
    try {
      reservations.assignAll(await useCases.getReservations());
    } on AppException catch (error) {
      reservationsError.value = error.message;
    } catch (_) {
      reservationsError.value = 'Unable to load your reservations.';
    } finally {
      isReservationsLoading.value = false;
    }
  }

  void selectFacility(Facility facility) {
    selectedFacility.value = facility;
    selectedSlot.value = null;
    customTime.value = null;
    bookingSuccess.value = null;
    errorMessage.value = null;
  }

  void selectDate(String date) {
    selectedDate.value = date;
  }

  void selectSlot(String slot) {
    customTime.value = null;
    selectedSlot.value = slot;
  }

  /// Stores a time the resident typed into the picker. The end time is derived
  /// from this and the duration rather than being picked separately.
  void selectCustomTime(TimeOfDay time) {
    customTime.value = time;
    selectedSlot.value = AppTimes.format(time);
  }

  /// The selected duration always has to be one the app offers.
  void selectDuration(int hours) {
    if (!reservationDurations.contains(hours)) {
      return;
    }
    selectedDurationHours.value = hours;
  }

  static String customSlotLabel(TimeOfDay time) => AppTimes.format(time);

  bool get isCustomTimeSelected => customTime.value != null;

  /// Mirrors `TimeOfDay.format` for the default locale, kept here so the label
  /// can be produced without a build context.
  static String formatTime(TimeOfDay time) => AppTimes.format(time);

  Future<Facility?> getFacility(String id) {
    return useCases.getFacility(id);
  }

  /// Used by the reservation list to show the facility's photo and name.
  Facility? facilityById(String id) => _findFacility(id);

  bool isBookingNow() => isBooking.value;

  /// Guards the submit so a second tap while the request is in flight is a
  /// no-op rather than a duplicate booking.
  Future<FacilityReservation?> bookSelectedSlot() async {
    if (isBooking.value) {
      return null;
    }
    final facility = selectedFacility.value;
    if (facility == null) {
      errorMessage.value = 'Choose a facility first.';
      return null;
    }
    // A custom time is not one of the facility's predefined slots, so it only
    // has to match the time the resident just chose.
    final usesCustomTime = isCustomTimeSelected;
    final start = selectedStartTimeLabel;
    final range = reservationRange;
    if (start == null || range == null) {
      errorMessage.value = 'Choose a start time.';
      return null;
    }
    final durationProblem = durationError;
    if (durationProblem != null) {
      errorMessage.value = durationProblem;
      return null;
    }
    if (!usesCustomTime && !facility.availableSlots.contains(start)) {
      errorMessage.value = 'Choose an available time slot.';
      return null;
    }

    isBooking.value = true;
    errorMessage.value = null;
    try {
      final reservation = await useCases.createReservation(
        FacilityReservation(
          // The reference is assigned by the data source, standing in for the
          // backend that will own it.
          id: '',
          facilityId: facility.id,
          facilityName: facility.name,
          date: selectedDate.value,
          // Stored as the full interval, which is what the resident booked.
          time: range.label,
          status: 'Confirmed',
          createdAt: AppDates.format(_today),
          isCustomTime: usesCustomTime,
          startTime: start,
          durationHours: selectedDurationHours.value,
        ),
      );
      reservations.insert(0, reservation);
      // Only a predefined slot is consumed from the list; a custom time does
      // not take one of the facility's slots away.
      final updatedFacility = usesCustomTime
          ? facility
          : facility.copyWith(
              availableSlots: facility.availableSlots
                  .where((item) => item != start)
                  .toList(),
            );
      final index = facilities.indexWhere((item) => item.id == facility.id);
      if (index != -1) {
        facilities[index] = updatedFacility;
        selectedFacility.value = updatedFacility;
      }
      bookingSuccess.value = reservation;
      return reservation;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to complete the reservation.';
      return null;
    } finally {
      isBooking.value = false;
    }
  }

  Facility? _findFacility(String id) {
    for (final facility in facilities) {
      if (facility.id == id) {
        return facility;
      }
    }
    return null;
  }

  /// The closing time from a label such as `6:00 AM – 10:00 PM`.
  String _closingTime(String openingHours) {
    final parts = openingHours.split('–');
    return parts.length > 1 ? parts.last.trim() : openingHours.trim();
  }

  static bool _isAfter(TimeOfDay value, TimeOfDay other) =>
      value.hour * 60 + value.minute > other.hour * 60 + other.minute;
}
