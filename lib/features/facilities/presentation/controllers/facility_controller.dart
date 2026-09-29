import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/facility.dart';
import '../../domain/usecases/facility_usecases.dart';

class FacilityController extends GetxController {
  FacilityController(this.useCases);

  final FacilityUseCases useCases;
  final facilities = <Facility>[].obs;
  final reservations = <FacilityReservation>[].obs;
  final selectedFacility = Rxn<Facility>();
  final selectedDate = 'Sep 26, 2026'.obs;
  final selectedSlot = RxnString();
  final isLoading = false.obs;
  final isBooking = false.obs;
  final errorMessage = RxnString();
  final bookingSuccess = Rxn<FacilityReservation>();

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
    selectedSlot.value = slot;
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
    if (slot == null || !facility.availableSlots.contains(slot)) {
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
        ),
      );
      reservations.insert(0, reservation);
      final updatedFacility = facility.copyWith(
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
