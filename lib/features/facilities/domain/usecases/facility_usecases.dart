import '../entities/facility.dart';
import '../repositories/facility_repository.dart';

class FacilityUseCases {
  const FacilityUseCases(this.repository);

  final FacilityRepository repository;

  Future<List<Facility>> getFacilities() {
    return repository.getFacilities();
  }

  Future<Facility?> getFacility(String id) {
    return repository.getFacility(id);
  }

  Future<List<FacilityReservation>> getReservations() {
    return repository.getReservations();
  }

  Future<FacilityReservation> createReservation(
    FacilityReservation reservation,
  ) {
    return repository.createReservation(reservation);
  }
}
