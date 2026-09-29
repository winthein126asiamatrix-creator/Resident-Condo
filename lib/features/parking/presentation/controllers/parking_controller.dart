import 'package:get/get.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/parking.dart';
import '../../domain/usecases/parking_usecases.dart';

class ParkingController extends GetxController {
  ParkingController(this.useCases);

  final ParkingUseCases useCases;
  final spaces = <ParkingSpace>[].obs;
  final events = <ParkingEvent>[].obs;
  final guestRequests = <GuestParkingRequest>[].obs;
  final mySpace = Rxn<ParkingSpace>();
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadParking();
  }

  int get availableCount => spaces
      .where((space) => space.status == ParkingStatus.vacant)
      .length;

  int get activeGuestRequests => guestRequests
      .where((request) => request.status != 'Cancelled')
      .length;


  Future<void> loadParking() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      mySpace.value = await useCases.getMySpace();
      spaces.assignAll(await useCases.getSpaces());
      events.assignAll(await useCases.getEvents());
      guestRequests.assignAll(await useCases.getGuestRequests());
    } on AppException catch (error) {
      errorMessage.value = error.message;
    } catch (_) {
      errorMessage.value = 'Unable to load parking information.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<ParkingSpace?> updateVehicle(String vehicle, String plate) async {
    final space = mySpace.value;
    if (space == null) {
      errorMessage.value = 'No parking space is assigned to your unit.';
      return null;
    }
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await useCases.updateVehicle(space, vehicle, plate);
      mySpace.value = updated;
      final index = spaces.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        spaces[index] = updated;
      }
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to update the vehicle.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<GuestParkingRequest?> requestGuestParking({
    required String guestName,
    required String vehicle,
    required String plate,
    required String date,
    required String window,
    String note = '',
  }) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final created = await useCases.requestGuestParking(
        GuestParkingRequest(
          id: 'local-guest-parking',
          guestName: guestName,
          vehicle: vehicle,
          licensePlate: plate,
          date: date,
          window: window,
          status: 'Pending review',
          requestedOn: 'Sep 25, 2026',
          note: note,
        ),
      );
      guestRequests.insert(0, created);
      return created;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to request guest parking.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<GuestParkingRequest?> cancelGuestParking(
    GuestParkingRequest request,
  ) async {
    isSubmitting.value = true;
    errorMessage.value = null;
    try {
      final updated = await useCases.cancelGuestParking(request);
      final index = guestRequests.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        guestRequests[index] = updated;
      }
      return updated;
    } on AppException catch (error) {
      errorMessage.value = error.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Unable to cancel the request.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }
}
