import '../../domain/entities/facility.dart';

abstract interface class FacilityRepository {
  Future<List<Facility>> getFacilities();

  Future<Facility?> getFacility(String id);

  Future<List<FacilityReservation>> getReservations();

  Future<FacilityReservation> createReservation(
    FacilityReservation reservation,
  );
}
