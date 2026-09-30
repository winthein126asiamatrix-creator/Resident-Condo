import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/app_dates.dart';
import '../../domain/entities/facility.dart';
import '../../domain/usecases/facility_usecases.dart';

class FacilityController extends GetxController {
  FacilityController(this.useCases);

  /// Today plus the next five days.
  static const reservationWindowDays = 4;

  final FacilityUseCases useCases;
  final facilities = <Facility>[].obs;
  final reservations = <FacilityReservation>[].obs;
  final selectedFacility = Rxn<Facility>();
  final selectedDate = AppDates.format(_today).obs;
  final selectedSlot = RxnString();

  /// Set when the resident picks their own time instead of one of the
  /// predefined slots, and cleared as soon as they pick a predefined one.
  final customTime = Rxn<TimeOfDay>();
  final isLoading = false.obs;
  final isBooking = false.obs;
  final errorMessage = RxnString();
  final bookingSuccess = Rxn<FacilityReservation>();

  /// The bookable window, generated from the current date so the chips always
  /// start at today.
  List<String> get reservationDates => List.generate(
    reservationWindowDays,
    (index) => AppDates.format(
      DateTime(_today.year, _today.month, _today.day + index),
    ),
  );

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

  void selectFacility(Facility facility) {
    selectedFacility.value = facility;
    selectedSlot.value = null;
    bookingSuccess.value = null;
  }

  void selectDate(String date) {
    selectedDate.value = date;
  }

  void selectSlot(String slot) {
    customTime.value = null;
    selectedSlot.value = slot;
  }

  /// Stores a time the resident typed into the picker. The slot mirrors the
  /// chip label so the booking reads back the same way the selection did.
  void selectCustomTime(TimeOfDay time) {
    customTime.value = time;
    selectedSlot.value = customSlotLabel(time);
  }

  bool get isCustomTimeSelected {
    final time = customTime.value;
    return time != null && selectedSlot.value == customSlotLabel(time);
  }

  static String customSlotLabel(TimeOfDay time) =>
      'Custom · ${formatTime(time)}';

  /// Mirrors `TimeOfDay.format` for the default locale, kept here so the label
  /// can be produced without a build context.
  static String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<Facility?> getFacility(String id) {
    return useCases.getFacility(id);
  }

  Future<FacilityReservation?> bookSelectedSlot() async {
    final facility = selectedFacility.value;
    final slot = selectedSlot.value;
    if (facility == null) {
      errorMessage.value = 'Choose a facility first.';
      return null;
    }
    // A custom time is not one of the facility's predefined slots, so it only
    // has to match the time the resident just chose.
    final usesCustomTime = isCustomTimeSelected;
    if (slot == null ||
        (!usesCustomTime && !facility.availableSlots.contains(slot))) {
      errorMessage.value = 'Choose an available time slot.';
      return null;
    }

    isBooking.value = true;
    errorMessage.value = null;
    try {
      final reservation = await useCases.createReservation(
        FacilityReservation(
          id: 'local-reservation',
          facilityId: facility.id,
          facilityName: facility.name,
          date: selectedDate.value,
          time: slot,
          status: 'Confirmed',
          createdAt: 'Sep 25, 2026',
          isCustomTime: usesCustomTime,
        ),
      );
      reservations.insert(0, reservation);
      // Only a predefined slot is consumed from the list; a custom time does
      // not take one of the facility's slots away.
      final updatedFacility = usesCustomTime
          ? facility
          : facility.copyWith(
              availableSlots: facility.availableSlots
                  .where((item) => item != slot)
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
}
