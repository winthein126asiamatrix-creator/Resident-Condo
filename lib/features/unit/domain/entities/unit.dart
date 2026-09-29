class UnitPerson {
  const UnitPerson({
    required this.name,
    required this.role,
    required this.initials,
  });

  final String name;
  final String role;
  final String initials;
}

class ParkingInfo {
  const ParkingInfo({
    required this.slot,
    required this.vehicle,
    required this.licensePlate,
  });

  final String slot;
  final String vehicle;
  final String licensePlate;
}

class Unit {
  const Unit({
    required this.tower,
    required this.unitNumber,
    required this.floor,
    required this.unitType,
    required this.area,
    required this.bedrooms,
    required this.bathrooms,
    required this.ownershipStatus,
    required this.occupancyStatus,
    required this.owner,
    required this.residents,
    this.tenant,
    required this.parking,
  });

  final String tower;
  final String unitNumber;
  final String floor;
  final String unitType;
  final String area;
  final int bedrooms;
  final int bathrooms;
  final String ownershipStatus;
  final String occupancyStatus;
  final UnitPerson owner;
  final List<UnitPerson> residents;
  final UnitPerson? tenant;
  final ParkingInfo parking;
}
