import '../../domain/entities/facility.dart';

class FacilityModel extends Facility {
  const FacilityModel({
    required super.id,
    required super.name,
    required super.imagePath,
    required super.location,
    required super.description,
    required super.rules,
    required super.openingHours,
    required super.capacity,
    required super.availableSlots,
  });
}

class FacilityReservationModel extends FacilityReservation {
  const FacilityReservationModel({
    required super.id,
    required super.facilityId,
    required super.facilityName,
    required super.date,
    required super.time,
    required super.status,
    required super.createdAt,
    super.isCustomTime,
  });
}
