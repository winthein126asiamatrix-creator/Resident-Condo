import '../../domain/entities/facility.dart';
import '../../domain/repositories/facility_repository.dart';
import '../datasources/facility_local_data_source.dart';

class FacilityRepositoryImpl implements FacilityRepository {
  const FacilityRepositoryImpl(this.localDataSource);

  final FacilityLocalDataSource localDataSource;

  @override
  Future<List<Facility>> getFacilities() async {
    final facilities = await localDataSource.getFacilities();
    return List<Facility>.of(facilities);
  }

  @override
  Future<Facility?> getFacility(String id) {
    return localDataSource.getFacility(id);
  }

  @override
  Future<List<FacilityReservation>> getReservations() async {
    final reservations = await localDataSource.getReservations();
    return List<FacilityReservation>.of(reservations);
  }

  @override
  Future<FacilityReservation> createReservation(
    FacilityReservation reservation,
  ) {
    return localDataSource.createReservation(reservation);
  }
}
