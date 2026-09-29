import '../../domain/entities/parking.dart';
import '../../domain/repositories/parking_repository.dart';
import '../datasources/parking_local_data_source.dart';

class ParkingRepositoryImpl implements ParkingRepository {
  const ParkingRepositoryImpl(this.localDataSource);

  final ParkingLocalDataSource localDataSource;

  @override
  Future<List<ParkingSpace>> getSpaces() => localDataSource.getSpaces();

  @override
  Future<ParkingSpace?> getMySpace() => localDataSource.getMySpace();

  @override
  Future<List<ParkingEvent>> getEvents() => localDataSource.getEvents();

  @override
  Future<List<GuestParkingRequest>> getGuestRequests() =>
      localDataSource.getGuestRequests();

  @override
  Future<ParkingSpace> updateVehicle(
    ParkingSpace space,
    String vehicle,
    String plate,
  ) => localDataSource.updateVehicle(space, vehicle, plate);

  @override
  Future<GuestParkingRequest> requestGuestParking(
    GuestParkingRequest request,
  ) => localDataSource.requestGuestParking(request);

  @override
  Future<GuestParkingRequest> cancelGuestParking(
    GuestParkingRequest request,
  ) => localDataSource.cancelGuestParking(request);
}
