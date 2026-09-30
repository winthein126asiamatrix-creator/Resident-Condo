class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.location,
    required this.description,
    required this.rules,
    required this.openingHours,
    required this.capacity,
    required this.availableSlots,
  });

  final String id;
  final String name;
  final String imagePath;
  final String location;
  final String description;
  final String rules;
  final String openingHours;
  final int capacity;
  final List<String> availableSlots;

  Facility copyWith({List<String>? availableSlots}) {
    return Facility(
      id: id,
      name: name,
      imagePath: imagePath,
      location: location,
      description: description,
      rules: rules,
      openingHours: openingHours,
      capacity: capacity,
      availableSlots: availableSlots ?? this.availableSlots,
    );
  }
}

class FacilityReservation {
  const FacilityReservation({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.date,
    required this.time,
    required this.status,
    required this.createdAt,
    this.isCustomTime = false,
    this.startTime,
    this.durationHours = 1,
  });

  final String id;
  final String facilityId;
  final String facilityName;
  final String date;

  /// The reservation interval as shown to the resident, for example
  /// `2:00 PM – 4:00 PM`.
  final String time;
  final String status;
  final String createdAt;

  /// True when the resident typed their own time instead of taking one of the
  /// facility's slots, so the slot is not consumed from its availability.
  final bool isCustomTime;

  /// The slot the reservation starts at, which is the value the facility's
  /// availability is checked against. Null only for a record that predates it.
  final String? startTime;

  /// How long the reservation runs for, in hours.
  final int durationHours;
}
