import '../entities/parking.dart';

abstract interface class ParkingRepository {
  Future<List<ParkingSpace>> getSpaces();

  Future<ParkingSpace?> getMySpace();

  Future<List<ParkingEvent>> getEvents();

  Future<List<GuestParkingRequest>> getGuestRequests();

  Future<ParkingSpace> updateVehicle(ParkingSpace space, String vehicle, String plate);

  Future<GuestParkingRequest> requestGuestParking(GuestParkingRequest request);

  Future<GuestParkingRequest> cancelGuestParking(GuestParkingRequest request);
}
