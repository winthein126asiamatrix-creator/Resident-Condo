import '../entities/parking.dart';
import '../repositories/parking_repository.dart';

class ParkingUseCases {
  const ParkingUseCases(this.repository);

  final ParkingRepository repository;

  Future<List<ParkingSpace>> getSpaces() => repository.getSpaces();

  Future<ParkingSpace?> getMySpace() => repository.getMySpace();

  Future<List<ParkingEvent>> getEvents() => repository.getEvents();

  Future<List<GuestParkingRequest>> getGuestRequests() =>
      repository.getGuestRequests();

  Future<ParkingSpace> updateVehicle(
    ParkingSpace space,
    String vehicle,
    String plate,
  ) => repository.updateVehicle(space, vehicle, plate);

  Future<GuestParkingRequest> requestGuestParking(
    GuestParkingRequest request,
  ) => repository.requestGuestParking(request);

  Future<GuestParkingRequest> cancelGuestParking(
    GuestParkingRequest request,
  ) => repository.cancelGuestParking(request);
}
